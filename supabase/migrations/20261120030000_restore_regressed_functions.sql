-- Restore RPC bodies regressed by 20261119233100_functions_use_tenant_id.sql
DROP FUNCTION IF EXISTS public.list_shop_orders_staff_page(
  bigint, integer, text, text, bigint, text, timestamp with time zone, bigint
);

CREATE OR REPLACE FUNCTION "public"."list_shop_orders_staff_page"("p_tenant_id" bigint, "p_limit" integer DEFAULT 30, "p_search" "text" DEFAULT NULL::"text", "p_status" "text" DEFAULT NULL::"text", "p_shop_id" bigint DEFAULT NULL::bigint, "p_shop_type" "text" DEFAULT NULL::"text", "p_profile_id" bigint DEFAULT NULL::bigint, "p_cursor_created_at" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_cursor_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_limit integer := greatest(1, least(coalesce(p_limit, 30), 100));
  v_fetch integer := v_limit + 1;
  v_is_parent_query boolean;
  v_shops jsonb := '[]'::jsonb;
  v_orders jsonb := '[]'::jsonb;
  v_has_more boolean := false;
  v_next_cursor jsonb := null;
BEGIN
  IF NOT public.is_tenant_staff(p_tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  SELECT (t.parent_id IS NULL) INTO v_is_parent_query
  FROM public.tenants t
  WHERE t.id = p_tenant_id;
  v_is_parent_query := coalesce(v_is_parent_query, false);

  IF p_cursor_created_at IS NULL AND p_cursor_id IS NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public.memberships m
      WHERE (m.tenant_id = p_tenant_id OR m.tenant_id = public.resolve_books_tenant_id(p_tenant_id))
        AND lower(trim(m.email)) = public.current_user_email()
        AND m.is_active = true
    ) THEN
      RAISE EXCEPTION 'not allowed';
    END IF;

    IF v_is_parent_query THEN
      SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.name), '[]'::jsonb)
      INTO v_shops
      FROM (
        SELECT
          s.id,
          s.tenant_id,
          s.name,
          s.slug,
          s.shop_type,
          coalesce(t.name, '')::text AS tenant_name
        FROM public.shops s
        LEFT JOIN public.tenants t ON t.id = s.tenant_id
        WHERE (
          s.tenant_id = p_tenant_id
          OR s.tenant_id IN (SELECT public.list_child_tenant_ids(p_tenant_id))
        )
          AND s.deleted_at IS NULL
        ORDER BY s.name
        LIMIT 500
      ) x;
    ELSE
      SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.name), '[]'::jsonb)
      INTO v_shops
      FROM (
        SELECT
          s.id,
          s.tenant_id,
          s.name,
          s.slug,
          s.shop_type,
          coalesce(t.name, '')::text AS tenant_name
        FROM public.shops s
        LEFT JOIN public.tenants t ON t.id = s.tenant_id
        WHERE s.tenant_id = p_tenant_id
          AND s.deleted_at IS NULL
        ORDER BY s.name
        LIMIT 500
      ) x;
    END IF;
  END IF;

  WITH base AS (
    SELECT
      o.id,
      o.tenant_id,
      o.shop_id,
      s.name AS shop_name,
      o.customer_group_id,
      cg.name AS customer_group_name,
      o.order_no,
      o.name,
      o.shop_type_snapshot,
      o.is_negotiable_snapshot,
      o.status,
      o.created_at,
      o.updated_at,
      o.hidden_from_customer,
      o.catalog_manual_price_entry,
      o.placement_scope,
      o.created_by_email,
      (SELECT count(*)::bigint FROM public.shop_order_items WHERE order_id = o.id) AS item_count,
      coalesce(t.name, '')::text AS tenant_name
    FROM public.shop_orders o
    JOIN public.shops s ON s.id = o.shop_id
    JOIN public.customer_groups cg ON cg.id = o.customer_group_id
    LEFT JOIN public.tenants t ON t.id = o.tenant_id
    WHERE (
      (
        v_is_parent_query
        AND (
          o.tenant_id = p_tenant_id
          OR o.tenant_id IN (SELECT public.list_child_tenant_ids(p_tenant_id))
        )
      )
      OR (NOT v_is_parent_query AND o.tenant_id = p_tenant_id)
    )
      AND (p_status IS NULL OR o.status::text = p_status)
      AND (p_shop_id IS NULL OR o.shop_id = p_shop_id)
      AND (p_shop_type IS NULL OR s.shop_type::text = p_shop_type)
      AND (p_profile_id IS NULL OR o.profile_id = p_profile_id)
      AND (
        p_search IS NULL
        OR o.order_no ILIKE ('%' || p_search || '%')
        OR o.name ILIKE ('%' || p_search || '%')
        OR s.name ILIKE ('%' || p_search || '%')
        OR cg.name ILIKE ('%' || p_search || '%')
        OR t.name ILIKE ('%' || p_search || '%')
      )
      AND (
        p_cursor_created_at IS NULL
        OR (o.created_at, o.id) < (p_cursor_created_at, p_cursor_id)
      )
    ORDER BY o.created_at DESC, o.id DESC
    LIMIT v_fetch
  ),
  page AS (
    SELECT * FROM base ORDER BY created_at DESC, id DESC LIMIT v_limit
  ),
  tail AS (
    SELECT created_at, id FROM page ORDER BY created_at ASC, id ASC LIMIT 1
  )
  SELECT
    coalesce(
      (SELECT jsonb_agg(to_jsonb(p) ORDER BY p.created_at DESC, p.id DESC) FROM page p),
      '[]'::jsonb
    ),
    (SELECT count(*) > v_limit FROM base),
    CASE
      WHEN (SELECT count(*) FROM base) > v_limit THEN
        (SELECT jsonb_build_object('created_at', created_at, 'id', id) FROM tail)
      ELSE NULL
    END
  INTO v_orders, v_has_more, v_next_cursor;

  RETURN jsonb_build_object(
    'shops', v_shops,
    'orders', v_orders,
    'meta', jsonb_build_object(
      'limit', v_limit,
      'has_more', v_has_more,
      'next_cursor', v_next_cursor
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION "public"."close_preorder_demand_document"("p_tenant_id" bigint, "p_document_type" "text", "p_document_id" bigint, "p_close_action" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_close_action text := lower(trim(coalesce(p_close_action, '')));
  v_operating_tenant_id bigint;
  v_profile_id bigint;
  v_doc_status text;
  v_books_tenant_id bigint;
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
        and public.user_can_manage_books_tenant(p_tenant_id)
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
  into v_books_tenant_id
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
            and tenant_id = v_books_tenant_id
          for update;

          if v_stock.id is null then
            raise exception 'stock % not found', v_global_stock_id;
          end if;

          if v_stock.availability = 'held'::public.stock_availability then
            perform public.create_and_post_stock_movement(
              p_tenant_id => v_books_tenant_id,
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
            and tenant_id = v_books_tenant_id
          for update;

          if v_stock.id is null then
            raise exception 'stock % not found', v_global_stock_id;
          end if;

          if v_stock.availability = 'held'::public.stock_availability then
            perform public.create_and_post_stock_movement(
              p_tenant_id => v_books_tenant_id,
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
$$;

CREATE OR REPLACE FUNCTION "public"."ensure_preorder_demand_for_procuring_document"("p_document_type" "text", "p_document_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
BEGIN
  IF p_document_id IS NULL THEN
    RETURN;
  END IF;

  IF v_doc_type = 'shop_order' THEN
    INSERT INTO public.preorder_demand (
      tenant_id,
      source_type,
      source_id,
      profile_id,
      confirmed_quantity,
      open_quantity,
      placed_quantity,
      delivered_quantity,
      vendor_placements,
      stock_picks
    )
    SELECT
      o.tenant_id,
      'shop_order_item'::public.preorder_demand_source_type,
      oi.id,
      o.profile_id,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer,
      0,
      0,
      '[]'::jsonb,
      '[]'::jsonb
    FROM public.shop_order_items oi
    INNER JOIN public.shop_orders o ON o.id = oi.order_id
    WHERE o.id = p_document_id
      AND o.shop_type_snapshot = 'vendor_catalog'
    ON CONFLICT (source_type, source_id) DO UPDATE SET
      profile_id = coalesce(public.preorder_demand.profile_id, excluded.profile_id),
      confirmed_quantity = excluded.confirmed_quantity,
      open_quantity = greatest(
        excluded.confirmed_quantity - coalesce(public.preorder_demand.delivered_quantity, 0),
        0
      ),
      updated_at = now();
  ELSIF v_doc_type = 'pbc_costing_file' THEN
    INSERT INTO public.preorder_demand (
      tenant_id,
      source_type,
      source_id,
      profile_id,
      confirmed_quantity,
      open_quantity,
      placed_quantity,
      delivered_quantity,
      vendor_placements,
      stock_picks
    )
    SELECT
      f.tenant_id,
      'pbc_costing_item'::public.preorder_demand_source_type,
      pci.id,
      f.profile_id,
      greatest(
        CASE
          WHEN pci.assigned_shipment_id IS NOT NULL THEN 0
          ELSE coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        END,
        0
      )::integer,
      greatest(
        CASE
          WHEN pci.assigned_shipment_id IS NOT NULL THEN 0
          ELSE coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        END,
        0
      )::integer,
      0,
      0,
      '[]'::jsonb,
      '[]'::jsonb
    FROM public.product_based_costing_items pci
    INNER JOIN public.product_based_costing_files f ON f.id = pci.product_based_costing_file_id
    WHERE f.id = p_document_id
    ON CONFLICT (source_type, source_id) DO UPDATE SET
      profile_id = coalesce(public.preorder_demand.profile_id, excluded.profile_id),
      confirmed_quantity = excluded.confirmed_quantity,
      open_quantity = greatest(
        excluded.confirmed_quantity - coalesce(public.preorder_demand.delivered_quantity, 0),
        0
      ),
      updated_at = now();
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION "public"."update_catalog_order_rates_for_staff"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order record;
begin
  if p_tenant_id is null or p_order_id is null then
    raise exception 'tenant and order required';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  if not found
     or (v_order.tenant_id is distinct from p_tenant_id) then
    raise exception 'order not found';
  end if;

  if v_order.status in (
    'procuring'::public.shop_order_status,
    'dispatch'::public.shop_order_status,
    'delivered'::public.shop_order_status,
    'closed'::public.shop_order_status,
    'ordered'::public.shop_order_status,
    'packed'::public.shop_order_status
  ) then
    raise exception 'order rates cannot be changed after procurement has started';
  end if;

  update public.shop_orders o
  set
    conversion_rate = case when p_payload ? 'conversion_rate' then (p_payload->>'conversion_rate')::numeric else o.conversion_rate end,
    cargo_rate = case when p_payload ? 'cargo_rate' then (p_payload->>'cargo_rate')::numeric else o.cargo_rate end,
    profit_rate = case when p_payload ? 'profit_rate' then (p_payload->>'profit_rate')::numeric else o.profit_rate end,
    first_offer_rate = case when p_payload ? 'first_offer_rate' then (p_payload->>'first_offer_rate')::numeric else o.first_offer_rate end,
    final_offer_rate = case when p_payload ? 'final_offer_rate' then (p_payload->>'final_offer_rate')::numeric else o.final_offer_rate end,
    profit_basis = case when p_payload ? 'profit_basis' then nullif(p_payload->>'profit_basis', '') else o.profit_basis end,
    updated_at = now()
  where o.id = p_order_id;

  return public.get_shop_order_for_staff(p_tenant_id, p_order_id);
end;
$$;

CREATE OR REPLACE FUNCTION public._insert_bill_line_from_compose_payload(
  p_parent_id bigint,
  p_invoice_id bigint,
  p_item_elem jsonb
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_shipment_id bigint;
  v_global_stock_id bigint;
  v_quantity numeric;
  v_sell_price numeric;
  v_line_discount numeric;
  v_line_total numeric;
  v_line_meta jsonb;
  v_line_kind text;
  v_name_snapshot text;
  v_created_item_id bigint;
  v_stock_parent bigint;
  v_shipment_item_id bigint;
  v_product_id bigint;
  v_barcode_snapshot text;
  v_product_code_snapshot text;
  v_assigned_child bigint;
begin
  v_line_meta := coalesce(p_item_elem->'line_meta', '{}'::jsonb);
  v_global_stock_id := coalesce(
    nullif(p_item_elem->>'global_stock_id', '')::bigint,
    nullif(v_line_meta->'stock_ref'->>'global_stock_id', '')::bigint
  );
  v_quantity := nullif(p_item_elem->>'quantity', '')::numeric;
  v_sell_price := nullif(p_item_elem->>'sell_price_amount', '')::numeric;
  v_line_discount := coalesce(nullif(p_item_elem->>'line_discount_amount', '')::numeric, 0);
  v_line_kind := lower(trim(coalesce(p_item_elem->>'line_kind', '')));

  if v_quantity is null or v_quantity <= 0 then
    raise exception 'each item requires quantity > 0';
  end if;
  if v_sell_price is null or v_sell_price < 0 then
    raise exception 'each item requires sell_price_amount >= 0';
  end if;

  if v_global_stock_id is null and coalesce(v_line_meta->>'is_warehouse_gift', 'false') = 'true' then
    v_product_id := nullif(p_item_elem->>'product_id', '')::bigint;
    v_shipment_item_id := nullif(p_item_elem->>'shipment_item_id', '')::bigint;
    v_name_snapshot := coalesce(nullif(trim(p_item_elem->>'name_snapshot'), ''), 'Gift item');
    v_line_total := coalesce(
      nullif(v_line_meta->>'gift_line_total_amount', '')::numeric,
      greatest((v_quantity * v_sell_price) - v_line_discount, 0)
    );

    insert into public.bill_lines (
      tenant_id, invoice_id, shipment_item_id, product_id,
      name_snapshot, barcode_snapshot, product_code_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, assigned_child_tenant_id, line_meta
    ) values (
      p_parent_id, p_invoice_id, v_shipment_item_id, v_product_id,
      v_name_snapshot,
      nullif(trim(p_item_elem->>'barcode_snapshot'), ''),
      nullif(trim(p_item_elem->>'product_code_snapshot'), ''),
      v_quantity, v_sell_price, v_line_discount, v_line_total,
      nullif(p_item_elem->>'assigned_child_tenant_id', '')::bigint,
      v_line_meta
    )
    returning id into v_created_item_id;
    return v_created_item_id;
  end if;

  if v_global_stock_id is null then
    v_product_id := nullif(p_item_elem->>'product_id', '')::bigint;
    if v_product_id is not null
       and lower(trim(coalesce(p_item_elem->>'line_kind', 'stock'))) = 'stock' then
      v_shipment_item_id := nullif(p_item_elem->>'shipment_item_id', '')::bigint;
      v_name_snapshot := coalesce(nullif(trim(p_item_elem->>'name_snapshot'), ''), 'Item');
      v_barcode_snapshot := nullif(trim(p_item_elem->>'barcode_snapshot'), '');
      v_product_code_snapshot := nullif(trim(p_item_elem->>'product_code_snapshot'), '');
      v_line_total := greatest((v_quantity * v_sell_price) - v_line_discount, 0);
      if v_shipment_item_id is not null then
        select gsi.shipment_id into v_shipment_id
        from public.global_shipment_items gsi
        where gsi.id = v_shipment_item_id;
        v_line_meta := jsonb_set(
          coalesce(v_line_meta, '{}'::jsonb),
          '{shipment_ref}',
          jsonb_build_object(
            'shipment_item_id', v_shipment_item_id,
            'shipment_id', coalesce(
              nullif(p_item_elem->>'shipment_id', '')::bigint,
              v_shipment_id
            )
          ),
          true
        );
      end if;
      insert into public.bill_lines (
        tenant_id, invoice_id, line_kind, shipment_item_id, product_id,
        name_snapshot, barcode_snapshot, product_code_snapshot,
        quantity, sell_price_amount, line_discount_amount, line_total_amount, line_meta
      ) values (
        p_parent_id, p_invoice_id, 'stock', v_shipment_item_id, v_product_id,
        v_name_snapshot, v_barcode_snapshot, v_product_code_snapshot,
        v_quantity, v_sell_price, v_line_discount, v_line_total, v_line_meta
      )
      returning id into v_created_item_id;
      return v_created_item_id;
    end if;
    if v_line_kind = '' then
      v_line_kind := 'description';
    end if;
    if v_line_kind not in ('description', 'charge') then
      raise exception 'non-stock items require line_kind description or charge';
    end if;
    v_name_snapshot := coalesce(nullif(trim(p_item_elem->>'name_snapshot'), ''), 'Line');
    v_line_total := greatest((v_quantity * v_sell_price) - v_line_discount, 0);

    insert into public.bill_lines (
      tenant_id, invoice_id, line_kind, name_snapshot,
      quantity, sell_price_amount, line_discount_amount, line_total_amount,
      currency_code, books_amount, line_meta
    ) values (
      p_parent_id, p_invoice_id, v_line_kind, v_name_snapshot,
      v_quantity, v_sell_price, v_line_discount, v_line_total,
      upper(trim(coalesce(p_item_elem->>'currency_code', 'BDT'))),
      coalesce(nullif(p_item_elem->>'books_amount', '')::numeric, v_line_total),
      v_line_meta
    )
    returning id into v_created_item_id;
    return v_created_item_id;
  end if;

  select
    gs.tenant_id, gs.shipment_item_id, gsi.name, gsi.barcode, gsi.product_code,
    sh.assigned_child_tenant_id, p.id
  into
    v_stock_parent, v_shipment_item_id, v_name_snapshot, v_barcode_snapshot,
    v_product_code_snapshot, v_assigned_child, v_product_id
  from public.global_stocks gs
  left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  left join public.global_shipments sh on sh.id = gsi.shipment_id
  left join public.products p on p.id = gsi.product_id
  where gs.id = v_global_stock_id;

  if v_stock_parent is null then
    raise exception 'stock % not found', v_global_stock_id;
  end if;
  if v_stock_parent <> p_parent_id then
    raise exception 'stock % does not belong to invoice parent tenant', v_global_stock_id;
  end if;

  v_shipment_item_id := coalesce(nullif(p_item_elem->>'shipment_item_id', '')::bigint, v_shipment_item_id);
  v_product_id := coalesce(nullif(p_item_elem->>'product_id', '')::bigint, v_product_id);
  v_name_snapshot := coalesce(nullif(trim(p_item_elem->>'name_snapshot'), ''), v_name_snapshot, 'Item');
  v_line_total := coalesce(
    nullif(v_line_meta->>'gift_line_total_amount', '')::numeric,
    greatest((v_quantity * v_sell_price) - v_line_discount, 0)
  );

  v_line_meta := jsonb_set(
    coalesce(v_line_meta, '{}'::jsonb),
    '{stock_ref}',
    jsonb_build_object('global_stock_id', v_global_stock_id),
    true
  );

  if v_shipment_item_id is not null then
    select gsi.shipment_id into v_shipment_id
    from public.global_shipment_items gsi
    where gsi.id = v_shipment_item_id;
    v_line_meta := jsonb_set(
      v_line_meta,
      '{shipment_ref}',
      jsonb_build_object(
        'shipment_item_id', v_shipment_item_id,
        'shipment_id', v_shipment_id
      ),
      true
    );
  end if;

  insert into public.bill_lines (
    tenant_id, invoice_id, line_kind, shipment_item_id, product_id,
    name_snapshot, barcode_snapshot, product_code_snapshot, quantity,
    sell_price_amount, line_discount_amount, line_total_amount, assigned_child_tenant_id, line_meta
  ) values (
    p_parent_id, p_invoice_id, 'stock', v_shipment_item_id, v_product_id,
    v_name_snapshot, v_barcode_snapshot, v_product_code_snapshot,
    v_quantity, v_sell_price, v_line_discount, v_line_total, v_assigned_child, v_line_meta
  )
  returning id into v_created_item_id;
  return v_created_item_id;
end;
$$;

GRANT ALL ON FUNCTION public.list_shop_orders_staff_page(
  bigint, integer, text, text, bigint, text, bigint, timestamp with time zone, bigint
) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public._insert_bill_line_from_compose_payload(bigint, bigint, jsonb) TO anon, authenticated, service_role;
