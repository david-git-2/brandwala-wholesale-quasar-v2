-- Catalog order + PBC fulfillment: dispatch → delivered → closed.
UPDATE public.shop_orders
SET status = 'dispatch'::public.shop_order_status, updated_at = now()
WHERE shop_type_snapshot = 'vendor_catalog'
  AND status IN ('packed'::public.shop_order_status, 'ordered'::public.shop_order_status);

UPDATE public.product_based_costing_files
SET status = 'dispatch', updated_at = now()
WHERE lower(trim(status)) IN ('packed', 'ready_for_shipment');

UPDATE public.product_based_costing_files
SET status = 'closed', updated_at = now()
WHERE lower(trim(status)) IN ('completed', 'invoicing');

CREATE OR REPLACE FUNCTION public.normalize_pbc_procurement_status(p_status text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE lower(trim(coalesce(p_status, '')))
    WHEN 'placing_order' THEN 'procuring'
    WHEN 'ready_for_shipment' THEN 'dispatch'
    WHEN 'packed' THEN 'dispatch'
    WHEN 'invoicing' THEN 'delivered'
    WHEN 'completed' THEN 'closed'
    ELSE lower(trim(coalesce(p_status, '')))
  END;
$$;

CREATE OR REPLACE FUNCTION public.normalize_shop_order_procurement_status(p_status public.shop_order_status)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_status = 'ordered'::public.shop_order_status THEN 'dispatch'
    WHEN p_status = 'packed'::public.shop_order_status THEN 'dispatch'
    ELSE p_status::text
  END;
$$;

CREATE OR REPLACE FUNCTION public.staff_mark_pbc_packed(p_file_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_file record;
BEGIN
  SELECT * INTO v_file
  FROM public.product_based_costing_files
  WHERE id = p_file_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'costing file not found: %', p_file_id;
  END IF;

  IF NOT public.is_tenant_staff(v_file.tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  IF public.normalize_pbc_procurement_status(v_file.status) <> 'procuring' THEN
    RAISE EXCEPTION 'costing file must be procuring to mark dispatch';
  END IF;

  UPDATE public.product_based_costing_files
  SET status = 'dispatch', updated_at = now()
  WHERE id = p_file_id;

  RETURN jsonb_build_object(
    'success', true,
    'file_id', p_file_id,
    'status', 'dispatch'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_set_catalog_ordered_qty(p_order_id bigint, p_items jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_order record;
  v_desk_tenant_id bigint;
  v_item_row record;
  v_target_qty integer;
  v_allocated integer;
  v_shortfall integer;
  v_product record;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  v_desk_tenant_id := coalesce(v_order.parent_tenant_id, v_order.tenant_id);

  IF NOT public.is_tenant_staff(v_desk_tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  IF v_order.shop_type_snapshot <> 'vendor_catalog' THEN
    RAISE EXCEPTION 'staff_set_catalog_ordered_qty is only valid for vendor_catalog orders.';
  END IF;

  IF public.normalize_shop_order_procurement_status(v_order.status) <> 'procuring' THEN
    RAISE EXCEPTION 'order must be procuring to mark dispatch';
  END IF;

  FOR v_item_row IN
    SELECT oi.*
    FROM public.shop_order_items oi
    WHERE oi.order_id = p_order_id
  LOOP
    v_target_qty := coalesce(v_item_row.confirmed_quantity, v_item_row.quantity, 0);

    SELECT coalesce(pd.delivered_quantity, 0)
    INTO v_allocated
    FROM public.preorder_demand pd
    WHERE pd.source_type = 'shop_order_item'
      AND pd.source_id = v_item_row.id;

    v_shortfall := greatest(v_target_qty - coalesce(v_allocated, 0), 0);

    IF v_shortfall > 0 AND v_order.profile_id IS NOT NULL THEN
      SELECT p.barcode, p.product_code
      INTO v_product
      FROM public.products p
      WHERE p.id = v_item_row.product_id;

      PERFORM public.add_demand_bucket_item_internal(
        v_order.tenant_id,
        v_order.profile_id,
        v_item_row.product_id,
        'shop_order_item'::public.demand_bucket_source_type,
        v_item_row.id,
        jsonb_build_object(
          'name', coalesce(v_item_row.name, ''),
          'image_url', v_item_row.image_url,
          'barcode', v_product.barcode,
          'product_code', v_product.product_code,
          'note', null
        ),
        v_shortfall
      );

      INSERT INTO public.customer_order_backlog_items (
        tenant_id,
        profile_id,
        product_id,
        order_id,
        order_item_id,
        requested_quantity,
        fulfilled_quantity,
        backlog_status
      ) VALUES (
        v_order.tenant_id,
        v_order.profile_id,
        v_item_row.product_id,
        p_order_id,
        v_item_row.id,
        v_shortfall,
        0,
        'open'
      )
      ON CONFLICT (tenant_id, profile_id, product_id)
      DO UPDATE SET
        requested_quantity = customer_order_backlog_items.requested_quantity + excluded.requested_quantity,
        backlog_status = 'open',
        updated_at = now();
    END IF;
  END LOOP;

  UPDATE public.shop_orders
  SET
    status = 'dispatch'::public.shop_order_status,
    placed_at = coalesce(placed_at, now()),
    updated_at = now()
  WHERE id = p_order_id;

  PERFORM public.notify_catalog_shop_order(
    p_order_id := p_order_id,
    p_notify_staff := false,
    p_notify_customer := true,
    p_event_type := 'catalog.order.dispatch',
    p_title := format('%s is dispatching', v_order.order_no),
    p_body := 'We will update you when it is delivered.'
  );

  RETURN public.get_shop_order_for_staff(v_desk_tenant_id, p_order_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_close_catalog_procurement(p_order_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_order record;
  v_desk_tenant_id bigint;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  v_desk_tenant_id := coalesce(v_order.parent_tenant_id, v_order.tenant_id);

  IF NOT public.is_tenant_staff(v_desk_tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  IF v_order.shop_type_snapshot <> 'vendor_catalog' THEN
    RAISE EXCEPTION 'staff_close_catalog_procurement is only valid for vendor_catalog orders.';
  END IF;

  IF public.normalize_shop_order_procurement_status(v_order.status) <> 'delivered' THEN
    RAISE EXCEPTION 'order must be delivered to close';
  END IF;

  UPDATE public.shop_orders
  SET status = 'closed'::public.shop_order_status, updated_at = now()
  WHERE id = p_order_id;

  RETURN public.get_shop_order_for_staff(v_desk_tenant_id, p_order_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_close_pbc_procurement(p_file_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_file record;
BEGIN
  SELECT * INTO v_file
  FROM public.product_based_costing_files
  WHERE id = p_file_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'costing file not found: %', p_file_id;
  END IF;

  IF NOT public.is_tenant_staff(v_file.tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  IF public.normalize_pbc_procurement_status(v_file.status) <> 'delivered' THEN
    RAISE EXCEPTION 'costing file must be delivered to close';
  END IF;

  UPDATE public.product_based_costing_files
  SET status = 'closed', updated_at = now()
  WHERE id = p_file_id;

  RETURN jsonb_build_object('success', true, 'file_id', p_file_id, 'status', 'closed');
END;
$$;

CREATE OR REPLACE FUNCTION "public"."close_preorder_demand_document"("p_tenant_id" bigint, "p_document_type" "text", "p_document_id" bigint, "p_close_action" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_close_action text := lower(trim(coalesce(p_close_action, '')));
  v_operating_tenant_id bigint;
  v_profile_id bigint;
  v_doc_status text;
  v_parent_tenant_id bigint;
  v_global_invoice_id bigint;
  v_pbc_invoice_id bigint;
  v_items jsonb := '[]'::jsonb;
  v_payload jsonb;
  v_result jsonb;
  v_invoice_id bigint;
  v_line record;
  v_pd record;
  v_pick_elem jsonb;
  v_new_picks jsonb;
  v_pick_close text;
  v_global_stock_id bigint;
  v_qty integer;
  v_pick_count integer := 0;
  v_unit_count integer := 0;
  v_stock public.global_stocks%rowtype;
  v_delivery_kind text;
begin
  if p_tenant_id is null or p_document_id is null then
    raise exception 'tenant_id and document_id are required';
  end if;

  if v_close_action not in ('take', 'condition', 'return') then
    raise exception 'close_action must be take, condition, or return';
  end if;

  if v_doc_type = 'shop_order' then
    select
      o.tenant_id,
      o.profile_id,
      o.global_invoice_id,
      public.normalize_shop_order_procurement_status(o.status)
    into v_operating_tenant_id, v_profile_id, v_global_invoice_id, v_doc_status
    from public.shop_orders o
    where o.id = p_document_id
      and o.shop_type_snapshot = 'vendor_catalog';

    if v_operating_tenant_id is null then
      raise exception 'shop order not found or not vendor_catalog';
    end if;
  elsif v_doc_type = 'pbc_costing_file' then
    select
      f.tenant_id,
      f.profile_id,
      f.invoice_id,
      public.normalize_pbc_procurement_status(f.status)
    into v_operating_tenant_id, v_profile_id, v_pbc_invoice_id, v_doc_status
    from public.product_based_costing_files f
    where f.id = p_document_id;

    if v_operating_tenant_id is null then
      raise exception 'costing file not found';
    end if;
  else
    raise exception 'invalid document_type: %', p_document_type;
  end if;

  if not public.can_access_preorder_demand_tenant(p_tenant_id)
    and not public.can_access_preorder_demand_tenant(v_operating_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_operating_tenant_id <> p_tenant_id then
    if not exists (
      select 1
      from public.tenants t
      where t.id = v_operating_tenant_id
        and t.parent_id = p_tenant_id
        and public.user_can_manage_parent_tenant(p_tenant_id)
    ) then
      raise exception 'tenant mismatch for demand document';
    end if;
  end if;

  if v_doc_status <> 'dispatch' then
    raise exception 'document must be dispatch to close picks';
  end if;

  if v_profile_id is null and v_close_action in ('take', 'condition') then
    raise exception 'profile_id is required on document';
  end if;

  select coalesce(t.parent_id, t.id)
  into v_parent_tenant_id
  from public.tenants t
  where t.id = v_operating_tenant_id;

  if v_close_action in ('take', 'condition') then
    v_delivery_kind := v_close_action;

    if v_doc_type = 'shop_order' then
      for v_line in
        select
          pd.source_type,
          pd.source_id,
          pd.stock_picks,
          coalesce(oi.final_price_amount, oi.staff_offer_amount, 0)::numeric(12,2) as sell_price
        from public.preorder_demand pd
        inner join public.shop_order_items oi
          on pd.source_type = 'shop_order_item'
          and pd.source_id = oi.id
        where oi.order_id = p_document_id
        order by pd.source_id
      loop
        for v_pick_elem in
          select value from jsonb_array_elements(coalesce(v_line.stock_picks, '[]'::jsonb))
        loop
          v_pick_close := lower(trim(coalesce(v_pick_elem->>'close_action', 'take')));
          v_global_stock_id := nullif(v_pick_elem->>'global_stock_id', '')::bigint;
          v_qty := coalesce((v_pick_elem->>'quantity')::integer, 0);
          if v_pick_close = v_close_action
            and v_global_stock_id is not null
            and v_qty > 0
            and nullif(v_pick_elem->>'invoice_id', '') is null
            and nullif(v_pick_elem->>'returned_at', '') is null
          then
            v_items := v_items || jsonb_build_array(jsonb_build_object(
              'global_stock_id', v_global_stock_id,
              'quantity', v_qty,
              'sell_price_amount', v_line.sell_price
            ));
            v_pick_count := v_pick_count + 1;
            v_unit_count := v_unit_count + v_qty;
          end if;
        end loop;
      end loop;
    else
      for v_line in
        select
          pd.source_type,
          pd.source_id,
          pd.stock_picks,
          coalesce(pci.offer_price, 0)::numeric(12,2) as sell_price
        from public.preorder_demand pd
        inner join public.product_based_costing_items pci
          on pd.source_type = 'pbc_costing_item'
          and pd.source_id = pci.id
        where pci.product_based_costing_file_id = p_document_id
        order by pd.source_id
      loop
        for v_pick_elem in
          select value from jsonb_array_elements(coalesce(v_line.stock_picks, '[]'::jsonb))
        loop
          v_pick_close := lower(trim(coalesce(v_pick_elem->>'close_action', 'take')));
          v_global_stock_id := nullif(v_pick_elem->>'global_stock_id', '')::bigint;
          v_qty := coalesce((v_pick_elem->>'quantity')::integer, 0);
          if v_pick_close = v_close_action
            and v_global_stock_id is not null
            and v_qty > 0
            and nullif(v_pick_elem->>'invoice_id', '') is null
            and nullif(v_pick_elem->>'returned_at', '') is null
          then
            v_items := v_items || jsonb_build_array(jsonb_build_object(
              'global_stock_id', v_global_stock_id,
              'quantity', v_qty,
              'sell_price_amount', v_line.sell_price
            ));
            v_pick_count := v_pick_count + 1;
            v_unit_count := v_unit_count + v_qty;
          end if;
        end loop;
      end loop;
    end if;

    if v_pick_count = 0 then
      return jsonb_build_object(
        'success', true,
        'created', false,
        'close_action', v_close_action,
        'pick_count', 0,
        'unit_count', 0
      );
    end if;

    v_payload := jsonb_build_object(
      'invoice', jsonb_build_object(
        'invoice_type', 'wholesale',
        'profile_id', v_profile_id,
        'channel_meta', jsonb_build_object('delivery_kind', v_delivery_kind)
      ),
      'items', v_items,
      'issue', false
    );

    v_result := public.create_sales_invoice_from_payload(v_operating_tenant_id, v_payload);

    if coalesce(v_result->>'success', 'false') <> 'true' then
      raise exception '%', coalesce(v_result->>'error', 'failed to create close invoice');
    end if;

    v_invoice_id := (v_result->>'invoice_id')::bigint;

    begin
      update public.bills
      set
        source_type = 'delivery_close',
        source_id = p_document_id::text,
        source_key = v_close_action,
        settlement_kind = v_close_action::public.bill_settlement_kind,
        channel_meta = coalesce(channel_meta, '{}'::jsonb)
          || jsonb_build_object(
            'delivery_kind', v_close_action,
            'document_type', v_doc_type
          ),
        updated_at = now()
      where id = v_invoice_id;
    exception
      when unique_violation then
        update public.bills
        set
          source_type = 'delivery_close',
          source_id = p_document_id::text,
          source_key = v_close_action || ':' || v_invoice_id::text,
          settlement_kind = v_close_action::public.bill_settlement_kind,
          channel_meta = coalesce(channel_meta, '{}'::jsonb)
            || jsonb_build_object(
              'delivery_kind', v_close_action,
              'document_type', v_doc_type
            ),
          updated_at = now()
        where id = v_invoice_id;
    end;

    perform public.stamp_bill_kernel_fields(v_invoice_id);

    if v_doc_type = 'shop_order' then
      for v_pd in
        select pd.id, pd.source_type, pd.source_id, pd.stock_picks
        from public.preorder_demand pd
        inner join public.shop_order_items oi
          on pd.source_type = 'shop_order_item'
          and pd.source_id = oi.id
        where oi.order_id = p_document_id
        order by pd.source_id
      loop
        v_new_picks := '[]'::jsonb;
        for v_pick_elem in
          select value from jsonb_array_elements(coalesce(v_pd.stock_picks, '[]'::jsonb))
        loop
          v_pick_close := lower(trim(coalesce(v_pick_elem->>'close_action', 'take')));
          v_global_stock_id := nullif(v_pick_elem->>'global_stock_id', '')::bigint;
          v_qty := coalesce((v_pick_elem->>'quantity')::integer, 0);
          if v_pick_close = v_close_action
            and v_global_stock_id is not null
            and v_qty > 0
            and nullif(v_pick_elem->>'invoice_id', '') is null
            and nullif(v_pick_elem->>'returned_at', '') is null
          then
            v_pick_elem := v_pick_elem || jsonb_build_object('invoice_id', v_invoice_id);
          end if;
          v_new_picks := v_new_picks || jsonb_build_array(v_pick_elem);
        end loop;

        update public.preorder_demand
        set
          stock_picks = v_new_picks,
          updated_at = now()
        where id = v_pd.id;
      end loop;

      if v_close_action = 'take' and v_global_invoice_id is null then
        update public.shop_orders
        set
          global_invoice_id = v_invoice_id,
          updated_at = now()
        where id = p_document_id
          and global_invoice_id is null;
      end if;
    else
      for v_pd in
        select pd.id, pd.source_type, pd.source_id, pd.stock_picks
        from public.preorder_demand pd
        inner join public.product_based_costing_items pci
          on pd.source_type = 'pbc_costing_item'
          and pd.source_id = pci.id
        where pci.product_based_costing_file_id = p_document_id
        order by pd.source_id
      loop
        v_new_picks := '[]'::jsonb;
        for v_pick_elem in
          select value from jsonb_array_elements(coalesce(v_pd.stock_picks, '[]'::jsonb))
        loop
          v_pick_close := lower(trim(coalesce(v_pick_elem->>'close_action', 'take')));
          v_global_stock_id := nullif(v_pick_elem->>'global_stock_id', '')::bigint;
          v_qty := coalesce((v_pick_elem->>'quantity')::integer, 0);
          if v_pick_close = v_close_action
            and v_global_stock_id is not null
            and v_qty > 0
            and nullif(v_pick_elem->>'invoice_id', '') is null
            and nullif(v_pick_elem->>'returned_at', '') is null
          then
            v_pick_elem := v_pick_elem || jsonb_build_object('invoice_id', v_invoice_id);
          end if;
          v_new_picks := v_new_picks || jsonb_build_array(v_pick_elem);
        end loop;

        update public.preorder_demand
        set
          stock_picks = v_new_picks,
          updated_at = now()
        where id = v_pd.id;
      end loop;

      if v_close_action = 'take' and v_pbc_invoice_id is null then
        update public.product_based_costing_files
        set
          invoice_id = v_invoice_id,
          updated_at = now()
        where id = p_document_id
          and invoice_id is null;
      end if;
    end if;

    return jsonb_build_object(
      'success', true,
      'created', true,
      'close_action', v_close_action,
      'invoice_id', v_invoice_id,
      'invoice_no', v_result->>'invoice_no',
      'pick_count', v_pick_count,
      'unit_count', v_unit_count
    );
  end if;

  if v_doc_type = 'shop_order' then
    for v_pd in
      select pd.id, pd.source_type, pd.source_id, pd.stock_picks
      from public.preorder_demand pd
      inner join public.shop_order_items oi
        on pd.source_type = 'shop_order_item'
        and pd.source_id = oi.id
      where oi.order_id = p_document_id
      order by pd.source_id
    loop
      v_new_picks := '[]'::jsonb;
      for v_pick_elem in
        select value from jsonb_array_elements(coalesce(v_pd.stock_picks, '[]'::jsonb))
      loop
        v_pick_close := lower(trim(coalesce(v_pick_elem->>'close_action', 'take')));
        v_global_stock_id := nullif(v_pick_elem->>'global_stock_id', '')::bigint;
        v_qty := coalesce((v_pick_elem->>'quantity')::integer, 0);
        if v_pick_close = 'return'
          and v_global_stock_id is not null
          and v_qty > 0
          and nullif(v_pick_elem->>'invoice_id', '') is null
          and nullif(v_pick_elem->>'returned_at', '') is null
        then
          select * into v_stock
          from public.global_stocks
          where id = v_global_stock_id
            and parent_tenant_id = v_parent_tenant_id
          for update;

          if v_stock.id is null then
            raise exception 'stock % not found', v_global_stock_id;
          end if;

          if v_stock.availability = 'held'::public.stock_availability then
            perform public.create_and_post_stock_movement(
              p_tenant_id => v_parent_tenant_id,
              p_stock_id => v_global_stock_id,
              p_quantity => v_qty,
              p_to_location_id => v_stock.location_id,
              p_to_availability => 'sellable'::public.stock_availability,
              p_movement_type => 'availability_transfer'::public.stock_movement_type,
              p_notes => 'Delivery paper return',
              p_reference_type => 'preorder_demand',
              p_reference_id => v_pd.id::text
            );
          elsif v_stock.availability <> 'sellable'::public.stock_availability then
            raise exception 'return close requires held or sellable stock % (current: %)',
              v_global_stock_id, v_stock.availability;
          end if;

          v_pick_elem := v_pick_elem || jsonb_build_object(
            'returned_at', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
          );
          v_pick_count := v_pick_count + 1;
          v_unit_count := v_unit_count + v_qty;
        end if;
        v_new_picks := v_new_picks || jsonb_build_array(v_pick_elem);
      end loop;

      update public.preorder_demand
      set
        stock_picks = v_new_picks,
        updated_at = now()
      where id = v_pd.id;
    end loop;
  else
    for v_pd in
      select pd.id, pd.source_type, pd.source_id, pd.stock_picks
      from public.preorder_demand pd
      inner join public.product_based_costing_items pci
        on pd.source_type = 'pbc_costing_item'
        and pd.source_id = pci.id
      where pci.product_based_costing_file_id = p_document_id
      order by pd.source_id
    loop
      v_new_picks := '[]'::jsonb;
      for v_pick_elem in
        select value from jsonb_array_elements(coalesce(v_pd.stock_picks, '[]'::jsonb))
      loop
        v_pick_close := lower(trim(coalesce(v_pick_elem->>'close_action', 'take')));
        v_global_stock_id := nullif(v_pick_elem->>'global_stock_id', '')::bigint;
        v_qty := coalesce((v_pick_elem->>'quantity')::integer, 0);
        if v_pick_close = 'return'
          and v_global_stock_id is not null
          and v_qty > 0
          and nullif(v_pick_elem->>'invoice_id', '') is null
          and nullif(v_pick_elem->>'returned_at', '') is null
        then
          select * into v_stock
          from public.global_stocks
          where id = v_global_stock_id
            and parent_tenant_id = v_parent_tenant_id
          for update;

          if v_stock.id is null then
            raise exception 'stock % not found', v_global_stock_id;
          end if;

          if v_stock.availability = 'held'::public.stock_availability then
            perform public.create_and_post_stock_movement(
              p_tenant_id => v_parent_tenant_id,
              p_stock_id => v_global_stock_id,
              p_quantity => v_qty,
              p_to_location_id => v_stock.location_id,
              p_to_availability => 'sellable'::public.stock_availability,
              p_movement_type => 'availability_transfer'::public.stock_movement_type,
              p_notes => 'Delivery paper return',
              p_reference_type => 'preorder_demand',
              p_reference_id => v_pd.id::text
            );
          elsif v_stock.availability <> 'sellable'::public.stock_availability then
            raise exception 'return close requires held or sellable stock % (current: %)',
              v_global_stock_id, v_stock.availability;
          end if;

          v_pick_elem := v_pick_elem || jsonb_build_object(
            'returned_at', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
          );
          v_pick_count := v_pick_count + 1;
          v_unit_count := v_unit_count + v_qty;
        end if;
        v_new_picks := v_new_picks || jsonb_build_array(v_pick_elem);
      end loop;

      update public.preorder_demand
      set
        stock_picks = v_new_picks,
        updated_at = now()
      where id = v_pd.id;
    end loop;
  end if;

  return jsonb_build_object(
    'success', true,
    'created', v_pick_count > 0,
    'close_action', v_close_action,
    'pick_count', v_pick_count,
    'unit_count', v_unit_count
  );
end;
$_$;

GRANT EXECUTE ON FUNCTION public.staff_close_catalog_procurement(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_close_pbc_procurement(bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.upsert_preorder_demand(
  p_tenant_id bigint,
  p_source_type public.preorder_demand_source_type,
  p_source_id bigint,
  p_vendor_id bigint DEFAULT NULL,
  p_placed_quantity integer DEFAULT NULL,
  p_stock_picks jsonb DEFAULT NULL,
  p_notes text DEFAULT NULL,
  p_vendor_placements jsonb DEFAULT NULL
)
RETURNS public.preorder_demand
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.preorder_demand;
  v_line_tenant_id bigint;
  v_doc_status text;
  v_open_qty integer;
  v_delivered integer;
  v_placed integer;
  v_placements jsonb;
  v_vendor_code text;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id is required';
  END IF;
  IF p_source_id IS NULL THEN
    RAISE EXCEPTION 'source_id is required';
  END IF;

  SELECT g.tenant_id, g.open_qty, g.document_status
  INTO v_line_tenant_id, v_open_qty, v_doc_status
  FROM public.get_procurement_demand_open_qty(p_source_type, p_source_id) g;

  IF v_line_tenant_id IS NULL THEN
    RAISE EXCEPTION 'demand line not found';
  END IF;

  IF NOT public.can_access_preorder_demand_tenant(p_tenant_id)
    AND NOT public.can_access_preorder_demand_tenant(v_line_tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  IF v_line_tenant_id <> p_tenant_id THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.tenants t
      WHERE t.id = v_line_tenant_id
        AND t.parent_id = p_tenant_id
        AND public.user_can_manage_parent_tenant(p_tenant_id)
    ) THEN
      RAISE EXCEPTION 'tenant mismatch for demand line';
    END IF;
  END IF;

  IF v_doc_status NOT IN ('procuring', 'dispatch', 'packed') THEN
    RAISE EXCEPTION 'document is not open for preorder demand updates';
  END IF;

  IF (p_placed_quantity IS NOT NULL OR p_vendor_placements IS NOT NULL)
    AND v_doc_status <> 'procuring' THEN
    RAISE EXCEPTION 'vendor placements can only be updated while procuring';
  END IF;

  IF p_stock_picks IS NOT NULL AND v_doc_status NOT IN ('procuring', 'dispatch', 'packed') THEN
    RAISE EXCEPTION 'stock_picks can only be updated while procuring or dispatch';
  END IF;

  IF p_vendor_placements IS NOT NULL THEN
    IF NOT public.validate_preorder_vendor_placements(p_vendor_placements) THEN
      RAISE EXCEPTION 'invalid vendor_placements payload';
    END IF;
    v_placements := p_vendor_placements;
    v_placed := public.sum_preorder_vendor_placements(v_placements);
    IF v_placed > coalesce(v_open_qty, 0) THEN
      RAISE EXCEPTION 'placed quantity cannot exceed need quantity';
    END IF;
  ELSIF p_placed_quantity IS NOT NULL THEN
    IF coalesce(p_placed_quantity, 0) < 0 THEN
      RAISE EXCEPTION 'placed_quantity cannot be negative';
    END IF;
    SELECT pd.* INTO v_row
    FROM public.preorder_demand pd
    WHERE pd.source_type = p_source_type AND pd.source_id = p_source_id;
    SELECT nullif(trim(v.code), '') INTO v_vendor_code
    FROM public.vendors v
    WHERE v.id = coalesce(p_vendor_id, v_row.vendor_id);
    v_vendor_code := coalesce(v_vendor_code, 'unknown');
    v_placements := jsonb_build_array(
      jsonb_build_object('vendor_code', v_vendor_code, 'quantity', p_placed_quantity)
    );
    v_placed := p_placed_quantity;
    IF v_placed > coalesce(v_open_qty, 0) THEN
      RAISE EXCEPTION 'placed quantity cannot exceed need quantity';
    END IF;
  ELSE
    v_placements := NULL;
  END IF;

  IF p_stock_picks IS NOT NULL AND NOT public.validate_preorder_stock_picks(p_stock_picks) THEN
    RAISE EXCEPTION 'invalid stock_picks payload';
  END IF;

  v_delivered := CASE
    WHEN p_stock_picks IS NOT NULL THEN public.sum_preorder_stock_picks(p_stock_picks)
    ELSE NULL
  END;

  SELECT pd.* INTO v_row
  FROM public.preorder_demand pd
  WHERE pd.source_type = p_source_type
    AND pd.source_id = p_source_id;

  IF v_placements IS NULL THEN
    IF found THEN
      v_placed := coalesce(
        public.sum_preorder_vendor_placements(v_row.vendor_placements),
        v_row.placed_quantity,
        0
      );
    ELSE
      v_placed := 0;
    END IF;
  END IF;

  IF v_delivered IS NOT NULL AND v_delivered > coalesce(v_open_qty, 0) THEN
    RAISE EXCEPTION 'delivered_quantity cannot exceed need quantity';
  END IF;

  INSERT INTO public.preorder_demand (
    tenant_id,
    parent_tenant_id,
    source_type,
    source_id,
    vendor_id,
    placed_quantity,
    delivered_quantity,
    vendor_placements,
    stock_picks,
    notes,
    updated_by_user_id
  ) VALUES (
    v_line_tenant_id,
    public.resolve_parent_tenant_id(v_line_tenant_id),
    p_source_type,
    p_source_id,
    coalesce(p_vendor_id, CASE WHEN found THEN v_row.vendor_id ELSE NULL END),
    v_placed,
    coalesce(v_delivered, CASE WHEN found THEN v_row.delivered_quantity ELSE 0 END, 0),
    coalesce(v_placements, CASE WHEN found THEN v_row.vendor_placements ELSE '[]'::jsonb END, '[]'::jsonb),
    coalesce(p_stock_picks, CASE WHEN found THEN v_row.stock_picks ELSE '[]'::jsonb END, '[]'::jsonb),
    coalesce(nullif(trim(p_notes), ''), CASE WHEN found THEN v_row.notes ELSE NULL END),
    auth.uid()
  )
  ON CONFLICT (source_type, source_id) DO UPDATE SET
    parent_tenant_id = coalesce(public.preorder_demand.parent_tenant_id, excluded.parent_tenant_id),
    vendor_id = CASE WHEN p_vendor_id IS NOT NULL THEN p_vendor_id ELSE preorder_demand.vendor_id END,
    placed_quantity = v_placed,
    vendor_placements = CASE
      WHEN v_placements IS NOT NULL THEN v_placements
      ELSE preorder_demand.vendor_placements
    END,
    delivered_quantity = CASE
      WHEN v_delivered IS NOT NULL THEN v_delivered
      ELSE preorder_demand.delivered_quantity
    END,
    open_quantity = greatest(
      coalesce(preorder_demand.confirmed_quantity, 0)
        - CASE WHEN v_delivered IS NOT NULL THEN v_delivered ELSE preorder_demand.delivered_quantity END,
      0
    ),
    stock_picks = CASE WHEN p_stock_picks IS NOT NULL THEN p_stock_picks ELSE preorder_demand.stock_picks END,
    notes = CASE WHEN p_notes IS NOT NULL THEN nullif(trim(p_notes), '') ELSE preorder_demand.notes END,
    updated_by_user_id = auth.uid(),
    updated_at = now()
  RETURNING * INTO v_row;

  IF p_stock_picks IS NOT NULL OR jsonb_array_length(coalesce(v_row.stock_picks, '[]'::jsonb)) > 0 THEN
    PERFORM public.sync_delivery_paper_lines_for_demand(v_row.id);
  END IF;

  RETURN v_row;
END;
$$;
