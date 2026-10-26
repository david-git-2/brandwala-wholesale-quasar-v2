-- BP3 renamed billing_profile_id → profile_id on tables; redeploy RPC bodies that still
-- referenced f.billing_profile_id / o.billing_profile_id (from declarative schemas).

DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prosrc LIKE '%billing_profile_id%'
  LOOP
    EXECUTE format('DROP FUNCTION IF EXISTS %s CASCADE', r.sig);
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION "public"."add_pbc_backlog_to_costing_file"("p_file_id" bigint, "p_backlog_ids" bigint[]) RETURNS SETOF bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_file public.product_based_costing_files%ROWTYPE;
  v_backlog public.product_based_costing_backlog_items%ROWTYPE;
  v_new_item_id bigint;
BEGIN
  SELECT * INTO v_file
  FROM public.product_based_costing_files
  WHERE id = p_file_id;

  IF v_file.id IS NULL THEN
    RAISE EXCEPTION 'costing file % not found', p_file_id;
  END IF;

  IF NOT (
    public.can_admin_manage_costing_file(v_file.tenant_id)
    OR public.can_staff_access_costing_file(v_file.tenant_id)
  ) THEN
    RAISE EXCEPTION 'access denied for tenant %', v_file.tenant_id;
  END IF;

  IF v_file.profile_id IS NULL THEN
    RAISE EXCEPTION 'costing file % must have a profile_id assigned before consuming backlog', p_file_id;
  END IF;

  IF p_backlog_ids IS NULL OR array_length(p_backlog_ids, 1) IS NULL THEN
    RETURN;
  END IF;

  FOR v_backlog IN
    SELECT *
    FROM public.product_based_costing_backlog_items
    WHERE id = ANY(p_backlog_ids)
      AND tenant_id = v_file.tenant_id
      AND profile_id = v_file.profile_id
  LOOP
    INSERT INTO public.product_based_costing_items (
      product_based_costing_file_id,
      product_id,
      name,
      image_url,
      quantity,
      confirmed_quantity,
      delivered_quantity,
      price_gbp,
      product_weight,
      package_weight,
      barcode,
      product_code
    )
    VALUES (
      v_file.id,
      v_backlog.product_id,
      v_backlog.name,
      v_backlog.image_url,
      v_backlog.open_quantity,
      v_backlog.open_quantity,
      NULL,
      v_backlog.price_gbp,
      v_backlog.product_weight::integer,
      v_backlog.package_weight::integer,
      v_backlog.barcode,
      v_backlog.product_code
    )
    RETURNING id INTO v_new_item_id;

    DELETE FROM public.product_based_costing_backlog_items
    WHERE id = v_backlog.id;

    RETURN NEXT v_new_item_id;
  END LOOP;

  RETURN;
END;
$$;


CREATE OR REPLACE FUNCTION "public"."add_pbc_backlog_to_file"("p_file_id" bigint, "p_backlog_ids" bigint[]) RETURNS bigint[]
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_file public.product_based_costing_files%ROWTYPE;
  v_backlog public.product_based_costing_backlog_items%ROWTYPE;
  v_new_item_id bigint;
  v_added_ids bigint[] := ARRAY[]::bigint[];
BEGIN
  SELECT * INTO v_file
  FROM public.product_based_costing_files
  WHERE id = p_file_id;

  IF v_file.id IS NULL THEN
    RAISE EXCEPTION 'costing file % not found', p_file_id;
  END IF;

  IF NOT (
    public.can_admin_manage_costing_file(v_file.tenant_id)
    OR public.can_staff_access_costing_file(v_file.tenant_id)
  ) THEN
    RAISE EXCEPTION 'access denied for tenant %', v_file.tenant_id;
  END IF;

  IF v_file.profile_id IS NULL THEN
    RAISE EXCEPTION 'costing file % must have a profile_id assigned before consuming backlog', p_file_id;
  END IF;

  IF p_backlog_ids IS NULL OR array_length(p_backlog_ids, 1) IS NULL THEN
    RETURN v_added_ids;
  END IF;

  FOR v_backlog IN
    SELECT *
    FROM public.product_based_costing_backlog_items
    WHERE id = ANY(p_backlog_ids)
      AND tenant_id = v_file.tenant_id
      AND profile_id = v_file.profile_id
  LOOP
    INSERT INTO public.product_based_costing_items (
      product_based_costing_file_id,
      product_id,
      name,
      image_url,
      quantity,
      confirmed_quantity,
      delivered_quantity,
      price_gbp,
      product_weight,
      package_weight,
      barcode,
      product_code
    )
    VALUES (
      v_file.id,
      v_backlog.product_id,
      v_backlog.name,
      v_backlog.image_url,
      v_backlog.open_quantity,
      v_backlog.open_quantity,
      NULL,
      v_backlog.price_gbp,
      v_backlog.product_weight::integer,
      v_backlog.package_weight::integer,
      v_backlog.barcode,
      v_backlog.product_code
    )
    RETURNING id INTO v_new_item_id;

    DELETE FROM public.product_based_costing_backlog_items
    WHERE id = v_backlog.id;

    v_added_ids := array_append(v_added_ids, v_new_item_id);
  END LOOP;

  RETURN v_added_ids;
END;
$$;


CREATE OR REPLACE FUNCTION "public"."cancel_demand_bucket_item"("p_bucket_item_id" bigint) RETURNS "public"."customer_demand_bucket_items"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.customer_demand_bucket_items;
begin
  select * into v_row
  from public.customer_demand_bucket_items
  where id = p_bucket_item_id;

  if not found then
    raise exception 'bucket item not found: %', p_bucket_item_id;
  end if;

  if v_row.status <> 'open' then
    raise exception 'bucket item % is not open', p_bucket_item_id;
  end if;

  if not public.can_access_demand_bucket_profile(v_row.tenant_id, v_row.profile_id, true) then
    raise exception 'access denied';
  end if;

  update public.customer_demand_bucket_items
  set
    status = 'cancelled',
    updated_at = now()
  where id = p_bucket_item_id
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.purge_popped_demand_bucket_items(
  p_tenant_id bigint,
  p_retention_days integer default 90
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cutoff timestamptz;
  v_deleted integer;
  v_is_parent boolean;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  select (t.parent_id is null) into v_is_parent
  from public.tenants t
  where t.id = p_tenant_id;

  if coalesce(v_is_parent, false) then
    if not public.user_can_manage_parent_tenant(p_tenant_id) then
      raise exception 'access denied';
    end if;
  elsif not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  v_cutoff := now() - make_interval(days => greatest(coalesce(p_retention_days, 90), 1));

  delete from public.customer_demand_bucket_items b
  where b.status = 'popped'
    and b.popped_at is not null
    and b.popped_at < v_cutoff
    and (
      b.tenant_id = p_tenant_id
      or exists (
        select 1
        from public.tenants t
        where t.id = b.tenant_id
          and t.parent_id = p_tenant_id
      )
    );

  get diagnostics v_deleted = row_count;

  return jsonb_build_object(
    'tenant_id', p_tenant_id,
    'retention_days', greatest(coalesce(p_retention_days, 90), 1),
    'deleted_count', v_deleted
  );
end;
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

  if v_doc_status <> 'packed' then
    raise exception 'document must be packed to close picks';
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
$_$;;


CREATE OR REPLACE FUNCTION "public"."create_customer_account"("p_tenant_id" bigint, "p_group_name" "text", "p_admin_name" "text" DEFAULT NULL::"text", "p_admin_email" "text" DEFAULT NULL::"text", "p_phone" "text" DEFAULT NULL::"text", "p_address" "text" DEFAULT NULL::"text", "p_accent_color" "text" DEFAULT '#B45F34'::"text", "p_phone_country_code" "text" DEFAULT '+880'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_group public.customer_groups;
  v_profile public.profiles;
  v_profile_id bigint;
  v_books_id bigint;
  v_clean_phone text;
  v_clean_code text;
  v_clean_group_name text;
  v_clean_color text;
begin
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  if not public.can_administer_customer_group(v_books_id) then
    raise exception 'Only parent tenant admins can create customer groups';
  end if;

  v_clean_group_name := trim(coalesce(p_group_name, ''));
  v_clean_phone := nullif(regexp_replace(trim(coalesce(p_phone, '')), '[^0-9]', '', 'g'), '');
  v_clean_code := coalesce(nullif(trim(coalesce(p_phone_country_code, '')), ''), '+880');
  if v_clean_code not like '+%' then
    v_clean_code := '+' || v_clean_code;
  end if;
  v_clean_color := coalesce(nullif(trim(coalesce(p_accent_color, '')), ''), '#B45F34');

  if v_clean_group_name = '' then
    raise exception 'Group / Company name is required';
  end if;
  if v_clean_phone is null then
    raise exception 'Phone is required';
  end if;

  if exists (
    select 1
    from public.profiles pr
    left join public.customer_groups cg on cg.id = pr.customer_group_id
    where pr.profile_type = 'customer'::public.profile_party_type
      and pr.parent_tenant_id = v_books_id
      and pr.phone_country_code = v_clean_code
      and pr.phone = v_clean_phone
      and pr.is_phone_unique
      and (cg.id is null or cg.deleted_at is null)
  ) then
    raise exception 'This phone is already used by another customer';
  end if;

  insert into public.customer_groups (
    tenant_id,
    parent_tenant_id,
    name,
    accent_color,
    is_active
  ) values (
    v_books_id,
    v_books_id,
    v_clean_group_name,
    v_clean_color,
    true
  )
  returning * into v_group;

  select * into v_profile
  from public.profiles
  where customer_group_id = v_group.id
    and profile_type = 'customer'::public.profile_party_type
  order by id asc
  limit 1;

  if v_profile.id is null then
    insert into public.profiles (
      parent_tenant_id,
      profile_type,
      subject_id,
      customer_group_id,
      operating_tenant_id,
      name,
      phone,
      phone_country_code,
      address,
      accent_color,
      is_active,
      created_at,
      updated_at
    ) values (
      v_books_id,
      'customer'::public.profile_party_type,
      v_group.id,
      v_group.id,
      v_books_id,
      v_clean_group_name,
      v_clean_phone,
      v_clean_code,
      nullif(trim(coalesce(p_address, '')), ''),
      v_clean_color,
      true,
      now(),
      now()
    )
    returning * into v_profile;

    update public.profiles
    set subject_id = v_profile.id
    where id = v_profile.id;
  else
    update public.profiles
    set
      name = v_clean_group_name,
      phone = v_clean_phone,
      phone_country_code = v_clean_code,
      parent_tenant_id = v_books_id,
      operating_tenant_id = v_books_id,
      address = coalesce(nullif(trim(coalesce(p_address, '')), ''), address),
      updated_at = now()
    where id = v_profile.id
    returning * into v_profile;
  end if;

  insert into public.cashbook_accounts (
    tenant_id,
    parent_tenant_id,
    entity_type,
    entity_id,
    currency_code,
    available_balance,
    locked_balance,
    pending_balance
  ) values (
    v_books_id,
    v_books_id,
    'customer',
    v_profile.id,
    'BDT',
    0.0000,
    0.0000,
    0.0000
  )
  on conflict (tenant_id, entity_type, entity_id, currency_code) do nothing;

  return jsonb_build_object(
    'id', v_group.id,
    'customer_group_id', v_group.id,
    'profile_id', v_profile.id,
    'group_name', v_group.name,
    'admin_name', v_profile.name,
    'email', v_profile.email,
    'phone', concat_ws(' ', v_profile.phone_country_code, v_profile.phone),
    'address', v_profile.address,
    'accent_color', coalesce(v_group.accent_color, '#B45F34'),
    'is_active', v_group.is_active,
    'member_count', 0,
    'wallet_available_balance', 0,
    'created_at', v_group.created_at
  );
end;
$$;


CREATE OR REPLACE FUNCTION "public"."create_invoice_from_preorder_demand_document"("p_tenant_id" bigint, "p_document_type" "text", "p_document_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_profile_id bigint;
  v_operating_tenant_id bigint;
  v_existing_invoice_id bigint;
  v_doc_status text;
  v_items jsonb := '[]'::jsonb;
  v_pick_elem jsonb;
  v_pd record;
  v_sell_price numeric(12,2);
  v_global_stock_id bigint;
  v_qty integer;
  v_payload jsonb;
  v_result jsonb;
  v_invoice_id bigint;
begin
  if p_tenant_id is null or p_document_id is null then
    raise exception 'tenant_id and document_id are required';
  end if;

  if v_doc_type = 'shop_order' then
    select
      o.tenant_id,
      o.profile_id,
      o.global_invoice_id,
      public.normalize_shop_order_procurement_status(o.status)
    into v_operating_tenant_id, v_profile_id, v_existing_invoice_id, v_doc_status
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
    into v_operating_tenant_id, v_profile_id, v_existing_invoice_id, v_doc_status
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

  if v_doc_status <> 'procuring' then
    raise exception 'document must be procuring to create invoice from demand';
  end if;

  if v_profile_id is null then
    raise exception 'profile_id is required on document';
  end if;

  if v_existing_invoice_id is not null then
    return jsonb_build_object(
      'success', true,
      'invoice_id', v_existing_invoice_id,
      'created', false
    );
  end if;

  if v_doc_type = 'shop_order' then
    for v_pd in
      select
        pd.stock_picks,
        coalesce(oi.final_price_amount, oi.staff_offer_amount, 0)::numeric(12,2) as sell_price
      from public.preorder_demand pd
      inner join public.shop_order_items oi
        on pd.source_type = 'shop_order_item'
        and pd.source_id = oi.id
      where oi.order_id = p_document_id
        and jsonb_array_length(coalesce(pd.stock_picks, '[]'::jsonb)) > 0
    loop
      v_sell_price := v_pd.sell_price;
      for v_pick_elem in
        select value from jsonb_array_elements(coalesce(v_pd.stock_picks, '[]'::jsonb))
      loop
        v_global_stock_id := nullif(v_pick_elem->>'global_stock_id', '')::bigint;
        v_qty := coalesce((v_pick_elem->>'quantity')::integer, 0);
        if v_global_stock_id is not null and v_qty > 0 then
          v_items := v_items || jsonb_build_array(jsonb_build_object(
            'global_stock_id', v_global_stock_id,
            'quantity', v_qty,
            'sell_price_amount', v_sell_price
          ));
        end if;
      end loop;
    end loop;
  else
    for v_pd in
      select
        pd.stock_picks,
        coalesce(pci.offer_price, 0)::numeric(12,2) as sell_price
      from public.preorder_demand pd
      inner join public.product_based_costing_items pci
        on pd.source_type = 'pbc_costing_item'
        and pd.source_id = pci.id
      where pci.product_based_costing_file_id = p_document_id
        and jsonb_array_length(coalesce(pd.stock_picks, '[]'::jsonb)) > 0
    loop
      v_sell_price := v_pd.sell_price;
      for v_pick_elem in
        select value from jsonb_array_elements(coalesce(v_pd.stock_picks, '[]'::jsonb))
      loop
        v_global_stock_id := nullif(v_pick_elem->>'global_stock_id', '')::bigint;
        v_qty := coalesce((v_pick_elem->>'quantity')::integer, 0);
        if v_global_stock_id is not null and v_qty > 0 then
          v_items := v_items || jsonb_build_array(jsonb_build_object(
            'global_stock_id', v_global_stock_id,
            'quantity', v_qty,
            'sell_price_amount', v_sell_price
          ));
        end if;
      end loop;
    end loop;
  end if;

  if jsonb_array_length(v_items) = 0 then
    raise exception 'at least one stock pick is required before marking ready for shipment';
  end if;

  v_payload := jsonb_build_object(
    'invoice', jsonb_build_object(
      'invoice_type', 'wholesale',
      'profile_id', v_profile_id
    ),
    'items', v_items,
    'issue', false
  );

  v_result := public.create_sales_invoice_from_payload(v_operating_tenant_id, v_payload);

  if coalesce(v_result->>'success', 'false') <> 'true' then
    raise exception '%', coalesce(v_result->>'error', 'failed to create invoice from demand');
  end if;

  v_invoice_id := (v_result->>'invoice_id')::bigint;

  update public.bills
  set
    invoice_status = 'proforma_generated'::public.global_invoice_status,
    shop_order_id = case when v_doc_type = 'shop_order' then p_document_id else shop_order_id end,
    updated_at = now()
  where id = v_invoice_id
    and invoice_status = 'draft'::public.global_invoice_status;

  if v_doc_type = 'shop_order' then
    update public.shop_orders
    set
      global_invoice_id = v_invoice_id,
      updated_at = now()
    where id = p_document_id
      and global_invoice_id is null;
  else
    update public.product_based_costing_files
    set
      invoice_id = v_invoice_id,
      updated_at = now()
    where id = p_document_id
      and invoice_id is null;
  end if;

  return v_result || jsonb_build_object(
    'created', true,
    'invoice_status', 'proforma_generated'
  );
end;
$$;


CREATE OR REPLACE FUNCTION "public"."fill_preorder_demand_oldest_stock_for_document"("p_tenant_id" bigint, "p_document_type" "text", "p_document_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_is_parent boolean;
  v_allowed boolean := false;
  v_line_tenant_id bigint;
  v_doc_status text;
  v_parent_tenant_id bigint;
  v_updated integer := 0;
  v_skipped integer := 0;
  r record;
  v_stock record;
  v_total_avail integer := 0;
  v_remaining integer;
  v_avail integer;
  v_take integer;
  v_picks jsonb;
  v_delivered integer;
  v_db_reserved integer;
  v_run_reserved integer;
begin
  if p_tenant_id is null or p_document_id is null then
    raise exception 'tenant_id and document_id are required';
  end if;

  create temp table if not exists fifo_run_pick_reserve (
    global_stock_id bigint primary key,
    reserved_qty integer not null default 0
  ) on commit delete rows;
  delete from fifo_run_pick_reserve where true;

  select (t.parent_id is null) into v_is_parent from public.tenants t where t.id = p_tenant_id;
  if not found then
    raise exception 'tenant not found: %', p_tenant_id;
  end if;

  if v_is_parent then
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  else
    v_allowed := public.is_tenant_staff(p_tenant_id);
  end if;
  if not coalesce(v_allowed, false) then
    raise exception 'access denied';
  end if;

  if v_doc_type = 'shop_order' then
    select
      o.tenant_id,
      public.normalize_shop_order_procurement_status(o.status)
    into v_line_tenant_id, v_doc_status
    from public.shop_orders o
    where o.id = p_document_id
      and o.shop_type_snapshot = 'vendor_catalog';

    if v_line_tenant_id is null then
      raise exception 'shop order not found or not vendor catalog';
    end if;
  elsif v_doc_type = 'pbc_costing_file' then
    select
      f.tenant_id,
      public.normalize_pbc_procurement_status(f.status)
    into v_line_tenant_id, v_doc_status
    from public.product_based_costing_files f
    where f.id = p_document_id
      and f.profile_id is not null;

    if v_line_tenant_id is null then
      raise exception 'costing file not found';
    end if;
  else
    raise exception 'invalid document_type: %', p_document_type;
  end if;

  if not public.can_access_preorder_demand_tenant(p_tenant_id)
    and not public.can_access_preorder_demand_tenant(v_line_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_line_tenant_id <> p_tenant_id then
    if not exists (
      select 1
      from public.tenants t
      where t.id = v_line_tenant_id
        and t.parent_id = p_tenant_id
        and public.user_can_manage_parent_tenant(p_tenant_id)
    ) then
      raise exception 'tenant mismatch for demand document';
    end if;
  end if;

  if v_doc_status not in ('procuring', 'packed') then
    raise exception 'document is not open for stock pick updates';
  end if;

  select coalesce(t.parent_id, t.id) into v_parent_tenant_id
  from public.tenants t
  where t.id = v_line_tenant_id;

  for r in
    select
      q.source_type,
      q.source_id,
      q.tenant_id,
      q.product_id,
      q.need_qty
    from (
      select
        'shop_order_item'::public.preorder_demand_source_type as source_type,
        oi.id as source_id,
        o.tenant_id,
        oi.product_id,
        greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer as need_qty
      from public.shop_order_items oi
      inner join public.shop_orders o on o.id = oi.order_id
      where v_doc_type = 'shop_order'
        and o.id = p_document_id
        and o.shop_type_snapshot = 'vendor_catalog'
      union all
      select
        'pbc_costing_item'::public.preorder_demand_source_type,
        pci.id,
        f.tenant_id,
        pci.product_id,
        greatest(
          case
            when pci.assigned_shipment_id is not null then 0
            else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
          end,
          0
        )::integer
      from public.product_based_costing_items pci
      inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
      where v_doc_type = 'pbc_costing_file'
        and f.id = p_document_id
        and f.profile_id is not null
    ) q
    order by q.source_id
  loop
    if r.product_id is null or r.need_qty <= 0 then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    if exists (
      select 1
      from public.preorder_demand pd
      where pd.source_type = r.source_type
        and pd.source_id = r.source_id
        and public.sum_preorder_stock_picks(pd.stock_picks) > 0
    ) then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    v_total_avail := 0;
    for v_stock in
      select
        gs.id as global_stock_id,
        floor(public.global_stock_atp_qty(gs.id))::integer as atp
      from public.global_stocks gs
      inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
      left join public.stock_locations sl on sl.id = gs.location_id
      where gs.parent_tenant_id = v_parent_tenant_id
        and gs.is_archived = false
        and gsi.product_id = r.product_id
        and gs.availability = 'sellable'::public.stock_availability
        and (gs.location_id is null or sl.is_pickable = true)
      order by gs.created_at, gs.id
    loop
      select coalesce(sum((e.value->>'quantity')::integer), 0)::integer
      into v_db_reserved
      from public.preorder_demand pd
      cross join jsonb_array_elements(coalesce(pd.stock_picks, '[]'::jsonb)) e(value)
      where nullif(e.value->>'global_stock_id', '')::bigint = v_stock.global_stock_id;

      v_run_reserved := coalesce((
        select fr.reserved_qty
        from fifo_run_pick_reserve fr
        where fr.global_stock_id = v_stock.global_stock_id
      ), 0);

      v_avail := greatest(v_stock.atp - v_db_reserved - v_run_reserved, 0);
      v_total_avail := v_total_avail + v_avail;
    end loop;

    if v_total_avail < r.need_qty then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    v_picks := '[]'::jsonb;
    v_remaining := r.need_qty;

    for v_stock in
      select
        gs.id as global_stock_id,
        sh.name as shipment_name,
        sl.name as location_name,
        floor(public.global_stock_atp_qty(gs.id))::integer as atp
      from public.global_stocks gs
      inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
      inner join public.global_shipments sh on sh.id = gsi.shipment_id
      left join public.stock_locations sl on sl.id = gs.location_id
      where gs.parent_tenant_id = v_parent_tenant_id
        and gs.is_archived = false
        and gsi.product_id = r.product_id
        and gs.availability = 'sellable'::public.stock_availability
        and (gs.location_id is null or sl.is_pickable = true)
      order by gs.created_at, gs.id
    loop
      select coalesce(sum((e.value->>'quantity')::integer), 0)::integer
      into v_db_reserved
      from public.preorder_demand pd
      cross join jsonb_array_elements(coalesce(pd.stock_picks, '[]'::jsonb)) e(value)
      where nullif(e.value->>'global_stock_id', '')::bigint = v_stock.global_stock_id;

      v_run_reserved := coalesce((
        select fr.reserved_qty
        from fifo_run_pick_reserve fr
        where fr.global_stock_id = v_stock.global_stock_id
      ), 0);

      v_avail := greatest(v_stock.atp - v_db_reserved - v_run_reserved, 0);
      if v_avail <= 0 then
        continue;
      end if;

      v_take := least(v_avail, v_remaining);
      v_picks := v_picks || jsonb_build_array(
        jsonb_build_object(
          'global_stock_id', v_stock.global_stock_id,
          'quantity', v_take,
          'shipment_name', coalesce(v_stock.shipment_name, ''),
          'location_name', coalesce(v_stock.location_name, '')
        )
      );

      insert into fifo_run_pick_reserve (global_stock_id, reserved_qty)
      values (v_stock.global_stock_id, v_take)
      on conflict (global_stock_id) do update
        set reserved_qty = fifo_run_pick_reserve.reserved_qty + excluded.reserved_qty;

      v_remaining := v_remaining - v_take;
      if v_remaining <= 0 then
        exit;
      end if;
    end loop;

    if v_remaining > 0 then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    v_delivered := public.sum_preorder_stock_picks(v_picks);

    insert into public.preorder_demand (
      tenant_id,
      source_type,
      source_id,
      placed_quantity,
      delivered_quantity,
      stock_picks,
      updated_by_user_id
    ) values (
      r.tenant_id,
      r.source_type,
      r.source_id,
      0,
      v_delivered,
      v_picks,
      auth.uid()
    )
    on conflict (source_type, source_id) do update set
      delivered_quantity = excluded.delivered_quantity,
      stock_picks = excluded.stock_picks,
      updated_by_user_id = auth.uid(),
      updated_at = now();

    v_updated := v_updated + 1;
  end loop;

  return jsonb_build_object(
    'document_type', v_doc_type,
    'document_id', p_document_id,
    'updated_count', v_updated,
    'skipped_count', v_skipped
  );
end;
$$;


CREATE OR REPLACE FUNCTION "public"."fill_preorder_demand_placed_quantities_for_document"("p_tenant_id" bigint, "p_document_type" "text", "p_document_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_is_parent boolean;
  v_allowed boolean := false;
  v_line_tenant_id bigint;
  v_doc_status text;
  v_updated integer := 0;
begin
  if p_tenant_id is null or p_document_id is null then
    raise exception 'tenant_id and document_id are required';
  end if;

  select (t.parent_id is null) into v_is_parent from public.tenants t where t.id = p_tenant_id;
  if not found then
    raise exception 'tenant not found: %', p_tenant_id;
  end if;

  if v_is_parent then
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  else
    v_allowed := public.is_tenant_staff(p_tenant_id);
  end if;
  if not coalesce(v_allowed, false) then
    raise exception 'access denied';
  end if;

  if v_doc_type = 'shop_order' then
    select
      o.tenant_id,
      public.normalize_shop_order_procurement_status(o.status)
    into v_line_tenant_id, v_doc_status
    from public.shop_orders o
    where o.id = p_document_id
      and o.shop_type_snapshot = 'vendor_catalog';

    if v_line_tenant_id is null then
      raise exception 'shop order not found or not vendor catalog';
    end if;
  elsif v_doc_type = 'pbc_costing_file' then
    select
      f.tenant_id,
      public.normalize_pbc_procurement_status(f.status)
    into v_line_tenant_id, v_doc_status
    from public.product_based_costing_files f
    where f.id = p_document_id
      and f.profile_id is not null;

    if v_line_tenant_id is null then
      raise exception 'costing file not found';
    end if;
  else
    raise exception 'invalid document_type: %', p_document_type;
  end if;

  if not public.can_access_preorder_demand_tenant(p_tenant_id)
    and not public.can_access_preorder_demand_tenant(v_line_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_line_tenant_id <> p_tenant_id then
    if not exists (
      select 1
      from public.tenants t
      where t.id = v_line_tenant_id
        and t.parent_id = p_tenant_id
        and public.user_can_manage_parent_tenant(p_tenant_id)
    ) then
      raise exception 'tenant mismatch for demand document';
    end if;
  end if;

  if v_doc_status <> 'procuring' then
    raise exception 'document is not open for placed quantity updates';
  end if;

  if v_doc_type = 'shop_order' then
    with lines as (
      select
        o.tenant_id,
        oi.id as source_id,
        greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer as need_qty
      from public.shop_order_items oi
      inner join public.shop_orders o on o.id = oi.order_id
      where o.id = p_document_id
        and o.shop_type_snapshot = 'vendor_catalog'
    ),
    upserted as (
      insert into public.preorder_demand (
        tenant_id,
        source_type,
        source_id,
        placed_quantity,
        delivered_quantity,
        stock_picks,
        updated_by_user_id
      )
      select
        l.tenant_id,
        'shop_order_item'::public.preorder_demand_source_type,
        l.source_id,
        l.need_qty,
        0,
        '[]'::jsonb,
        auth.uid()
      from lines l
      on conflict (source_type, source_id) do update set
        placed_quantity = excluded.placed_quantity,
        updated_by_user_id = auth.uid(),
        updated_at = now()
      returning 1
    )
    select count(*)::integer into v_updated from upserted;
  else
    with lines as (
      select
        f.tenant_id,
        pci.id as source_id,
        greatest(
          case
            when pci.assigned_shipment_id is not null then 0
            else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
          end,
          0
        )::integer as need_qty
      from public.product_based_costing_items pci
      inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
      where f.id = p_document_id
        and f.profile_id is not null
    ),
    upserted as (
      insert into public.preorder_demand (
        tenant_id,
        source_type,
        source_id,
        placed_quantity,
        delivered_quantity,
        stock_picks,
        updated_by_user_id
      )
      select
        l.tenant_id,
        'pbc_costing_item'::public.preorder_demand_source_type,
        l.source_id,
        l.need_qty,
        0,
        '[]'::jsonb,
        auth.uid()
      from lines l
      on conflict (source_type, source_id) do update set
        placed_quantity = excluded.placed_quantity,
        updated_by_user_id = auth.uid(),
        updated_at = now()
      returning 1
    )
    select count(*)::integer into v_updated from upserted;
  end if;

  return jsonb_build_object(
    'document_type', v_doc_type,
    'document_id', p_document_id,
    'updated_count', v_updated
  );
end;
$$;


CREATE OR REPLACE FUNCTION "public"."finalize_dropship_return"("p_order_id" bigint, "p_items" "jsonb", "p_actual_return_charge" numeric DEFAULT 0.00, "p_deduct_from_middle_man" boolean DEFAULT true, "p_override_reason" "text" DEFAULT NULL::"text", "p_return_ref" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order record;
  v_invoice record;
  v_parent_tenant_id bigint;
  v_ref text;
  v_item_elem jsonb;
  v_order_item_id bigint;
  v_returned_qty numeric;
  v_condition text;
  v_order_item record;
  v_invoice_item record;
  v_stock record;
  v_target_stock_type_id bigint;
  v_target_stock_id bigint;
  v_net_delivered numeric;
  v_currency text;
  v_profile_id bigint;
  v_is_remitted boolean := false;
  v_existing_ref_order_id bigint;
  v_profit numeric(12,2) := 0;
  v_revenue numeric(12,2) := 0;
  v_billed numeric(12,2) := 0;
  v_remit_net numeric(12,2) := 0;
  v_courier_charge numeric(12,2) := 0;
  v_has_billed boolean := false;
  v_has_profit boolean := false;
  v_grade_tag_id bigint;
  v_to_availability public.stock_availability;
  v_to_availability_raw text;
  v_use_explicit_targets boolean := false;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    raise exception 'Shop order #% not found', p_order_id;
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'Order #% is not a dropship order', p_order_id;
  end if;

  v_currency := 'BDT';
  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  if not (
    public.user_can_manage_parent_tenant(v_parent_tenant_id)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_order.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: Staff or Admin role required';
  end if;

  v_ref := nullif(trim(coalesce(p_return_ref, '')), '');
  if v_ref is not null then
    select id into v_existing_ref_order_id
    from public.shop_orders
    where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
      and return_ref = v_ref;

    if v_existing_ref_order_id is not null then
      if v_existing_ref_order_id = p_order_id and v_order.return_sub_state = 'return_finalized' then
        return jsonb_build_object(
          'success', true,
          'idempotent', true,
          'message', 'Return already finalized with reference ' || v_ref,
          'order_id', p_order_id
        );
      else
        raise exception 'Duplicate return reference % already used for another return', v_ref;
      end if;
    end if;
  end if;

  if v_order.return_sub_state = 'return_finalized' then
    return jsonb_build_object(
      'success', true,
      'idempotent', true,
      'message', 'Order return is already finalized',
      'order_id', p_order_id
    );
  end if;

  if v_order.global_invoice_id is not null then
    select * into v_invoice from public.bills where id = v_order.global_invoice_id for update;
  end if;

  v_profile_id := v_order.profile_id;
  if v_profile_id is null and v_order.customer_group_id is not null then
    select id into v_profile_id
    from public.profiles
    where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
      and customer_group_id = v_order.customer_group_id
    order by is_default desc, created_at asc
    limit 1;
  end if;

  if p_items is not null and jsonb_array_length(p_items) > 0 then
    for v_item_elem in select * from jsonb_array_elements(p_items) loop
      v_order_item_id := (v_item_elem->>'order_item_id')::bigint;
      v_returned_qty := coalesce((v_item_elem->>'returned_qty')::numeric, 0);
      v_condition := coalesce(lower(trim(v_item_elem->>'condition')), 'perfect');
      v_grade_tag_id := nullif((v_item_elem->>'grade_tag_id')::bigint, 0);
      v_to_availability_raw := nullif(lower(trim(v_item_elem->>'to_availability')), '');
      v_use_explicit_targets := v_grade_tag_id is not null or v_to_availability_raw is not null;

      if v_returned_qty <= 0 then
        continue;
      end if;

      select * into v_order_item
      from public.shop_order_items
      where id = v_order_item_id and order_id = p_order_id for update;

      if v_order_item.id is null then
        raise exception 'Order item #% not found on order #%', v_order_item_id, p_order_id;
      end if;

      v_net_delivered := coalesce(v_order_item.confirmed_quantity, v_order_item.quantity) - coalesce(v_order_item.returned_quantity, 0);
      if v_returned_qty > v_net_delivered then
        raise exception 'Returned quantity % exceeds net delivered quantity % for item #%', v_returned_qty, v_net_delivered, v_order_item_id;
      end if;

      if v_use_explicit_targets then
        v_grade_tag_id := coalesce(
          v_grade_tag_id,
          v_order_item.grade_tag_id,
          public.default_stock_grade_tag_id()
        );
        v_to_availability := coalesce(
          v_to_availability_raw::public.stock_availability,
          'held'::public.stock_availability
        );
      else
        v_to_availability := case
          when v_condition = 'damaged' then 'unsellable'::public.stock_availability
          else 'held'::public.stock_availability
        end;
        v_grade_tag_id := public.stock_grade_tag_id_for_slug(
          case v_condition
            when 'open_box' then 'open_box'
            when 'damaged' then 'badly_damaged'
            else 'standard'
          end
        );
      end if;

      select * into v_stock from public.global_stocks where id = v_order_item.global_stock_id;

      if v_stock.id is not null then
        perform public.create_and_post_stock_movement(
          v_parent_tenant_id,
          v_stock.id,
          ceil(v_returned_qty)::integer,
          public.default_returns_stock_location_id(v_parent_tenant_id),
          v_to_availability,
          v_grade_tag_id,
          'return_inbound'::public.stock_movement_type,
          coalesce(p_override_reason, 'Dropship return'),
          'shop_order',
          p_order_id::text
        );
      end if;

      update public.shop_order_items
      set returned_quantity = coalesce(returned_quantity, 0) + v_returned_qty, updated_at = now()
      where id = v_order_item_id;

      if v_invoice.id is not null then
        select * into v_invoice_item
        from public.global_invoice_items
        where invoice_id = v_invoice.id
          and (global_stock_id = v_order_item.global_stock_id or product_id = v_order_item.product_id)
        limit 1;

        if v_invoice_item.id is not null then
          -- global_return_items schema: quantity + return_charge_amount only (no return_amount / face / accounting)
          insert into public.global_return_items (
            tenant_id, parent_tenant_id, invoice_id, invoice_item_id, global_stock_id,
            quantity, return_charge_amount, note
          )
          values (
            v_invoice.parent_tenant_id, v_invoice.parent_tenant_id, v_invoice.id, v_invoice_item.id, v_order_item.global_stock_id,
            v_returned_qty, 0.00, coalesce(p_override_reason, 'Dropship return finalization')
          );

          update public.global_invoice_items
          set return_quantity = coalesce(return_quantity, 0) + v_returned_qty, updated_at = now()
          where id = v_invoice_item.id;
        end if;
      end if;
    end loop;
  end if;

  if v_invoice.id is not null then
    perform public.recompute_global_invoice_totals(v_invoice.id);
  end if;

  select exists (
    select 1 from public.cashbook_entries
    where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'tenant_remittance_received'
  ) into v_is_remitted;

  -- Resolve amounts from UWL (canonical after billing-profile unification)
  select coalesce(sum(case when type = 'credit' then base_amount else -base_amount end), 0)
  into v_billed
  from public.cashbook_entries
  where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and entity_type = 'customer'
    and entity_id = v_profile_id
    and metadata->>'transaction_type' in ('invoice_billed', 'return_reversal', 'invoice_collection');

  -- Net billed outstanding before clawback: invert so positive = amount still billed
  v_billed := greatest(-v_billed, 0);
  v_has_billed := v_billed > 0 or exists (
    select 1 from public.cashbook_entries
    where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'transaction_type' = 'invoice_billed'
  );

  select coalesce(sum(case when type = 'credit' then base_amount else -base_amount end), 0)
  into v_profit
  from public.cashbook_entries
  where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and entity_type in ('customer', 'middleman')
    and entity_id = v_profile_id
    and metadata->>'section' = 'payout_earned';

  v_profit := greatest(v_profit, 0);
  v_has_profit := v_profit > 0;

  select coalesce(sum(case when type = 'credit' then base_amount else -base_amount end), 0)
  into v_revenue
  from public.cashbook_entries
  where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and entity_type = 'tenant'
    and metadata->>'transaction_type' = 'revenue';

  if v_revenue <= 0 then
    v_revenue := coalesce(v_invoice.total_amount, 0.00);
  end if;

  select coalesce((metadata->>'net_remitted')::numeric, amount, 0)
  into v_remit_net
  from public.cashbook_entries
  where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'tenant_remittance_received'
  limit 1;

  select coalesce((metadata->>'courier_charge')::numeric, amount, 0)
  into v_courier_charge
  from public.cashbook_entries
  where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'tenant_courier_charge'
  limit 1;

  -- Leg 1: Reverse remaining invoice billed / collection net on customer
  if v_profile_id is not null and v_has_billed and v_billed > 0
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_reversal'
     )
  then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_profile_id,
      p_type => 'credit',
      p_amount => v_billed,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'receivable',
        'transaction_type', 'return_reversal',
        'label', 'Return Billed Reversal',
        'order_no', v_order.order_no,
        'return_ref', v_ref
      )
    );
  elsif v_profile_id is not null and v_has_billed and v_billed = 0
     and exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'invoice_billed'
     )
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_reversal'
     )
  then
    -- Invoice fully collected already — reverse original billed amount then reverse collection net via billed lookup
    select coalesce(base_amount, 0) into v_billed
    from public.cashbook_entries
    where source_type = 'shop_order' and source_id = p_order_id::text
      and metadata->>'transaction_type' = 'invoice_billed'
    limit 1;

    if v_billed > 0 then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_profile_id,
        p_type => 'credit',
        p_amount => v_billed,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'receivable',
          'transaction_type', 'return_reversal',
          'label', 'Return Billed Reversal',
          'order_no', v_order.order_no,
          'return_ref', v_ref
        )
      );

      if exists (
        select 1 from public.cashbook_entries
        where source_type = 'shop_order' and source_id = p_order_id::text
          and metadata->>'transaction_type' = 'invoice_collection'
      ) then
        perform public.record_ledger_transaction(
          p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
          p_entity_type => 'customer',
          p_entity_id => v_profile_id,
          p_type => 'debit',
          p_amount => v_billed,
          p_currency_code => v_currency,
          p_exchange_rate => 1.000000,
          p_source_type => 'shop_order',
          p_source_id => p_order_id::text,
          p_metadata => jsonb_build_object(
            'section', 'receivable',
            'transaction_type', 'return_collection_reversal',
            'label', 'Return Collection Reversal',
            'order_no', v_order.order_no,
            'return_ref', v_ref
          )
        );
      end if;
    end if;

  -- Historical remittance path: invoice_collection posted without invoice_billed.
  -- Unwind collection only (no synthetic return_reversal credit).
  elsif v_profile_id is not null
     and exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'invoice_collection'
     )
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'invoice_billed'
     )
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_collection_reversal'
     )
  then
    select coalesce(sum(base_amount), 0) into v_billed
    from public.cashbook_entries
    where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and entity_type = 'customer'
      and entity_id = v_profile_id
      and type = 'credit'
      and metadata->>'transaction_type' = 'invoice_collection';

    if v_billed > 0 then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_profile_id,
        p_type => 'debit',
        p_amount => v_billed,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'receivable',
          'transaction_type', 'return_collection_reversal',
          'label', 'Return Collection Reversal',
          'order_no', v_order.order_no,
          'return_ref', v_ref
        )
      );
    end if;
  end if;

  -- Leg 2: Claw back profit on customer (unified billing-profile wallet)
  if v_profile_id is not null and v_has_profit
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_profit_clawback'
     )
  then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_profile_id,
      p_type => 'debit',
      p_amount => v_profit,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'payout_earned',
        'transaction_type', 'return_profit_clawback',
        'label', 'Return Profit Reversal',
        'order_no', v_order.order_no,
        'return_ref', v_ref
      )
    );
  end if;

  -- Leg 3: Reverse tenant revenue
  if v_revenue > 0
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_revenue_reversal'
     )
  then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_type => 'debit',
      p_amount => v_revenue,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'revenue',
        'transaction_type', 'return_revenue_reversal',
        'label', 'Return Revenue Reversal',
        'order_no', v_order.order_no,
        'return_ref', v_ref
      )
    );
  end if;

  -- Leg 4: Reverse remittance cash + courier fee if remitted
  if v_is_remitted then
    if coalesce(v_remit_net, 0) > 0
       and not exists (
         select 1 from public.cashbook_entries
         where source_type = 'shop_order' and source_id = p_order_id::text
           and metadata->>'purpose' = 'remittance_return_reversal'
       )
    then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => public.resolve_parent_tenant_id(v_order.tenant_id),
        p_type => 'debit',
        p_amount => v_remit_net,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'payment_received',
          'purpose', 'remittance_return_reversal',
          'transaction_type', 'remittance_return_reversal',
          'label', 'Remittance Return Reversal',
          'order_no', v_order.order_no,
          'return_ref', v_ref
        )
      );
    end if;

    if coalesce(v_courier_charge, 0) > 0
       and not exists (
         select 1 from public.cashbook_entries
         where source_type = 'shop_order' and source_id = p_order_id::text
           and metadata->>'purpose' = 'courier_charge_return_reversal'
       )
    then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => public.resolve_parent_tenant_id(v_order.tenant_id),
        p_type => 'credit',
        p_amount => v_courier_charge,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'delivery_fee',
          'purpose', 'courier_charge_return_reversal',
          'transaction_type', 'courier_charge_return_reversal',
          'label', 'Courier Fee Return Reversal',
          'order_no', v_order.order_no,
          'return_ref', v_ref
        )
      );
    end if;
  end if;

  -- Return fee: UWL only (legacy middle_man_payout_ledger was dropped)
  if p_deduct_from_middle_man
     and p_actual_return_charge > 0
     and v_profile_id is not null
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order'
         and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_fee'
     )
  then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_profile_id,
      p_type => 'debit',
      p_amount => p_actual_return_charge,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'payout_earned',
        'transaction_type', 'return_fee',
        'label', 'Return Fee',
        'order_no', v_order.order_no,
        'return_ref', v_ref,
        'invoice_id', v_order.global_invoice_id
      )
    );
  end if;

  update public.shop_orders
  set
    status = 'returned'::public.shop_order_status,
    return_sub_state = 'return_finalized',
    returned_at = coalesce(returned_at, now()),
    return_charge_amount = p_actual_return_charge,
    deduct_return_charge_from_middle_man = p_deduct_from_middle_man,
    return_override_reason = coalesce(p_override_reason, return_override_reason),
    return_ref = v_ref,
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'status', 'returned',
    'return_sub_state', 'return_finalized',
    'return_ref', v_ref
  );
end;
$$;


CREATE OR REPLACE FUNCTION "public"."fulfill_shop_order_to_invoice"("p_order_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_invoice_type public.global_invoice_type;
  v_retail_billing_mode public.retail_billing_mode;
  v_invoice_no text;
  v_item record;
  v_items jsonb := '[]'::jsonb;
  v_payload jsonb;
  v_result jsonb;
  v_invoice_id bigint;
begin
  select * into v_order from public.shop_orders where id = p_order_id;

  if v_order.id is null then
    raise exception 'order not found';
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.status = 'fulfilled' and v_order.global_invoice_id is not null then
    return;
  end if;

  if v_order.status <> 'confirmed' then
    raise exception 'only confirmed orders can be fulfilled to an invoice';
  end if;

  if v_order.shop_type_snapshot = 'vendor_catalog' then
    raise exception 'vendor catalog orders cannot be fulfilled to an invoice directly';
  end if;

  if v_order.shop_type_snapshot = 'fixed_price' then
    raise exception 'stock-backed catalog orders must close on Delivery paper (take / condition / return), not fulfill_shop_order_to_invoice';
  end if;

  if v_order.shop_type_snapshot = 'dropship' then
    raise exception 'dropship orders must use ship_dropship_order_and_issue_merchant_bill';
  end if;

  if exists (
    select 1
    from public.bills si
    where si.shop_order_id = p_order_id
  ) then
    raise exception 'order already has a linked sales invoice';
  end if;

  if v_order.order_mode_snapshot = 'checkout_wholesale' then
    v_invoice_type := 'wholesale'::public.global_invoice_type;
    v_retail_billing_mode := null;
    if v_order.profile_id is null then
      raise exception 'billing profile is required for wholesale shop orders';
    end if;
  else
    v_invoice_type := 'retail'::public.global_invoice_type;
    if v_order.profile_id is not null then
      v_retail_billing_mode := 'account'::public.retail_billing_mode;
    else
      v_retail_billing_mode := 'direct'::public.retail_billing_mode;
    end if;
  end if;

  v_invoice_no := 'INV-SO-' || v_order.order_no;

  for v_item in
    select *
    from public.shop_order_items
    where order_id = p_order_id
      and coalesce(is_fulfillment_unavailable, false) = false
      and quantity > 0
  loop
    if v_item.global_stock_id is null then
      raise exception 'item % is missing global_stock_id association', v_item.name;
    end if;

    v_items := v_items || jsonb_build_array(
      jsonb_build_object(
        'global_stock_id', v_item.global_stock_id,
        'quantity', v_item.quantity::numeric,
        'sell_price_amount', coalesce(
          v_item.final_price_amount,
          v_item.unit_sell_price_amount,
          v_item.unit_list_price_amount
        ),
        'line_discount_amount', 0,
        'line_meta', case
          when v_item.customer_sell_price_amount is not null then
            jsonb_build_object('resell_price_amount', v_item.customer_sell_price_amount)
          else '{}'::jsonb
        end
      )
    );
  end loop;

  if jsonb_array_length(v_items) = 0 then
    raise exception 'order has no fulfillable line items';
  end if;

  v_payload := jsonb_build_object(
    'invoice', jsonb_build_object(
      'invoice_no', v_invoice_no,
      'invoice_type', v_invoice_type,
      'profile_id', v_order.profile_id,
      'recipient_name', v_order.recipient_name,
      'recipient_phone', v_order.recipient_phone,
      'recipient_address', v_order.shipping_address,
      'retail_billing_mode', v_retail_billing_mode,
      'discount_amount', coalesce(v_order.discount_amount, 0),
      'shipping_charge', coalesce(v_order.delivery_charge_amount, 0),
      'print_charge', coalesce(v_order.print_charge_amount, 0),
      'wrapping_charge', coalesce(v_order.packing_charge_amount, 0),
      'note', coalesce(v_order.delivery_instructions, 'Fulfillment of Shop Order: ' || v_order.order_no)
    ),
    'items', v_items,
    'issue', true
  );

  v_result := public.create_sales_invoice_from_payload(v_order.tenant_id, v_payload);

  if coalesce(v_result->>'success', 'false') <> 'true' then
    raise exception '%', coalesce(v_result->>'error', 'failed to fulfill shop order to invoice');
  end if;

  v_invoice_id := (v_result->>'invoice_id')::bigint;

  update public.bills
  set
    shop_order_id = p_order_id,
    collection_source = 'profile'::public.collection_source_type,
    updated_at = now()
  where id = v_invoice_id;

  update public.shop_orders
  set
    status = 'fulfilled',
    global_invoice_id = v_invoice_id,
    fulfilled_at = now(),
    updated_at = now()
  where id = p_order_id;
end;
$$;


CREATE OR REPLACE FUNCTION "public"."get_customer_account_summary_for_staff"("p_tenant_id" bigint, "p_customer_group_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_books_id bigint;
  v_group_tenant_id bigint;
  v_profile_id bigint;
  v_bp_ids bigint[];
  v_still_due numeric(12, 2) := 0;
  v_total_billed numeric(12, 2) := 0;
  v_settlement numeric(12, 2) := 0;
  v_collected_cash numeric(12, 2) := 0;
  v_wallet_applied numeric(12, 2) := 0;
  v_store_credit numeric(15, 4) := 0;
  v_unallocated numeric(12, 2) := 0;
  v_open_invoices jsonb := '[]'::jsonb;
  v_recent_payments jsonb := '[]'::jsonb;
  v_recent_ledger jsonb := '[]'::jsonb;
  v_shop_access jsonb := '[]'::jsonb;
begin
  if p_tenant_id is null or p_customer_group_id is null then
    return jsonb_build_object('success', false, 'error', 'tenant and customer group are required');
  end if;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  if not (
    public.is_tenant_staff(p_tenant_id)
    or public.membership_has_module_action(v_books_id, 'customer', 'view')
  ) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  select cg.tenant_id
  into v_group_tenant_id
  from public.customer_groups cg
  where cg.id = p_customer_group_id;

  if v_group_tenant_id is null then
    return jsonb_build_object('success', false, 'error', 'customer group not found');
  end if;

  select
    coalesce(array_agg(bp.id order by
      case when bp.tenant_id = v_group_tenant_id then 0 else 1 end,
      bp.id
    ), '{}'::bigint[]),
    (array_agg(bp.id order by
      case when bp.tenant_id = v_group_tenant_id then 0 else 1 end,
      bp.id
    ))[1]
  into v_bp_ids, v_profile_id
  from public.profiles bp
  where bp.customer_group_id = p_customer_group_id
    and (
      bp.tenant_id = v_books_id
      or bp.tenant_id in (
        select t.id from public.tenants t where t.parent_id = v_books_id
      )
    );

  if v_profile_id is null then
    return jsonb_build_object(
      'success', true,
      'books_tenant_id', v_books_id,
      'profile_id', null,
      'still_due', 0,
      'total_billed', 0,
      'collected_cash', 0,
      'wallet_applied', 0,
      'settlement', 0,
      'store_credit_balance', 0,
      'unallocated_payments', 0,
      'open_invoices', '[]'::jsonb,
      'recent_payments', '[]'::jsonb,
      'recent_ledger', '[]'::jsonb,
      'shop_access', coalesce((
        select jsonb_agg(to_jsonb(r))
        from (
          select
            s.id as shop_id,
            s.name as shop_name,
            s.shop_type::text as shop_type,
            st.id as shop_tenant_id,
            st.name as shop_tenant_name,
            scga.status,
            scga.credit_limit_amount
          from public.shop_customer_group_access scga
          join public.shops s on s.id = scga.shop_id
          join public.tenants st on st.id = s.tenant_id
          where scga.customer_group_id = p_customer_group_id
          order by st.name, s.name
          limit 20
        ) r
      ), '[]'::jsonb)
    );
  end if;

  select
    coalesce(sum(si.due_amount), 0.00),
    coalesce(sum(si.total_amount), 0.00),
    coalesce(sum(si.settlement_discount_amount), 0.00)
  into v_still_due, v_total_billed, v_settlement
  from public.bills si
  where si.profile_id = any(v_bp_ids)
    and si.invoice_status = 'issued'::public.global_invoice_status;

  select
    coalesce(sum(ip.amount) filter (where coalesce(gp.method, '') <> 'wallet_credit'), 0.00),
    coalesce(sum(ip.amount) filter (where gp.method = 'wallet_credit'), 0.00)
  into v_collected_cash, v_wallet_applied
  from public.pay_allocations ip
  join public.pays gp on gp.id = ip.payment_id
  join public.bills si on si.id = ip.global_invoice_id
  where si.profile_id = any(v_bp_ids)
    and si.invoice_status = 'issued'::public.global_invoice_status;

  select coalesce(wa.available_balance, 0.0000)
  into v_store_credit
  from public.cashbook_accounts wa
  where wa.parent_tenant_id = v_books_id
    and wa.entity_type = 'customer'
    and wa.entity_id = v_profile_id
    and wa.currency_code = 'BDT';

  select coalesce(sum(gp.unallocated_amount), 0.00)
  into v_unallocated
  from public.pays gp
  where gp.profile_id = any(v_bp_ids);

  select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
  into v_open_invoices
  from (
    select
      si.id,
      si.invoice_no,
      si.invoice_type::text as invoice_type,
      si.due_amount,
      si.paid_amount,
      si.total_amount,
      si.payment_status,
      si.invoice_date,
      si.due_date,
      si.issued_by_tenant_id,
      it.name as issued_by_tenant_name
    from public.bills si
    left join public.tenants it on it.id = si.issued_by_tenant_id
    where si.profile_id = any(v_bp_ids)
      and si.invoice_status = 'issued'::public.global_invoice_status
      and si.due_amount > 0
    order by si.due_amount desc, si.invoice_date desc, si.id desc
    limit 50
  ) r;

  select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
  into v_recent_payments
  from (
    select
      gp.id as payment_id,
      gp.payment_date,
      gp.method,
      gp.amount,
      gp.unallocated_amount,
      gp.note,
      ip.global_invoice_id as invoice_id,
      ip.amount as allocated_amount
    from public.pays gp
    left join public.pay_allocations ip on ip.payment_id = gp.id
    where gp.profile_id = any(v_bp_ids)
    order by gp.payment_date desc, gp.id desc
    limit 30
  ) r;

  select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
  into v_recent_ledger
  from (
    select
      l.id,
      l.type,
      l.amount,
      l.balance_after,
      l.operating_tenant_id,
      l.source_type,
      l.source_id,
      l.created_at,
      l.metadata->>'transaction_type' as transaction_type,
      coalesce(
        l.metadata->>'label',
        l.metadata->>'transaction_type',
        'Adjustment'
      ) as label
    from public.cashbook_entries l
    where l.parent_tenant_id = v_books_id
      and l.entity_type = 'customer'
      and l.entity_id = any(v_bp_ids)
    order by l.created_at desc, l.id desc
    limit 30
  ) r;

  select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
  into v_shop_access
  from (
    select
      s.id as shop_id,
      s.name as shop_name,
      s.shop_type::text as shop_type,
      st.id as shop_tenant_id,
      st.name as shop_tenant_name,
      scga.status,
      scga.credit_limit_amount
    from public.shop_customer_group_access scga
    join public.shops s on s.id = scga.shop_id
    join public.tenants st on st.id = s.tenant_id
    where scga.customer_group_id = p_customer_group_id
    order by st.name, s.name
    limit 20
  ) r;

  return jsonb_build_object(
    'success', true,
    'books_tenant_id', v_books_id,
    'profile_id', v_profile_id,
    'still_due', v_still_due,
    'total_billed', v_total_billed,
    'collected_cash', v_collected_cash,
    'wallet_applied', v_wallet_applied,
    'settlement', v_settlement,
    'store_credit_balance', v_store_credit,
    'unallocated_payments', v_unallocated,
    'open_invoices', v_open_invoices,
    'recent_payments', v_recent_payments,
    'recent_ledger', v_recent_ledger,
    'shop_access', v_shop_access
  );
end;
$$;


CREATE OR REPLACE FUNCTION "public"."get_customer_dues_report"("p_tenant_id" bigint, "p_issued_by_tenant_id" bigint DEFAULT NULL::bigint, "p_search" "text" DEFAULT NULL::"text", "p_aging_bucket" "text" DEFAULT NULL::"text", "p_min_due" numeric DEFAULT 0, "p_over_limit_only" boolean DEFAULT false, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 50, "p_skip_count" boolean DEFAULT true) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_today date;
  v_totals jsonb;
  v_rows jsonb;
  v_total_count bigint;
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(least(coalesce(p_page_size, 50), 200), 1);
  v_offset integer;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'Tenant ID is required';
  END IF;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_today := (timezone('Asia/Dhaka', now()))::date;
  v_offset := (v_page - 1) * v_page_size;

  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  WITH invoice_returned AS (
    SELECT
      sii.invoice_id,
      coalesce(sum(sii.return_quantity * sii.sell_price_amount), 0)::numeric(12,2) AS returned
    FROM public.bill_lines sii
    GROUP BY sii.invoice_id
  ),
  invoice_payments_agg AS (
    SELECT
      ip.global_invoice_id AS invoice_id,
      coalesce(sum(CASE WHEN coalesce(gp.method, '') <> 'wallet_credit' THEN ip.amount ELSE 0 END), 0)::numeric(12,2) AS collected_cash,
      coalesce(sum(CASE WHEN gp.method = 'wallet_credit' THEN ip.amount ELSE 0 END), 0)::numeric(12,2) AS wallet_applied
    FROM public.pay_allocations ip
    JOIN public.pays gp ON gp.id = ip.payment_id
    WHERE ip.global_invoice_id IS NOT NULL
      AND gp.voided_at IS NULL
    GROUP BY ip.global_invoice_id
  ),
  per_invoice AS (
    SELECT
      si.profile_id AS profile_id,
      si.due_amount,
      (si.total_amount + coalesce(ir.returned, 0))::numeric(12,2) AS billed,
      coalesce(ir.returned, 0)::numeric(12,2) AS returned,
      coalesce(ipa.collected_cash, 0)::numeric(12,2) AS collected_cash,
      coalesce(ipa.wallet_applied, 0)::numeric(12,2) AS wallet_applied,
      coalesce(si.written_off_amount, 0)::numeric(12,2) AS settlement,
      coalesce(si.due_date, si.invoice_date) AS aging_date,
      CASE
        WHEN si.due_amount <= 0 THEN NULL
        WHEN (v_today - coalesce(si.due_date, si.invoice_date)) <= 0 THEN 'current'
        WHEN (v_today - coalesce(si.due_date, si.invoice_date)) BETWEEN 1 AND 30 THEN '1_30'
        WHEN (v_today - coalesce(si.due_date, si.invoice_date)) BETWEEN 31 AND 60 THEN '31_60'
        WHEN (v_today - coalesce(si.due_date, si.invoice_date)) BETWEEN 61 AND 90 THEN '61_90'
        ELSE '90_plus'
      END AS aging_bucket
    FROM public.bills si
    LEFT JOIN invoice_returned ir ON ir.invoice_id = si.id
    LEFT JOIN invoice_payments_agg ipa ON ipa.invoice_id = si.id
    WHERE si.parent_tenant_id = v_books_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND si.profile_id IS NOT NULL
      AND (p_issued_by_tenant_id IS NULL OR si.issued_by_tenant_id = p_issued_by_tenant_id)
  ),
  customer_base AS (
    SELECT
      pi.profile_id,
      round(sum(pi.billed), 2) AS billed,
      round(sum(pi.returned), 2) AS returned,
      round(sum(pi.collected_cash), 2) AS collected_cash,
      round(sum(pi.wallet_applied), 2) AS wallet_applied,
      round(sum(pi.settlement), 2) AS settlement,
      round(sum(pi.due_amount), 2) AS still_due,
      min(pi.aging_date) FILTER (WHERE pi.due_amount > 0) AS oldest_due_date,
      count(*) FILTER (WHERE pi.due_amount > 0)::bigint AS open_invoice_count,
      round(coalesce(sum(pi.due_amount) FILTER (WHERE pi.aging_bucket = 'current'), 0), 2) AS aging_current,
      round(coalesce(sum(pi.due_amount) FILTER (WHERE pi.aging_bucket = '1_30'), 0), 2) AS aging_d1_30,
      round(coalesce(sum(pi.due_amount) FILTER (WHERE pi.aging_bucket = '31_60'), 0), 2) AS aging_d31_60,
      round(coalesce(sum(pi.due_amount) FILTER (WHERE pi.aging_bucket = '61_90'), 0), 2) AS aging_d61_90,
      round(coalesce(sum(pi.due_amount) FILTER (WHERE pi.aging_bucket = '90_plus'), 0), 2) AS aging_d90_plus
    FROM per_invoice pi
    GROUP BY pi.profile_id
    HAVING sum(pi.due_amount) > 0
  ),
  customer_rows AS (
    SELECT
      cb.*,
      bp.name,
      bp.phone,
      cl.credit_limit
    FROM customer_base cb
    JOIN public.profiles bp ON bp.id = cb.profile_id
    LEFT JOIN LATERAL (
      SELECT max(scga.credit_limit_amount)::numeric(12,2) AS credit_limit
      FROM public.shop_customer_group_access scga
      JOIN public.shops sh ON sh.id = scga.shop_id
      WHERE scga.customer_group_id = bp.customer_group_id
        AND public.resolve_parent_tenant_id(sh.tenant_id) = v_books_id
    ) cl ON true
    WHERE cb.still_due >= coalesce(p_min_due, 0)
      AND (
        p_search IS NULL
        OR btrim(p_search) = ''
        OR bp.name ILIKE ('%' || btrim(p_search) || '%')
        OR bp.phone ILIKE ('%' || btrim(p_search) || '%')
      )
      AND (
        p_aging_bucket IS NULL
        OR btrim(p_aging_bucket) = ''
        OR (p_aging_bucket = 'current' AND cb.aging_current > 0)
        OR (p_aging_bucket = '1_30' AND cb.aging_d1_30 > 0)
        OR (p_aging_bucket = '31_60' AND cb.aging_d31_60 > 0)
        OR (p_aging_bucket = '61_90' AND cb.aging_d61_90 > 0)
        OR (p_aging_bucket = '90_plus' AND cb.aging_d90_plus > 0)
      )
      AND (
        NOT coalesce(p_over_limit_only, false)
        OR (cl.credit_limit IS NOT NULL AND cb.still_due > cl.credit_limit)
      )
  ),
  totals_calc AS (
    SELECT
      round(coalesce(sum(billed), 0), 2) AS billed,
      round(coalesce(sum(returned), 0), 2) AS returned,
      round(coalesce(sum(collected_cash), 0), 2) AS collected_cash,
      round(coalesce(sum(wallet_applied), 0), 2) AS wallet_applied,
      round(coalesce(sum(settlement), 0), 2) AS settlement,
      round(coalesce(sum(still_due), 0), 2) AS still_due,
      count(*)::bigint AS customer_count
    FROM customer_rows
  ),
  paged AS (
    SELECT * FROM customer_rows ORDER BY still_due DESC, name ASC OFFSET v_offset LIMIT v_page_size
  )
  SELECT (SELECT count(*) FROM customer_rows),
    (SELECT jsonb_build_object(
      'billed', billed, 'returned', returned, 'collected_cash', collected_cash,
      'wallet_applied', wallet_applied, 'settlement', settlement, 'still_due', still_due,
      'customer_count', customer_count
    ) FROM totals_calc),
    coalesce((SELECT jsonb_agg(jsonb_build_object(
      'profile_id', profile_id, 'name', name, 'phone', phone, 'credit_limit', credit_limit,
      'billed', billed, 'returned', returned, 'collected_cash', collected_cash, 'wallet_applied', wallet_applied,
      'settlement', settlement, 'still_due', still_due, 'oldest_due_date', oldest_due_date,
      'open_invoice_count', open_invoice_count,
      'aging', jsonb_build_object(
        'current', aging_current, 'd1_30', aging_d1_30, 'd31_60', aging_d31_60,
        'd61_90', aging_d61_90, 'd90_plus', aging_d90_plus
      )
    ) ORDER BY still_due DESC, name ASC) FROM paged), '[]'::jsonb)
  INTO v_total_count, v_totals, v_rows;

  RETURN jsonb_build_object(
    'totals', coalesce(v_totals, '{}'::jsonb),
    'rows', coalesce(v_rows, '[]'::jsonb),
    'page', v_page,
    'page_size', v_page_size,
    'total_count', CASE WHEN coalesce(p_skip_count, true) THEN NULL ELSE v_total_count END
  );
END;
$$;


CREATE OR REPLACE FUNCTION "public"."get_dropship_finance_hub_data"("p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_summary jsonb;
  v_orders jsonb;
  v_merchants jsonb;
  v_parent_tenant_id bigint;
  v_is_parent_scope boolean;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_is_parent_scope := (p_tenant_id = v_parent_tenant_id);

  v_summary := public.get_wallet_dashboard_summary(p_tenant_id);

  with finance_orders as (
    select
      o.id,
      o.order_no,
      o.recipient_name,
      o.status,
      o.cod_collect_amount,
      o.delivery_charge_amount,
      o.cod_charge_amount,
      o.driver_notes,
      o.courier_name,
      o.courier_remittance_ref,
      o.courier_bank_trx_id,
      o.profile_id,
      o.created_at,
      o.collection_source,
      o.payout_settlement_status,
      o.is_prepaid_snapshot,
      o.global_invoice_id,
      s.name as shop_name,
      pr.name as billing_profile_name,
      inv.collection_source as invoice_collection_source,
      inv.total_amount as invoice_total_amount,
      inv.paid_amount as invoice_paid_amount
    from public.shop_orders o
    left join public.shops s on s.id = o.shop_id
    left join public.profiles pr on pr.id = o.profile_id
    left join public.bills inv on inv.id = o.global_invoice_id
    where (
        (v_is_parent_scope and (o.parent_tenant_id = p_tenant_id or o.tenant_id = p_tenant_id))
        or (not v_is_parent_scope and o.tenant_id = p_tenant_id)
      )
      and o.shop_type_snapshot = 'dropship'
      and o.status in ('delivered', 'payment_received')
  ),
  ledger_flags as (
    select
      l.source_id,
      max(case when coalesce(l.metadata->>'purpose', '') in ('delivered_costing', 'courier_cod_receivable') then 1 else 0 end) as has_delivered_costing,
      max(case when coalesce(l.metadata->>'purpose', '') in ('courier_remittance', 'tenant_remittance_received') then 1 else 0 end) as has_remittance
    from public.cashbook_entries l
    where l.parent_tenant_id = v_parent_tenant_id
      and l.source_type = 'shop_order'
      and l.source_id in (select fo.id::text from finance_orders fo)
    group by l.source_id
  ),
  order_rows as (
    select
      fo.id,
      fo.order_no as "orderNo",
      fo.recipient_name as "customerName",
      fo.shop_name as "shopName",
      fo.courier_name as "courierName",
      fo.status::text as status,
      case
        when fo.global_invoice_id is not null then coalesce(fo.invoice_total_amount, 0)
        else coalesce(fo.cod_collect_amount, 0)
      end as "totalAmount",
      coalesce(fo.cod_collect_amount, 0) as "codCollectAmount",
      coalesce(fo.delivery_charge_amount, 0) as "deliveryChargeAmount",
      coalesce(fo.cod_charge_amount, 0) as "codChargeAmount",
      fo.driver_notes as "courierNotes",
      fo.courier_remittance_ref as "courierRemittanceRef",
      fo.courier_bank_trx_id as "courierBankTrxId",
      fo.profile_id as "billingProfileId",
      fo.billing_profile_name as "billingProfileName",
      fo.created_at as "createdAt",
      case
        when fo.status::text = 'delivered'
          and coalesce(lf.has_remittance, 0) = 0
          and fo.courier_remittance_ref is null
          and coalesce(fo.cod_collect_amount, 0) > 0
          and coalesce(
            fo.collection_source,
            fo.invoice_collection_source,
            case
              when fo.is_prepaid_snapshot then 'profile'::public.collection_source_type
              else 'recipient'::public.collection_source_type
            end
          ) <> 'profile'::public.collection_source_type
          then 'courier_remittance'
        when coalesce(lf.has_delivered_costing, 0) = 0 and fo.status::text = 'delivered' then 'delivered_costing'
        when fo.status::text = 'delivered'
          or (coalesce(lf.has_remittance, 0) = 0 and fo.status::text <> 'payment_received')
          then 'courier_remittance'
        when fo.status::text = 'payment_received'
          and coalesce(fo.payout_settlement_status, 'unpaid') in ('unpaid', 'partial')
          then 'middleman_payout'
        else 'completed'
      end as "nextStep",
      coalesce(
        fo.collection_source,
        fo.invoice_collection_source,
        case
          when fo.is_prepaid_snapshot then 'profile'::public.collection_source_type
          else null::public.collection_source_type
        end
      )::text as "collectionSource",
      coalesce(fo.payout_settlement_status, 'unpaid') as "payoutSettlementStatus",
      case
        when fo.global_invoice_id is not null then greatest(coalesce(fo.invoice_total_amount, 0) - coalesce(fo.invoice_paid_amount, 0), 0)
        else null
      end as "invoiceOutstanding"
    from finance_orders fo
    left join ledger_flags lf on lf.source_id = fo.id::text
    order by fo.created_at desc
  )
  select coalesce(jsonb_agg(to_jsonb(order_rows)), '[]'::jsonb)
  into v_orders
  from order_rows;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', pr.id,
        'name', pr.name,
        'payableBalance', coalesce(wa.available_balance, 0)
      )
      order by pr.name
    ),
    '[]'::jsonb
  )
  into v_merchants
  from public.profiles pr
  left join public.cashbook_accounts wa
    on wa.parent_tenant_id = v_parent_tenant_id
   and wa.entity_type = 'customer'
   and wa.entity_id = pr.id
   and wa.currency_code = 'BDT'
  where pr.operating_tenant_id = p_tenant_id
     or pr.operating_tenant_id = v_parent_tenant_id;

  return jsonb_build_object(
    'kpis', jsonb_build_object(
      'courierOwedTotal', coalesce((v_summary->>'courier_cod_holding_total')::numeric, 0),
      'tenantCashTotal', coalesce((v_summary->>'tenant_cash_total')::numeric, 0),
      'middlemanPayableTotal', coalesce((v_summary->>'merchant_available_total')::numeric, 0)
    ),
    'orders', coalesce(v_orders, '[]'::jsonb),
    'merchants', coalesce(v_merchants, '[]'::jsonb)
  );
end;
$$;


CREATE OR REPLACE FUNCTION "public"."get_dropship_wallet_reconciliation_report"("p_tenant_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_target_tenant_id bigint;
  v_missing_invoice_billed bigint := 0;
  v_missing_courier_remittance bigint := 0;
  v_missing_return_compensation bigint := 0;
  v_mixed_customer_profit bigint := 0;
  v_uncanonicalized_source_ids bigint := 0;
  v_conflicting_active_offers bigint := 0;
  v_missing_or_duplicate_gifts bigint := 0;
begin
  if p_tenant_id is not null then
    v_target_tenant_id := p_tenant_id;
  else
    v_target_tenant_id := public.current_tenant_id();
  end if;

  if not (
    public.is_superadmin()
    or exists (
      select 1 from public.memberships m
      where (v_target_tenant_id is null or m.tenant_id = v_target_tenant_id)
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: Admin or Staff role required for reconciliation report';
  end if;

  -- 1. Posted dropship invoices missing invoice_billed (P0A contract)
  select count(*) into v_missing_invoice_billed
  from public.bills i
  where i.invoice_type = 'dropship'
    and i.invoice_status = 'posted'
    and i.profile_id is not null
    and i.total_amount > 0
    and (v_target_tenant_id is null or i.tenant_id = v_target_tenant_id)
    and not exists (
      select 1 from public.cashbook_entries u
      where u.tenant_id = i.tenant_id
        and u.entity_type = 'customer'
        and u.entity_id = i.profile_id
        and u.source_type = 'shop_order'
        and u.metadata->>'transaction_type' = 'invoice_billed'
        and (u.metadata->>'invoice_id' = i.id::text or u.source_id = i.invoice_no)
    );

  -- 2. Remitted shop orders missing courier remittance UWL entry
  select count(*) into v_missing_courier_remittance
  from public.shop_orders o
  where o.shop_type_snapshot = 'dropship'
    and o.status = 'payment_received'
    and o.courier_remittance_ref is not null
    and (v_target_tenant_id is null or o.tenant_id = v_target_tenant_id)
    and not exists (
      select 1 from public.cashbook_entries u
      where u.tenant_id = o.tenant_id
        and u.entity_type = 'courier'
        and u.source_type = 'shop_order'
        and u.source_id = o.id::text
        and u.metadata->>'purpose' = 'courier_remittance'
    );

  -- 3. Finalized returns missing return compensating UWL entry
  select count(*) into v_missing_return_compensation
  from public.shop_orders o
  where o.shop_type_snapshot = 'dropship'
    and o.status = 'returned'
    and (v_target_tenant_id is null or o.tenant_id = v_target_tenant_id)
    and not exists (
      select 1 from public.cashbook_entries u
      where u.tenant_id = o.tenant_id
        and u.source_type = 'shop_order'
        and u.source_id = o.id::text
        and (
          u.metadata->>'purpose' = 'dropship_return_finalize'
          or u.metadata->>'transaction_type' in (
            'return_reversal',
            'return_profit_clawback',
            'return_revenue_reversal'
          )
        )
    );

  -- 4. Mixed customer vs middleman profit rows
  select count(*) into v_mixed_customer_profit
  from public.cashbook_entries u
  where u.entity_type = 'customer'
    and u.source_type = 'shop_order'
    and u.metadata->>'transaction_type' = 'dropship_profit'
    and (v_target_tenant_id is null or u.tenant_id = v_target_tenant_id);

  -- 5. Uncanonicalized source_ids (order_no instead of order_id string), exclude invoice_billed
  select count(*) into v_uncanonicalized_source_ids
  from public.cashbook_entries u
  join public.shop_orders o on o.tenant_id = u.tenant_id and o.order_no = u.source_id
  where u.source_type = 'shop_order'
    and coalesce(u.metadata->>'transaction_type', '') <> 'invoice_billed'
    and (v_target_tenant_id is null or u.tenant_id = v_target_tenant_id);

  -- 6. Conflicting active offer prices (P2 shop_product_offers)
  select count(*) into v_conflicting_active_offers
  from (
    select shop_id, product_id, condition_bucket
    from public.shop_product_offers
    where is_active = true
    group by shop_id, product_id, condition_bucket
    having count(*) > 1
  ) t;

  -- 7. Legacy gift rules removed - drift is 0
  v_missing_or_duplicate_gifts := 0;

  return jsonb_build_object(
    'reconciliation_time', now(),
    'tenant_id', v_target_tenant_id,
    'healthy', (
      v_missing_invoice_billed = 0 and
      v_missing_courier_remittance = 0 and
      v_missing_return_compensation = 0 and
      v_mixed_customer_profit = 0 and
      v_uncanonicalized_source_ids = 0 and
      v_conflicting_active_offers = 0 and
      v_missing_or_duplicate_gifts = 0
    ),
    'drift_counts', jsonb_build_object(
      'missing_invoice_billed', v_missing_invoice_billed,
      'missing_courier_remittance', v_missing_courier_remittance,
      'missing_return_compensation', v_missing_return_compensation,
      'mixed_customer_profit', v_mixed_customer_profit,
      'uncanonicalized_source_ids', v_uncanonicalized_source_ids,
      'conflicting_active_offers', v_conflicting_active_offers,
      'missing_or_duplicate_gifts', v_missing_or_duplicate_gifts
    )
  );
end;
$$;


CREATE OR REPLACE FUNCTION "public"."get_procurement_demand_open_qty"("p_source_type" "public"."preorder_demand_source_type", "p_source_id" bigint) RETURNS TABLE("tenant_id" bigint, "open_qty" integer, "document_status" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if p_source_type = 'shop_order_item' then
    return query
    select
      o.tenant_id,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer,
      public.normalize_shop_order_procurement_status(o.status)
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    where oi.id = p_source_id
      and o.shop_type_snapshot = 'vendor_catalog';
  elsif p_source_type = 'pbc_costing_item' then
    return query
    select
      f.tenant_id,
      greatest(
        case when pci.assigned_shipment_id is not null then 0
          else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        end,
        0
      )::integer,
      public.normalize_pbc_procurement_status(f.status)
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    where pci.id = p_source_id
      and f.profile_id is not null;
  end if;
end;
$$;


CREATE OR REPLACE FUNCTION "public"."get_tenant_invoice_book_report"("p_tenant_id" bigint, "p_start_date" "date" DEFAULT NULL::"date", "p_end_date" "date" DEFAULT NULL::"date", "p_search" "text" DEFAULT NULL::"text", "p_invoice_type" "text" DEFAULT NULL::"text", "p_payment_status" "text" DEFAULT NULL::"text", "p_issued_by_tenant_id" bigint DEFAULT NULL::bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 50, "p_skip_count" boolean DEFAULT true) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_totals jsonb;
  v_rows jsonb;
  v_total_count bigint;
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(least(coalesce(p_page_size, 50), 200), 1);
  v_offset integer := (greatest(coalesce(p_page, 1), 1) - 1) * greatest(least(coalesce(p_page_size, 50), 200), 1);
BEGIN
  IF p_tenant_id IS NULL THEN RAISE EXCEPTION 'Tenant ID is required'; END IF;
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
  ) THEN RAISE EXCEPTION 'Not authorized'; END IF;

  WITH invoice_returned AS (
    SELECT sii.invoice_id, coalesce(sum(sii.return_quantity * sii.sell_price_amount), 0)::numeric(12,2) AS returned
    FROM public.bill_lines sii GROUP BY sii.invoice_id
  ),
  invoice_payments_agg AS (
    SELECT ip.global_invoice_id AS invoice_id,
      coalesce(sum(CASE WHEN coalesce(gp.method, '') <> 'wallet_credit' THEN ip.amount ELSE 0 END), 0)::numeric(12,2) AS collected_cash,
      coalesce(sum(CASE WHEN gp.method = 'wallet_credit' THEN ip.amount ELSE 0 END), 0)::numeric(12,2) AS wallet_applied
    FROM public.pay_allocations ip
    JOIN public.pays gp ON gp.id = ip.payment_id
    WHERE ip.global_invoice_id IS NOT NULL
      AND gp.voided_at IS NULL
    GROUP BY ip.global_invoice_id
  ),
  base AS (
    SELECT
      si.id, si.invoice_no, si.invoice_date, si.invoice_type::text AS invoice_type,
      si.payment_status, si.profile_id AS profile_id, si.due_amount,
      coalesce(nullif(trim(bp.name), ''), nullif(trim(si.recipient_name), ''), 'Unknown') AS customer_name,
      coalesce(child.name, parent.name) AS issued_by_name,
      round((si.total_amount + coalesce(ir.returned, 0)), 2) AS billed,
      round(coalesce(ir.returned, 0), 2) AS returned,
      round(coalesce(ipa.collected_cash, 0), 2) AS collected_cash,
      round(coalesce(ipa.wallet_applied, 0), 2) AS wallet_applied,
      round(coalesce(si.written_off_amount, 0), 2) AS settlement,
      round(coalesce(si.due_amount, 0), 2) AS still_due
    FROM public.bills si
    LEFT JOIN public.profiles bp ON bp.id = si.profile_id
    LEFT JOIN public.tenants child ON child.id = si.issued_by_tenant_id
    LEFT JOIN public.tenants parent ON parent.id = si.parent_tenant_id
    LEFT JOIN invoice_returned ir ON ir.invoice_id = si.id
    LEFT JOIN invoice_payments_agg ipa ON ipa.invoice_id = si.id
    WHERE si.parent_tenant_id = v_books_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND (p_start_date IS NULL OR si.invoice_date >= p_start_date)
      AND (p_end_date IS NULL OR si.invoice_date <= p_end_date)
      AND (p_invoice_type IS NULL OR btrim(p_invoice_type) = '' OR si.invoice_type::text = p_invoice_type)
      AND (p_payment_status IS NULL OR btrim(p_payment_status) = '' OR si.payment_status = p_payment_status)
      AND (p_issued_by_tenant_id IS NULL OR si.issued_by_tenant_id = p_issued_by_tenant_id)
      AND (
        p_search IS NULL OR btrim(p_search) = ''
        OR si.invoice_no ILIKE ('%' || btrim(p_search) || '%')
        OR bp.name ILIKE ('%' || btrim(p_search) || '%')
        OR si.recipient_name ILIKE ('%' || btrim(p_search) || '%')
      )
  ),
  totals_calc AS (
    SELECT round(coalesce(sum(billed), 0), 2) AS billed, round(coalesce(sum(returned), 0), 2) AS returned,
      round(coalesce(sum(collected_cash), 0), 2) AS collected_cash, round(coalesce(sum(wallet_applied), 0), 2) AS wallet_applied,
      round(coalesce(sum(settlement), 0), 2) AS settlement, round(coalesce(sum(still_due), 0), 2) AS still_due,
      count(*)::bigint AS invoice_count FROM base
  ),
  paged AS (
    SELECT * FROM base ORDER BY invoice_date DESC, id DESC OFFSET v_offset LIMIT v_page_size
  )
  SELECT (SELECT count(*) FROM base),
    (SELECT jsonb_build_object('billed', billed, 'returned', returned, 'collected_cash', collected_cash,
      'wallet_applied', wallet_applied, 'settlement', settlement, 'still_due', still_due, 'invoice_count', invoice_count) FROM totals_calc),
    coalesce((SELECT jsonb_agg(jsonb_build_object(
      'id', id, 'invoice_no', invoice_no, 'invoice_date', invoice_date, 'invoice_type', invoice_type,
      'payment_status', payment_status, 'customer_name', customer_name, 'profile_id', profile_id,
      'issued_by_name', issued_by_name, 'billed', billed, 'returned', returned, 'collected_cash', collected_cash,
      'wallet_applied', wallet_applied, 'settlement', settlement, 'still_due', still_due
    ) ORDER BY invoice_date DESC, id DESC) FROM paged), '[]'::jsonb)
  INTO v_total_count, v_totals, v_rows;

  RETURN jsonb_build_object('totals', coalesce(v_totals, '{}'::jsonb), 'rows', coalesce(v_rows, '[]'::jsonb),
    'page', v_page, 'page_size', v_page_size,
    'total_count', CASE WHEN coalesce(p_skip_count, true) THEN NULL ELSE v_total_count END);
END;
$$;


CREATE OR REPLACE FUNCTION "public"."get_tenant_wallet_liability_report"("p_tenant_id" bigint, "p_start_date" "date" DEFAULT NULL::"date", "p_end_date" "date" DEFAULT NULL::"date", "p_search" "text" DEFAULT NULL::"text", "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 50, "p_skip_count" boolean DEFAULT true) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_totals jsonb;
  v_rows jsonb;
  v_total_count bigint;
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(least(coalesce(p_page_size, 50), 200), 1);
  v_offset integer := (greatest(coalesce(p_page, 1), 1) - 1) * greatest(least(coalesce(p_page_size, 50), 200), 1);
  v_start_ts timestamptz := CASE WHEN p_start_date IS NULL THEN NULL ELSE p_start_date::timestamptz END;
  v_end_ts timestamptz := CASE WHEN p_end_date IS NULL THEN NULL ELSE (p_end_date + interval '1 day' - interval '1 microsecond') END;
  v_customer_store_credit numeric(18,4) := 0;
  v_merchant_payable numeric(18,4) := 0;
  v_courier numeric(18,4) := 0;
BEGIN
  IF p_tenant_id IS NULL THEN RAISE EXCEPTION 'Tenant ID is required'; END IF;
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
  ) THEN RAISE EXCEPTION 'Not authorized'; END IF;

  SELECT
    round(coalesce(sum(CASE WHEN entity_type = 'customer' THEN available_balance ELSE 0 END), 0), 2),
    round(coalesce(sum(CASE WHEN entity_type IN ('customer', 'middleman') THEN pending_balance + available_balance ELSE 0 END), 0), 2),
    round(coalesce(sum(CASE WHEN entity_type = 'courier' THEN pending_balance + available_balance ELSE 0 END), 0), 2)
  INTO v_customer_store_credit, v_merchant_payable, v_courier
  FROM public.cashbook_accounts
  WHERE parent_tenant_id = v_books_id;

  WITH ledger_agg AS (
    SELECT
      l.entity_id AS profile_id,
      round(
        coalesce(sum(CASE
          WHEN l.type = 'credit'
            AND coalesce(l.metadata->>'reversed_by', '') = ''
            AND coalesce(l.metadata->>'purpose', '') IN ('customer_ar_reduction', 'store_credit')
          THEN l.amount
          ELSE 0
        END), 0)
        - coalesce(sum(CASE
          WHEN l.type = 'debit'
            AND coalesce(l.metadata->>'purpose', '') IN ('reverse_customer_ar_reduction', 'void_store_credit')
          THEN l.amount
          ELSE 0
        END), 0),
        4
      ) AS credit_issued,
      round(coalesce(sum(CASE
        WHEN l.type = 'debit' AND coalesce(l.metadata->>'purpose', '') = 'apply_store_credit' THEN l.amount
        ELSE 0 END), 0), 4) AS credit_applied
    FROM public.cashbook_entries l
    WHERE l.parent_tenant_id = v_books_id
      AND l.entity_type = 'customer'
      AND (v_start_ts IS NULL OR l.created_at >= v_start_ts)
      AND (v_end_ts IS NULL OR l.created_at <= v_end_ts)
    GROUP BY l.entity_id
  ),
  base AS (
    SELECT
      wa.entity_id AS profile_id,
      bp.name,
      bp.phone,
      round(coalesce(la.credit_issued, 0), 2) AS credit_issued,
      round(coalesce(la.credit_applied, 0), 2) AS credit_applied,
      round(coalesce(wa.available_balance, 0), 2) AS outstanding
    FROM public.cashbook_accounts wa
    JOIN public.profiles bp ON bp.id = wa.entity_id
    LEFT JOIN ledger_agg la ON la.profile_id = wa.entity_id
    WHERE wa.parent_tenant_id = v_books_id
      AND wa.entity_type = 'customer'
      AND (
        coalesce(wa.available_balance, 0) > 0
        OR coalesce(la.credit_issued, 0) > 0
        OR coalesce(la.credit_applied, 0) > 0
      )
      AND (
        p_search IS NULL OR btrim(p_search) = ''
        OR bp.name ILIKE ('%' || btrim(p_search) || '%')
        OR bp.phone ILIKE ('%' || btrim(p_search) || '%')
      )
  ),
  totals_calc AS (
    SELECT round(coalesce(sum(credit_issued), 0), 2) AS credit_issued,
      round(coalesce(sum(credit_applied), 0), 2) AS credit_applied,
      round(coalesce(sum(outstanding), 0), 2) AS outstanding,
      count(*)::bigint AS customer_count
    FROM base
  ),
  paged AS (
    SELECT * FROM base ORDER BY outstanding DESC, name ASC OFFSET v_offset LIMIT v_page_size
  )
  SELECT (SELECT count(*) FROM base),
    (SELECT jsonb_build_object(
      'credit_issued', credit_issued, 'credit_applied', credit_applied,
      'outstanding', outstanding, 'customer_count', customer_count,
      'customer_store_credit', v_customer_store_credit,
      'merchant_payable', v_merchant_payable,
      'courier', v_courier
    ) FROM totals_calc),
    coalesce((SELECT jsonb_agg(jsonb_build_object(
      'profile_id', profile_id, 'name', name, 'phone', phone,
      'credit_issued', credit_issued, 'credit_applied', credit_applied, 'outstanding', outstanding
    ) ORDER BY outstanding DESC, name ASC) FROM paged), '[]'::jsonb)
  INTO v_total_count, v_totals, v_rows;

  RETURN jsonb_build_object('totals', coalesce(v_totals, '{}'::jsonb), 'rows', coalesce(v_rows, '[]'::jsonb),
    'page', v_page, 'page_size', v_page_size,
    'total_count', CASE WHEN coalesce(p_skip_count, true) THEN NULL ELSE v_total_count END);
END;
$$;


CREATE OR REPLACE FUNCTION "public"."list_customer_accounts"("p_tenant_id" bigint, "p_search" "text" DEFAULT NULL::"text") RETURNS TABLE("id" bigint, "customer_group_id" bigint, "profile_id" bigint, "group_name" "text", "admin_name" "text", "email" "text", "phone" "text", "address" "text", "accent_color" "text", "is_active" boolean, "member_count" bigint, "wallet_available_balance" numeric, "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_books_id bigint;
begin
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  return query
  select
    cg.id,
    cg.id as customer_group_id,
    bp.id as profile_id,
    cg.name as group_name,
    coalesce(bp.name, cg.name) as admin_name,
    bp.email,
    nullif(concat_ws(' ', bp.phone_country_code, bp.phone), '') as phone,
    bp.address,
    coalesce(cg.accent_color, '#B45F34') as accent_color,
    cg.is_active,
    coalesce(mem.cnt, 0::bigint) as member_count,
    coalesce(wa.available_balance, 0.00) as wallet_available_balance,
    cg.created_at
  from public.customer_groups cg
  left join public.profiles bp
    on bp.customer_group_id = cg.id
   and bp.parent_tenant_id = v_books_id
  left join (
    select cgm.customer_group_id as c_group_id, count(*) as cnt
    from public.customer_group_members cgm
    group by cgm.customer_group_id
  ) mem on mem.c_group_id = cg.id
  left join public.cashbook_accounts wa
    on wa.parent_tenant_id = v_books_id
   and wa.entity_type = 'customer'
   and wa.entity_id = bp.id
   and wa.currency_code = 'BDT'
  where cg.parent_tenant_id = v_books_id
    and cg.deleted_at is null
    and (
      p_search is null
      or trim(p_search) = ''
      or cg.name ilike '%' || trim(p_search) || '%'
      or bp.name ilike '%' || trim(p_search) || '%'
      or bp.email ilike '%' || trim(p_search) || '%'
      or bp.phone ilike '%' || trim(p_search) || '%'
      or bp.phone_country_code ilike '%' || trim(p_search) || '%'
      or bp.address ilike '%' || trim(p_search) || '%'
    )
  order by cg.id desc;
end;
$$;


CREATE OR REPLACE FUNCTION "public"."list_customer_accounts_paginated"("p_tenant_id" bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_search" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_books_id bigint;
  v_page integer;
  v_page_size integer;
  v_total_count bigint;
  v_total_pages integer;
  v_data jsonb;
  v_search text;
begin
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_page := greatest(coalesce(p_page, 1), 1);
  v_page_size := greatest(1, least(coalesce(p_page_size, 20), 200));
  v_search := nullif(trim(coalesce(p_search, '')), '');

  select count(*)
  into v_total_count
  from public.customer_groups cg
  left join public.profiles bp
    on bp.customer_group_id = cg.id
   and bp.parent_tenant_id = v_books_id
  where cg.parent_tenant_id = v_books_id
    and cg.deleted_at is null
    and (
      v_search is null
      or cg.name ilike '%' || v_search || '%'
      or bp.name ilike '%' || v_search || '%'
      or bp.email ilike '%' || v_search || '%'
      or bp.phone ilike '%' || v_search || '%'
      or bp.phone_country_code ilike '%' || v_search || '%'
      or bp.address ilike '%' || v_search || '%'
    );

  select coalesce(jsonb_agg(row_json order by sort_id desc), '[]'::jsonb)
  into v_data
  from (
    select
      cg.id as sort_id,
      jsonb_build_object(
        'id', cg.id,
        'customer_group_id', cg.id,
        'profile_id', bp.id,
        'group_name', cg.name,
        'admin_name', coalesce(bp.name, cg.name),
        'email', bp.email,
        'phone', nullif(concat_ws(' ', bp.phone_country_code, bp.phone), ''),
        'address', bp.address,
        'accent_color', coalesce(cg.accent_color, '#B45F34'),
        'is_active', cg.is_active,
        'member_count', coalesce(mem.cnt, 0::bigint),
        'wallet_available_balance', coalesce(wa.available_balance, 0.00),
        'created_at', cg.created_at
      ) as row_json
    from public.customer_groups cg
    left join public.profiles bp
      on bp.customer_group_id = cg.id
     and bp.parent_tenant_id = v_books_id
    left join (
      select cgm.customer_group_id as c_group_id, count(*) as cnt
      from public.customer_group_members cgm
      group by cgm.customer_group_id
    ) mem on mem.c_group_id = cg.id
    left join public.cashbook_accounts wa
      on wa.parent_tenant_id = v_books_id
     and wa.entity_type = 'customer'
     and wa.entity_id = bp.id
     and wa.currency_code = 'BDT'
    where cg.parent_tenant_id = v_books_id
      and cg.deleted_at is null
      and (
        v_search is null
        or cg.name ilike '%' || v_search || '%'
        or bp.name ilike '%' || v_search || '%'
        or bp.email ilike '%' || v_search || '%'
        or bp.phone ilike '%' || v_search || '%'
        or bp.phone_country_code ilike '%' || v_search || '%'
        or bp.address ilike '%' || v_search || '%'
      )
    order by cg.id desc
    limit v_page_size
    offset (v_page - 1) * v_page_size
  ) q;

  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::numeric / v_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', v_page,
      'page_size', v_page_size,
      'total_pages', v_total_pages
    )
  );
end;
$$;


CREATE OR REPLACE FUNCTION "public"."list_customer_group_receipts"("p_tenant_id" bigint, "p_customer_group_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
  v_result jsonb;
begin
  if p_tenant_id is null or p_customer_group_id is null then
    raise exception 'Tenant and customer group are required.';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_result
  from (
    select
      gp.id,
      gp.payment_date,
      gp.amount,
      gp.unallocated_amount,
      gp.method,
      gp.reference,
      gp.note,
      gp.voided_at,
      gp.profile_id as profile_id,
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'id', gpi.id,
              'payment_method_code', gpi.payment_method_code,
              'amount', gpi.amount,
              'reference', gpi.reference,
              'bd_bank_id', gpi.bd_bank_id,
              'bank_name', b.name,
              'cheque_number', gpi.cheque_number,
              'cheque_date', gpi.cheque_date,
              'sort_order', gpi.sort_order
            )
            order by gpi.sort_order, gpi.id
          )
          from public.pay_instruments gpi
          left join public.bd_banks b on b.id = gpi.bd_bank_id
          where gpi.payment_id = gp.id
        ),
        '[]'::jsonb
      ) as instruments,
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'invoice_id', ip.global_invoice_id,
              'invoice_no', si.invoice_no,
              'amount', ip.amount
            )
            order by si.invoice_no
          )
          from public.pay_allocations ip
          join public.bills si on si.id = ip.global_invoice_id
          where ip.payment_id = gp.id
        ),
        '[]'::jsonb
      ) as allocations
    from public.pays gp
    where gp.tenant_id = p_tenant_id
      and (
        gp.customer_group_id = p_customer_group_id
        or gp.profile_id in (
          select pr.id from public.profiles pr where pr.customer_group_id = p_customer_group_id
        )
      )
      and coalesce(gp.method, '') <> 'wallet_credit'
    order by gp.voided_at nulls first, gp.payment_date desc, gp.id desc
  ) r;

  return v_result;
end;
$$;


CREATE OR REPLACE FUNCTION "public"."list_customer_groups_payout_summary"("p_tenant_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_customer_group_id" bigint DEFAULT NULL::bigint, "p_only_with_payable" boolean DEFAULT true) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
  v_result jsonb;
  v_search text;
begin
  if p_tenant_id is null then
    return '[]'::jsonb;
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_search := nullif(trim(p_search), '');

  if not (
    public.is_superadmin()
    or public.is_tenant_staff(p_tenant_id)
    or public.membership_has_module_action(v_parent_id, 'payments', 'view')
    or public.membership_has_module_action(p_tenant_id, 'payments', 'view')
  ) then
    return '[]'::jsonb;
  end if;

  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_result
  from (
    select
      cg.id as customer_group_id,
      cg.name,
      ('CUST-GRP-' || lpad(cg.id::text, 4, '0')) as account_code,
      coalesce(sum(wa.available_balance), 0.00)::numeric(12, 2) as payable_balance,
      (
        select coalesce(
          jsonb_agg(
            jsonb_build_object(
              'profile_id', pr2.id,
              'name', pr2.name,
              'payable_balance', coalesce(wa2.available_balance, 0.00)
            )
            order by coalesce(wa2.available_balance, 0.00) desc, pr2.name
          ),
          '[]'::jsonb
        )
        from public.profiles pr2
        left join public.cashbook_accounts wa2
          on wa2.parent_tenant_id = v_parent_id
         and wa2.entity_type = 'customer'
         and wa2.entity_id = pr2.id
         and wa2.currency_code = 'BDT'
        where pr2.customer_group_id = cg.id
          and pr2.profile_type = 'customer'::public.profile_party_type
          and (pr2.operating_tenant_id = v_parent_id or pr2.operating_tenant_id = p_tenant_id)
      ) as profiles
    from public.customer_groups cg
    inner join public.profiles pr
      on pr.customer_group_id = cg.id
     and (pr.operating_tenant_id = v_parent_id or pr.operating_tenant_id = p_tenant_id)
    left join public.cashbook_accounts wa
      on wa.parent_tenant_id = v_parent_id
     and wa.entity_type = 'customer'
     and wa.entity_id = pr.id
     and wa.currency_code = 'BDT'
    where (cg.parent_tenant_id = v_parent_id or cg.tenant_id = p_tenant_id)
      and (p_customer_group_id is null or cg.id = p_customer_group_id)
      and (
        v_search is null
        or cg.name ilike '%' || v_search || '%'
        or pr.name ilike '%' || v_search || '%'
        or coalesce(pr.phone, '') ilike '%' || v_search || '%'
        or coalesce(pr.email, '') ilike '%' || v_search || '%'
      )
    group by cg.id, cg.name
    having (
      not coalesce(p_only_with_payable, false)
      or coalesce(sum(wa.available_balance), 0.00) > 0.00
    )
    order by payable_balance desc nulls last, cg.name asc
    limit greatest(least(coalesce(p_limit, 50), 200), 1)
  ) r;

  return v_result;
end;
$$;


CREATE OR REPLACE FUNCTION "public"."list_procurement_demand_group_items"("p_tenant_id" bigint, "p_document_type" "text", "p_document_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_cursor_source_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_is_parent boolean;
  v_allowed boolean := false;
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 100));
  v_items jsonb := '[]'::jsonb;
  v_n integer := 0;
  v_has_more boolean := false;
  v_next_cursor jsonb := null;
  v_last_source_id bigint;
begin
  if p_tenant_id is null or p_document_id is null then
    raise exception 'tenant_id and document_id are required';
  end if;

  select (t.parent_id is null) into v_is_parent from public.tenants t where t.id = p_tenant_id;
  if not found then raise exception 'tenant not found: %', p_tenant_id; end if;

  if v_is_parent then
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  else
    v_allowed := public.is_tenant_staff(p_tenant_id);
  end if;
  if not coalesce(v_allowed, false) then raise exception 'access denied'; end if;

  if v_doc_type not in ('shop_order', 'pbc_costing_file') then
    raise exception 'invalid document_type: %', p_document_type;
  end if;

  with tenant_scope as (
    select t.id as tenant_id from public.tenants t
    where (
      (v_is_parent and (t.parent_id = p_tenant_id or t.id = p_tenant_id))
      or (not v_is_parent and t.id = p_tenant_id)
    )
  ),
  shop_lines as (
    select
      'shop_order'::text as document_type,
      o.id as document_id,
      'shop_order_item'::text as source_type,
      oi.id as source_id,
      oi.product_id,
      oi.name,
      oi.image_url,
      coalesce(p.barcode, '') as barcode,
      coalesce(p.product_code, '') as product_code,
      nullif(trim(coalesce(p.vendor_code, '')), '') as vendor_code,
      nullif(trim(coalesce(p.market_code, '')), '') as market_code,
      nullif(trim(coalesce(p.brand, '')), '') as brand,
      nullif(trim(coalesce(p.category, '')), '') as category,
      p.available_units,
      nullif(trim(coalesce(p.languages, '')), '') as languages,
      nullif(trim(coalesce(p.country_of_origin, '')), '') as country_of_origin,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer as quantity,
      pd.id as preorder_demand_id,
      pd.vendor_id,
      coalesce(pd.placed_quantity, 0) as placed_quantity,
      coalesce(pd.delivered_quantity, 0) as delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    inner join tenant_scope ts on ts.tenant_id = o.tenant_id
    left join public.products p on p.id = oi.product_id
    left join public.preorder_demand pd
      on pd.source_type = 'shop_order_item'
      and pd.source_id = oi.id
      and pd.tenant_id = o.tenant_id
    where v_doc_type = 'shop_order'
      and o.id = p_document_id
      and o.shop_type_snapshot = 'vendor_catalog'
  ),
  pbc_lines as (
    select
      'pbc_costing_file'::text as document_type,
      f.id as document_id,
      'pbc_costing_item'::text as source_type,
      pci.id as source_id,
      pci.product_id,
      coalesce(pci.name, p.name, 'Item') as name,
      coalesce(pci.image_url, p.image_url) as image_url,
      coalesce(pci.barcode, p.barcode, '') as barcode,
      coalesce(pci.product_code, p.product_code, '') as product_code,
      coalesce(
        nullif(trim(coalesce(pci.vendor_code, '')), ''),
        nullif(trim(coalesce(p.vendor_code, '')), '')
      ) as vendor_code,
      coalesce(
        nullif(trim(coalesce(pci.market_code, '')), ''),
        nullif(trim(coalesce(p.market_code, '')), '')
      ) as market_code,
      coalesce(
        nullif(trim(coalesce(pci.brand, '')), ''),
        nullif(trim(coalesce(p.brand, '')), '')
      ) as brand,
      nullif(trim(coalesce(p.category, '')), '') as category,
      p.available_units,
      nullif(trim(coalesce(p.languages, '')), '') as languages,
      nullif(trim(coalesce(p.country_of_origin, '')), '') as country_of_origin,
      greatest(
        case when pci.assigned_shipment_id is not null then 0
          else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        end,
        0
      )::integer as quantity,
      pd.id as preorder_demand_id,
      pd.vendor_id,
      coalesce(pd.placed_quantity, 0) as placed_quantity,
      coalesce(pd.delivered_quantity, 0) as delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    inner join tenant_scope ts on ts.tenant_id = f.tenant_id
    left join public.products p on p.id = pci.product_id
    left join public.preorder_demand pd
      on pd.source_type = 'pbc_costing_item'
      and pd.source_id = pci.id
      and pd.tenant_id = f.tenant_id
    where v_doc_type = 'pbc_costing_file'
      and f.id = p_document_id
      and f.profile_id is not null
  ),
  demand_lines as (
    select * from shop_lines
    union all
    select * from pbc_lines
  ),
  eligible_lines as (
    select dl.*
    from demand_lines dl
    where (
      dl.quantity > 0
      or dl.placed_quantity > 0
      or dl.delivered_quantity > 0
    )
      and (
        v_search is null
        or dl.name ilike '%' || v_search || '%'
        or coalesce(dl.barcode, '') ilike '%' || v_search || '%'
        or coalesce(dl.product_code, '') ilike '%' || v_search || '%'
      )
      and (
        p_cursor_source_id is null
        or dl.source_id > p_cursor_source_id
      )
  ),
  paged as (
    select el.*
    from eligible_lines el
    order by el.source_id
    limit v_limit + 1
  ),
  page_count as (
    select count(*)::integer as n from paged
  ),
  page_rows as (
    select p.*
    from paged p
    order by p.source_id
    limit v_limit
  ),
  item_json as (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'source_type', row.source_type,
          'source_id', row.source_id,
          'product_id', row.product_id,
          'name', row.name,
          'image_url', row.image_url,
          'barcode', nullif(row.barcode, ''),
          'product_code', nullif(row.product_code, ''),
          'vendor_code', row.vendor_code,
          'market_code', row.market_code,
          'brand', row.brand,
          'category', row.category,
          'available_units', row.available_units,
          'languages', row.languages,
          'country_of_origin', row.country_of_origin,
          'quantity', row.quantity,
          'need_quantity', row.quantity,
          'preorder_demand_id', row.preorder_demand_id,
          'vendor_id', row.vendor_id,
          'placed_quantity', row.placed_quantity,
          'delivered_quantity', row.delivered_quantity,
          'remaining_quantity', row.quantity - row.placed_quantity,
          'remaining_to_deliver', greatest(row.quantity - row.delivered_quantity, 0),
          'stock_picks', row.stock_picks
        )
        order by row.source_id
      ),
      '[]'::jsonb
    ) as items
    from page_rows row
  ),
  cursor_row as (
    select p.source_id
    from paged p
    order by p.source_id
    offset v_limit
    limit 1
  )
  select
    ij.items,
    pc.n,
    cr.source_id
  into v_items, v_n, v_last_source_id
  from item_json ij
  cross join page_count pc
  left join cursor_row cr on true;

  if v_n > v_limit then
    v_has_more := true;
    v_next_cursor := jsonb_build_object('source_id', v_last_source_id);
  end if;

  return jsonb_build_object(
    'meta', jsonb_build_object(
      'document_type', v_doc_type,
      'document_id', p_document_id,
      'limit', v_limit,
      'has_more', v_has_more,
      'next_cursor', v_next_cursor
    ),
    'items', v_items
  );
end;
$$;


CREATE OR REPLACE FUNCTION "public"."list_procurement_demand_groups"("p_tenant_id" bigint, "p_procurement_status" "text" DEFAULT 'procuring'::"text", "p_search" "text" DEFAULT NULL::"text", "p_child_tenant_id" bigint DEFAULT NULL::bigint, "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_is_parent boolean;
  v_allowed boolean := false;
  v_status text := lower(trim(coalesce(p_procurement_status, 'procuring')));
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_limit integer := greatest(coalesce(p_limit, 50), 1);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_groups jsonb := '[]'::jsonb;
  v_group_count integer := 0;
  v_item_count integer := 0;
  v_has_shop boolean := false;
  v_has_pbc boolean := false;
  v_sources text[] := '{}'::text[];
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  select (t.parent_id is null) into v_is_parent from public.tenants t where t.id = p_tenant_id;
  if not found then raise exception 'tenant not found: %', p_tenant_id; end if;

  if v_is_parent then
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  else
    v_allowed := public.is_tenant_staff(p_tenant_id);
  end if;
  if not coalesce(v_allowed, false) then raise exception 'access denied'; end if;
  if v_status not in ('procuring', 'packed', 'delivered') then
    raise exception 'invalid procurement status: %', v_status;
  end if;

  with tenant_scope as (
    select t.id as tenant_id from public.tenants t
    where (
      (v_is_parent and (t.parent_id = p_tenant_id or t.id = p_tenant_id))
      or (not v_is_parent and t.id = p_tenant_id)
    )
      and (p_child_tenant_id is null or t.id = p_child_tenant_id)
  ),
  shop_lines as (
    select
      'shop_order'::text as document_type,
      o.id as document_id,
      public.normalize_shop_order_procurement_status(o.status) as document_status,
      o.customer_group_id,
      cg.name as customer_group_name,
      null::jsonb as vendor,
      'shop_order_item'::text as source_type,
      oi.id as source_id,
      oi.product_id,
      oi.name,
      oi.image_url,
      coalesce(p.barcode, '') as barcode,
      coalesce(p.product_code, '') as product_code,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer as quantity,
      pd.id as preorder_demand_id,
      pd.vendor_id,
      coalesce(pd.placed_quantity, 0) as placed_quantity,
      coalesce(pd.delivered_quantity, 0) as delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks,
      o.global_invoice_id as invoice_id,
      nullif(trim(coalesce(o.name, o.order_no, '')), '') as document_name
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    inner join tenant_scope ts on ts.tenant_id = o.tenant_id
    left join public.customer_groups cg on cg.id = o.customer_group_id
    left join public.products p on p.id = oi.product_id
    left join public.preorder_demand pd
      on pd.source_type = 'shop_order_item'
      and pd.source_id = oi.id
      and pd.tenant_id = o.tenant_id
    where o.shop_type_snapshot = 'vendor_catalog'
      and public.normalize_shop_order_procurement_status(o.status) = v_status
      and (
        v_search is null
        or oi.name ilike '%' || v_search || '%'
        or o.name ilike '%' || v_search || '%'
        or o.order_no ilike '%' || v_search || '%'
        or coalesce(p.barcode, '') ilike '%' || v_search || '%'
        or coalesce(p.product_code, '') ilike '%' || v_search || '%'
      )
  ),
  pbc_lines as (
    select
      'pbc_costing_file'::text as document_type,
      f.id as document_id,
      public.normalize_pbc_procurement_status(f.status) as document_status,
      f.customer_group_id,
      cg.name as customer_group_name,
      case
        when v.id is not null then jsonb_build_object(
          'id', v.id,
          'code', coalesce(nullif(trim(f.vendor_code), ''), v.code),
          'name', v.name
        )
        when nullif(trim(f.vendor_code), '') is not null then jsonb_build_object(
          'id', f.vendor_id,
          'code', trim(f.vendor_code),
          'name', null
        )
        else null::jsonb
      end as vendor,
      'pbc_costing_item'::text as source_type,
      pci.id as source_id,
      pci.product_id,
      coalesce(pci.name, p.name, 'Item') as name,
      coalesce(pci.image_url, p.image_url) as image_url,
      coalesce(pci.barcode, p.barcode, '') as barcode,
      coalesce(pci.product_code, p.product_code, '') as product_code,
      greatest(
        case when pci.assigned_shipment_id is not null then 0
          else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        end,
        0
      )::integer as quantity,
      pd.id as preorder_demand_id,
      pd.vendor_id,
      coalesce(pd.placed_quantity, 0) as placed_quantity,
      coalesce(pd.delivered_quantity, 0) as delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks,
      f.invoice_id,
      nullif(trim(coalesce(f.name, '')), '') as document_name
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    inner join tenant_scope ts on ts.tenant_id = f.tenant_id
    left join public.customer_groups cg on cg.id = f.customer_group_id
    left join public.products p on p.id = pci.product_id
    left join public.vendors v on v.id = f.vendor_id
    left join public.preorder_demand pd
      on pd.source_type = 'pbc_costing_item'
      and pd.source_id = pci.id
      and pd.tenant_id = f.tenant_id
    where f.profile_id is not null
      and public.normalize_pbc_procurement_status(f.status) = v_status
      and (
        v_search is null
        or coalesce(pci.name, p.name, '') ilike '%' || v_search || '%'
        or coalesce(f.name, '') ilike '%' || v_search || '%'
        or coalesce(pci.barcode, p.barcode, '') ilike '%' || v_search || '%'
        or coalesce(pci.product_code, p.product_code, '') ilike '%' || v_search || '%'
      )
  ),
  demand_lines as (
    select * from shop_lines
    union all
    select * from pbc_lines
  ),
  eligible_lines as (
    select dl.*
    from demand_lines dl
    where dl.quantity > 0
      or dl.placed_quantity > 0
      or dl.delivered_quantity > 0
  ),
  grouped as (
    select
      el.document_type,
      el.document_id,
      max(el.document_status) as document_status,
      max(el.customer_group_id) as customer_group_id,
      max(el.customer_group_name) as customer_group_name,
      (array_agg(el.vendor) filter (where el.vendor is not null))[1] as vendor,
      max(el.invoice_id) as invoice_id,
      max(el.document_name) as document_name,
      jsonb_agg(
        jsonb_build_object(
          'source_type', el.source_type,
          'source_id', el.source_id,
          'product_id', el.product_id,
          'name', el.name,
          'image_url', el.image_url,
          'barcode', nullif(el.barcode, ''),
          'product_code', nullif(el.product_code, ''),
          'quantity', el.quantity,
          'need_quantity', el.quantity,
          'preorder_demand_id', el.preorder_demand_id,
          'vendor_id', el.vendor_id,
          'placed_quantity', el.placed_quantity,
          'delivered_quantity', el.delivered_quantity,
          'remaining_quantity', el.quantity - el.placed_quantity,
          'remaining_to_deliver', greatest(el.quantity - el.delivered_quantity, 0),
          'stock_picks', el.stock_picks
        )
        order by el.source_id
      ) as items,
      count(*)::integer as item_count
    from eligible_lines el
    group by el.document_type, el.document_id
  ),
  paged as (
    select g.*, count(*) over ()::integer as total_groups
    from grouped g
    order by g.document_type, g.document_id
    limit v_limit offset v_offset
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'document_type', p.document_type,
          'document_id', p.document_id,
          'document_name', p.document_name,
          'document_status', p.document_status,
          'customer_group_id', p.customer_group_id,
          'customer_group_name', p.customer_group_name,
          'vendor', p.vendor,
          'invoice_id', p.invoice_id,
          'items', p.items
        )
        order by p.document_type, p.document_id
      ),
      '[]'::jsonb
    ),
    coalesce(max(p.total_groups), 0),
    coalesce(sum(p.item_count), 0),
    coalesce(bool_or(p.document_type = 'shop_order'), false),
    coalesce(bool_or(p.document_type = 'pbc_costing_file'), false)
  into v_groups, v_group_count, v_item_count, v_has_shop, v_has_pbc
  from paged p;

  if v_has_shop then v_sources := array_append(v_sources, 'shop_order'); end if;
  if v_has_pbc then v_sources := array_append(v_sources, 'pbc_costing'); end if;

  return jsonb_build_object(
    'meta', jsonb_build_object(
      'tenant_id', p_tenant_id,
      'procurement_status', v_status,
      'sources_included', to_jsonb(v_sources),
      'group_count', coalesce(jsonb_array_length(v_groups), 0),
      'item_count', v_item_count,
      'total_group_count', v_group_count,
      'limit', v_limit,
      'offset', v_offset,
      'has_more', v_group_count > (v_offset + v_limit)
    ),
    'groups', v_groups
  );
end;
$$;


CREATE OR REPLACE FUNCTION "public"."list_procurement_fulfill_groups"("p_tenant_id" bigint, "p_procurement_status" "text" DEFAULT 'procuring'::"text", "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_is_parent boolean;
  v_allowed boolean := false;
  v_status text := lower(trim(coalesce(p_procurement_status, 'procuring')));
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_limit integer := greatest(coalesce(p_limit, 50), 1);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_groups jsonb := '[]'::jsonb;
  v_group_count integer := 0;
  v_item_count integer := 0;
  v_has_shop boolean := false;
  v_has_pbc boolean := false;
  v_sources text[] := '{}'::text[];
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  select (t.parent_id is null) into v_is_parent from public.tenants t where t.id = p_tenant_id;
  if not found then raise exception 'tenant not found: %', p_tenant_id; end if;

  if v_is_parent then
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  else
    v_allowed := public.is_tenant_staff(p_tenant_id);
  end if;
  if not coalesce(v_allowed, false) then raise exception 'access denied'; end if;
  if v_status not in ('procuring', 'packed', 'delivered') then
    raise exception 'invalid procurement status: %', v_status;
  end if;

  with tenant_scope as (
    select t.id as tenant_id from public.tenants t
    where (
      (v_is_parent and (t.parent_id = p_tenant_id or t.id = p_tenant_id))
      or (not v_is_parent and t.id = p_tenant_id)
    )
  ),
  shop_lines as (
    select
      'shop_order'::text as document_type,
      o.id as document_id,
      public.normalize_shop_order_procurement_status(o.status) as document_status,
      o.customer_group_id,
      cg.name as customer_group_name,
      null::jsonb as vendor,
      'shop_order_item'::text as source_type,
      oi.id as source_id,
      oi.product_id,
      oi.name,
      oi.image_url,
      coalesce(p.barcode, '') as barcode,
      coalesce(p.product_code, '') as product_code,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer as quantity,
      pd.id as preorder_demand_id,
      pd.vendor_id,
      coalesce(pd.placed_quantity, 0) as placed_quantity,
      coalesce(pd.delivered_quantity, 0) as delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks,
      o.global_invoice_id as invoice_id,
      nullif(trim(coalesce(o.name, o.order_no, '')), '') as document_name
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    inner join tenant_scope ts on ts.tenant_id = o.tenant_id
    left join public.customer_groups cg on cg.id = o.customer_group_id
    left join public.products p on p.id = oi.product_id
    left join public.preorder_demand pd
      on pd.source_type = 'shop_order_item'
      and pd.source_id = oi.id
      and pd.tenant_id = o.tenant_id
    where o.shop_type_snapshot = 'vendor_catalog'
      and public.normalize_shop_order_procurement_status(o.status) = v_status
      and (
        v_search is null
        or oi.name ilike '%' || v_search || '%'
        or o.name ilike '%' || v_search || '%'
        or o.order_no ilike '%' || v_search || '%'
        or coalesce(p.barcode, '') ilike '%' || v_search || '%'
        or coalesce(p.product_code, '') ilike '%' || v_search || '%'
      )
  ),
  pbc_lines as (
    select
      'pbc_costing_file'::text as document_type,
      f.id as document_id,
      public.normalize_pbc_procurement_status(f.status) as document_status,
      f.customer_group_id,
      cg.name as customer_group_name,
      case
        when v.id is not null then jsonb_build_object(
          'id', v.id,
          'code', coalesce(nullif(trim(f.vendor_code), ''), v.code),
          'name', v.name
        )
        when nullif(trim(f.vendor_code), '') is not null then jsonb_build_object(
          'id', f.vendor_id,
          'code', trim(f.vendor_code),
          'name', null
        )
        else null::jsonb
      end as vendor,
      'pbc_costing_item'::text as source_type,
      pci.id as source_id,
      pci.product_id,
      coalesce(pci.name, p.name, 'Item') as name,
      coalesce(pci.image_url, p.image_url) as image_url,
      coalesce(pci.barcode, p.barcode, '') as barcode,
      coalesce(pci.product_code, p.product_code, '') as product_code,
      greatest(
        case when pci.assigned_shipment_id is not null then 0
          else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        end,
        0
      )::integer as quantity,
      pd.id as preorder_demand_id,
      pd.vendor_id,
      coalesce(pd.placed_quantity, 0) as placed_quantity,
      coalesce(pd.delivered_quantity, 0) as delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks,
      f.invoice_id,
      nullif(trim(coalesce(f.name, '')), '') as document_name
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    inner join tenant_scope ts on ts.tenant_id = f.tenant_id
    left join public.customer_groups cg on cg.id = f.customer_group_id
    left join public.products p on p.id = pci.product_id
    left join public.vendors v on v.id = f.vendor_id
    left join public.preorder_demand pd
      on pd.source_type = 'pbc_costing_item'
      and pd.source_id = pci.id
      and pd.tenant_id = f.tenant_id
    where f.profile_id is not null
      and public.normalize_pbc_procurement_status(f.status) = v_status
      and (
        v_search is null
        or coalesce(pci.name, p.name, '') ilike '%' || v_search || '%'
        or coalesce(f.name, '') ilike '%' || v_search || '%'
        or coalesce(pci.barcode, p.barcode, '') ilike '%' || v_search || '%'
        or coalesce(pci.product_code, p.product_code, '') ilike '%' || v_search || '%'
      )
  ),
  demand_lines as (
    select * from shop_lines
    union all
    select * from pbc_lines
  ),
  eligible_lines as (
    select dl.*
    from demand_lines dl
    where dl.quantity > 0
      or dl.placed_quantity > 0
      or dl.delivered_quantity > 0
  ),
  grouped as (
    select
      el.document_type,
      el.document_id,
      max(el.document_status) as document_status,
      max(el.customer_group_id) as customer_group_id,
      max(el.customer_group_name) as customer_group_name,
      (array_agg(el.vendor) filter (where el.vendor is not null))[1] as vendor,
      max(el.invoice_id) as invoice_id,
      max(el.document_name) as document_name,
      count(*)::integer as item_count,
      count(*) filter (where el.quantity > el.delivered_quantity)::integer as unallocated_item_count
    from eligible_lines el
    group by el.document_type, el.document_id
  ),
  enriched as (
    select
      g.*,
      inv.invoice_status,
      case
        when g.invoice_id is null then false
        else public.preorder_demand_invoice_items_stale(g.document_type, g.document_id, g.invoice_id)
      end as invoice_stale
    from grouped g
    left join public.bills inv on inv.id = g.invoice_id
  ),
  paged as (
    select e.*, count(*) over ()::integer as total_groups
    from enriched e
    order by e.document_type, e.document_id
    limit v_limit offset v_offset
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'document_type', p.document_type,
          'document_id', p.document_id,
          'document_name', p.document_name,
          'document_status', p.document_status,
          'customer_group_id', p.customer_group_id,
          'customer_group_name', p.customer_group_name,
          'vendor', p.vendor,
          'invoice_id', p.invoice_id,
          'invoice_status', p.invoice_status,
          'invoice_stale', coalesce(p.invoice_stale, false),
          'item_count', p.item_count,
          'unallocated_item_count', p.unallocated_item_count
        )
        order by p.document_type, p.document_id
      ),
      '[]'::jsonb
    ),
    coalesce(max(p.total_groups), 0),
    coalesce(sum(p.item_count), 0),
    coalesce(bool_or(p.document_type = 'shop_order'), false),
    coalesce(bool_or(p.document_type = 'pbc_costing_file'), false)
  into v_groups, v_group_count, v_item_count, v_has_shop, v_has_pbc
  from paged p;

  if v_has_shop then v_sources := array_append(v_sources, 'shop_order'); end if;
  if v_has_pbc then v_sources := array_append(v_sources, 'pbc_costing'); end if;

  return jsonb_build_object(
    'meta', jsonb_build_object(
      'tenant_id', p_tenant_id,
      'procurement_status', v_status,
      'sources_included', to_jsonb(v_sources),
      'group_count', coalesce(jsonb_array_length(v_groups), 0),
      'item_count', v_item_count,
      'total_group_count', v_group_count,
      'limit', v_limit,
      'offset', v_offset,
      'has_more', v_group_count > (v_offset + v_limit)
    ),
    'groups', v_groups
  );
end;
$$;


CREATE OR REPLACE FUNCTION "public"."mark_shop_order_item_shortfall"("p_order_item_id" bigint, "p_shortfall_qty" integer, "p_reason" "text" DEFAULT NULL::"text", "p_add_to_demand_bucket" boolean DEFAULT true) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_item public.shop_order_items%rowtype;
  v_order public.shop_orders%rowtype;
  v_picked integer := 0;
  v_profile_id bigint;
begin
  if p_shortfall_qty is null or p_shortfall_qty <= 0 then
    raise exception 'shortfall quantity must be positive';
  end if;

  select * into v_item from public.shop_order_items where id = p_order_item_id for update;
  select * into v_order from public.shop_orders where id = v_item.order_id for update;

  if not public.is_tenant_staff(v_order.tenant_id) then raise exception 'access denied'; end if;
  if v_order.status <> 'processing'::public.shop_order_status then
    raise exception 'shortfall only allowed while processing';
  end if;
  if coalesce(v_item.is_fulfillment_unavailable, false) then
    raise exception 'line is fully unavailable';
  end if;

  select coalesce(sum(sp.quantity), 0) into v_picked
  from public.shop_order_item_stock_picks sp where sp.order_item_id = p_order_item_id;

  if v_picked + p_shortfall_qty > v_item.quantity then
    raise exception 'shortfall exceeds remaining qty';
  end if;

  update public.shop_order_items
  set shortfall_quantity = p_shortfall_qty, updated_at = now()
  where id = p_order_item_id;

  if coalesce(p_add_to_demand_bucket, true) then
    v_profile_id := coalesce(
      v_order.profile_id,
      public.resolve_customer_profile_for_group(v_order.tenant_id, v_order.customer_group_id)
    );
    if v_profile_id is not null then
      perform public.add_demand_bucket_item(
        v_order.tenant_id, v_profile_id, v_item.product_id,
        'shop_order'::public.demand_bucket_source_type, v_order.id,
        jsonb_build_object('order_item_id', v_item.id, 'reason', coalesce(p_reason, 'partial_shortfall')),
        p_shortfall_qty
      );
    end if;
  end if;

  perform public.recompute_dropship_cod_collect_amount(v_order.id);
  return jsonb_build_object('success', true);
end;
$$;


CREATE OR REPLACE FUNCTION "public"."mark_shop_order_item_unavailable"("p_order_item_id" bigint, "p_reason" "text" DEFAULT NULL::"text", "p_add_to_demand_bucket" boolean DEFAULT true) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_item public.shop_order_items%rowtype;
  v_order public.shop_orders%rowtype;
  v_pick_count integer := 0;
  v_profile_id bigint;
begin
  select * into v_item from public.shop_order_items where id = p_order_item_id for update;
  if v_item.id is null then
    raise exception 'order item not found';
  end if;

  select * into v_order from public.shop_orders where id = v_item.order_id for update;
  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.status <> 'processing'::public.shop_order_status then
    raise exception 'unavailable is only allowed while order is processing';
  end if;

  select count(*) into v_pick_count
  from public.shop_order_item_stock_picks sp
  where sp.order_item_id = p_order_item_id;

  if v_pick_count > 0 then
    raise exception 'cannot mark unavailable while picks exist — remove picks first';
  end if;

  update public.shop_order_items
  set
    is_fulfillment_unavailable = true,
    unavailable_reason = nullif(trim(p_reason), ''),
    unavailable_at = now(),
    unavailable_by_email = public.current_user_email(),
    confirmed_quantity = 0,
    global_stock_id = null,
    updated_at = now()
  where id = p_order_item_id;

  if coalesce(p_add_to_demand_bucket, true) then
    v_profile_id := coalesce(
      v_order.profile_id,
      public.resolve_customer_profile_for_group(v_order.tenant_id, v_order.customer_group_id)
    );
    if v_profile_id is not null then
      perform public.add_demand_bucket_item(
        v_order.tenant_id,
        v_profile_id,
        v_item.product_id,
        'shop_order'::public.demand_bucket_source_type,
        v_order.id,
        jsonb_build_object(
          'order_item_id', v_item.id,
          'name', v_item.name,
          'reason', coalesce(nullif(trim(p_reason), ''), 'fulfillment_unavailable')
        ),
        v_item.quantity
      );
    end if;
  end if;

  perform public.recompute_dropship_cod_collect_amount(v_order.id);

  return jsonb_build_object('success', true);
end;
$$;


CREATE OR REPLACE FUNCTION "public"."pop_demand_bucket_item"("p_bucket_item_id" bigint, "p_popped_into_type" "text", "p_popped_into_id" bigint) RETURNS "public"."customer_demand_bucket_items"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.customer_demand_bucket_items;
begin
  if p_bucket_item_id is null then
    raise exception 'bucket_item_id is required';
  end if;
  if nullif(trim(coalesce(p_popped_into_type, '')), '') is null
     or p_popped_into_id is null then
    raise exception 'popped_into_type and popped_into_id are required';
  end if;

  select * into v_row
  from public.customer_demand_bucket_items
  where id = p_bucket_item_id;

  if not found then
    raise exception 'bucket item not found: %', p_bucket_item_id;
  end if;

  if v_row.status <> 'open' then
    raise exception 'bucket item % is not open', p_bucket_item_id;
  end if;

  if not public.can_access_demand_bucket_profile(v_row.tenant_id, v_row.profile_id, false) then
    raise exception 'access denied';
  end if;

  update public.customer_demand_bucket_items
  set
    status = 'popped',
    popped_at = now(),
    popped_into_type = trim(p_popped_into_type),
    popped_into_id = p_popped_into_id,
    updated_at = now()
  where id = p_bucket_item_id
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.pop_demand_bucket_items(
  p_bucket_item_ids bigint[],
  p_popped_into_type text,
  p_popped_into_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id bigint;
  v_row public.customer_demand_bucket_items;
  v_items jsonb := '[]'::jsonb;
begin
  if p_bucket_item_ids is null or cardinality(p_bucket_item_ids) = 0 then
    return jsonb_build_object('items', '[]'::jsonb, 'count', 0);
  end if;

  foreach v_id in array p_bucket_item_ids loop
    v_row := public.pop_demand_bucket_item(v_id, p_popped_into_type, p_popped_into_id);
    v_items := v_items || jsonb_build_array(to_jsonb(v_row));
  end loop;

  return jsonb_build_object(
    'items', v_items,
    'count', jsonb_array_length(v_items)
  );
end;
$$;


CREATE OR REPLACE FUNCTION "public"."process_wholesale_invoice_return"("p_invoice_id" bigint, "p_items" "jsonb", "p_return_charge_amount" numeric DEFAULT 0, "p_refund_method" "text" DEFAULT NULL::"text", "p_payout_account_id" bigint DEFAULT NULL::bigint, "p_note" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.bills;
  v_item_elem jsonb;
  v_item_id bigint;
  v_return_qty numeric;
  v_to_availability public.stock_availability;
  v_to_grade_tag_id bigint;
  v_item_note text;
  v_db_item public.bill_lines%rowtype;
  v_parent_id bigint;
  v_eff_tenant_id bigint;
  v_total_return_value numeric(12,2) := 0.00;
  v_line_unit_price numeric(12,2);
  v_line_return_val numeric(12,2);
  v_new_subtotal numeric(12,2) := 0.00;
  v_charges numeric(12,2) := 0.00;
  v_discount numeric(12,2) := 0.00;
  v_paid numeric(12,2) := 0.00;
  v_new_total numeric(12,2) := 0.00;
  v_new_due numeric(12,2) := 0.00;
  v_excess_paid numeric(12,2) := 0.00;
  v_refund_amount numeric(12,2) := 0.00;
  v_return_count integer := 0;
  v_payout_id text;
  v_charge numeric(12,2) := 0.00;
begin
  if p_invoice_id is null then
    raise exception 'Invoice ID is required';
  end if;

  select * into v_invoice
  from public.bills
  where id = p_invoice_id
  for update;

  if v_invoice.id is null then
    raise exception 'Invoice not found';
  end if;

  if v_invoice.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'Returns can only be processed on issued/posted invoices';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'At least one return item must be provided';
  end if;

  v_charge := greatest(coalesce(p_return_charge_amount, 0.00), 0.00);
  v_eff_tenant_id := coalesce(v_invoice.issued_by_tenant_id, v_invoice.parent_tenant_id);
  v_parent_id := coalesce(v_invoice.parent_tenant_id, v_invoice.issued_by_tenant_id);

  -- 1. Loop and process each return item
  for v_item_elem in select * from jsonb_array_elements(p_items) loop
    v_item_id := (v_item_elem->>'invoice_item_id')::bigint;
    v_return_qty := (v_item_elem->>'quantity')::numeric;
    v_to_availability := coalesce(
      (v_item_elem->>'to_availability')::public.stock_availability,
      'held'::public.stock_availability
    );
    v_to_grade_tag_id := (v_item_elem->>'to_grade_tag_id')::bigint;
    v_item_note := nullif(trim(v_item_elem->>'note'), '');

    if v_item_id is null then
      raise exception 'invoice_item_id is required for all items';
    end if;

    if v_return_qty is null or v_return_qty <= 0 then
      continue; -- Skip 0 or empty quantity items
    end if;

    select * into v_db_item
    from public.bill_lines
    where id = v_item_id and invoice_id = p_invoice_id
    for update;

    if v_db_item.id is null then
      raise exception 'Invoice item % not found on this invoice', v_item_id;
    end if;

    if (v_db_item.return_quantity + v_return_qty) > v_db_item.quantity then
      raise exception 'Return quantity % exceeds available returnable quantity % for %',
        v_return_qty,
        (v_db_item.quantity - v_db_item.return_quantity),
        v_db_item.name_snapshot;
    end if;

    -- Calculate line return value
    v_line_unit_price := v_db_item.sell_price_amount;
    v_line_return_val := round(v_return_qty * v_line_unit_price, 2);
    v_total_return_value := v_total_return_value + v_line_return_val;

    -- Insert record into sales_return_items
    insert into public.sales_return_items (
      parent_tenant_id,
      invoice_id,
      invoice_item_id,
      global_stock_id,
      quantity,
      return_charge_amount,
      note
    ) values (
      v_parent_id,
      p_invoice_id,
      v_item_id,
      v_db_item.global_stock_id,
      v_return_qty,
      0.00,
      v_item_note
    );

    -- Update bill_lines cumulative return_quantity; sold quantity stays.
    -- line_total_amount is the net after return credit (kept qty × price − line discount).
    update public.bill_lines
    set
      return_quantity = return_quantity + v_return_qty,
      line_total_amount = greatest(
        (v_db_item.quantity - (v_db_item.return_quantity + v_return_qty)) * v_db_item.sell_price_amount
        - coalesce(v_db_item.line_discount_amount, 0),
        0
      ),
      updated_at = now()
    where id = v_item_id;

    -- Post return_inbound stock movement
    if v_db_item.global_stock_id is not null then
      perform public.create_and_post_stock_movement(
        p_tenant_id => v_parent_id,
        p_stock_id => v_db_item.global_stock_id,
        p_quantity => ceil(v_return_qty)::integer,
        p_to_location_id => public.default_returns_stock_location_id(v_parent_id),
        p_to_availability => v_to_availability,
        p_to_grade_tag_id => coalesce(v_to_grade_tag_id, public.default_stock_grade_tag_id()),
        p_movement_type => 'return_inbound'::public.stock_movement_type,
        p_notes => coalesce(v_item_note, 'Wholesale invoice return #' || coalesce(v_invoice.invoice_no, p_invoice_id::text)),
        p_reference_type => 'sales_invoice',
        p_reference_id => p_invoice_id::text
      );
    end if;

    v_return_count := v_return_count + 1;
  end loop;

  if v_return_count = 0 then
    raise exception 'No items with quantity > 0 were selected for return';
  end if;

  -- 2. Recalculate invoice totals based on retained quantities
  select coalesce(sum((quantity - return_quantity) * sell_price_amount - line_discount_amount), 0.00)
  into v_new_subtotal
  from public.bill_lines
  where invoice_id = p_invoice_id;

  v_charges := coalesce(v_invoice.shipping_charge, 0.00)
             + coalesce(v_invoice.wrapping_charge, 0.00)
             + coalesce(v_invoice.print_charge, 0.00)
             + v_charge; -- add return handling charge if any

  v_discount := coalesce(v_invoice.discount_amount, 0.00);
  v_paid := coalesce(v_invoice.paid_amount, 0.00);

  v_new_total := greatest(v_new_subtotal + v_charges - v_discount, 0.00);
  v_new_due := greatest(v_new_total - v_paid, 0.00);
  v_excess_paid := greatest(v_paid - v_new_total, 0.00);

  -- 3. Handle excess overpayment refund if applicable
  if v_excess_paid > 0.00 then
    if p_refund_method = 'wallet_credit' and v_invoice.profile_id is not null then
      -- Ensure wallet account exists
      insert into public.cashbook_accounts (
        tenant_id, entity_type, entity_id, currency_code,
        available_balance, locked_balance, pending_balance
      ) values (
        v_eff_tenant_id, 'customer', v_invoice.profile_id, 'BDT',
        0.0000, 0.0000, 0.0000
      ) on conflict (tenant_id, entity_type, entity_id, currency_code) do nothing;

      -- Credit Customer Wallet via universal ledger
      perform public.record_ledger_transaction(
        p_tenant_id => v_eff_tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_invoice.profile_id,
        p_type => 'credit',
        p_amount => v_excess_paid,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'sales_invoice_return',
        p_source_id => p_invoice_id::text,
        p_metadata => jsonb_build_object(
          'section', 'returns',
          'purpose', 'wholesale_return_wallet_credit',
          'transaction_type', 'return_credit',
          'label', 'Return Credit (Wallet)',
          'invoice_id', p_invoice_id,
          'invoice_no', v_invoice.invoice_no,
          'notes', p_note
        )
      );

      v_refund_amount := v_excess_paid;

    elsif p_refund_method = 'payout' and v_invoice.profile_id is not null then
      v_payout_id := 'RET-PO-' || gen_random_uuid()::text;

      -- Payout: Debit Tenant Cash (cash outflow from business to customer)
      perform public.record_ledger_transaction(
        p_tenant_id => v_eff_tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => v_eff_tenant_id,
        p_type => 'debit',
        p_amount => v_excess_paid,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'payout',
        p_source_id => v_payout_id,
        p_metadata => jsonb_build_object(
          'section', 'payout_earned',
          'purpose', 'wholesale_return_payout',
          'transaction_type', 'return_cash_payout',
          'label', 'Return Cash Payout',
          'invoice_id', p_invoice_id,
          'invoice_no', v_invoice.invoice_no,
          'profile_id', v_invoice.profile_id,
          'notes', p_note
        )
      );

      v_refund_amount := v_excess_paid;
    end if;
  end if;

  -- 4. Update bills header
  update public.bills
  set
    subtotal_amount = v_new_subtotal,
    total_amount = v_new_total,
    due_amount = v_new_due,
    payment_status = case
      when v_new_due <= 0.00 then 'paid'
      when v_paid > 0.00 and v_new_due > 0.00 then 'partially_paid'
      else 'due'
    end,
    updated_at = now()
  where id = p_invoice_id
  returning * into v_invoice;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_no', v_invoice.invoice_no,
    'new_subtotal', v_new_subtotal,
    'new_total', v_new_total,
    'new_due', v_new_due,
    'paid_amount', v_paid,
    'excess_paid', v_excess_paid,
    'refund_amount', v_refund_amount,
    'refund_method', p_refund_method,
    'payment_status', v_invoice.payment_status,
    'returned_items_count', v_return_count
  );
end;
$$;


CREATE OR REPLACE FUNCTION "public"."set_preorder_demand_vendor_for_document"("p_tenant_id" bigint, "p_document_type" "text", "p_document_id" bigint, "p_vendor_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_is_parent boolean;
  v_allowed boolean := false;
  v_line_tenant_id bigint;
  v_doc_status text;
  v_updated integer := 0;
begin
  if p_tenant_id is null or p_document_id is null then
    raise exception 'tenant_id and document_id are required';
  end if;
  if p_vendor_id is null then
    raise exception 'vendor_id is required';
  end if;

  select (t.parent_id is null) into v_is_parent from public.tenants t where t.id = p_tenant_id;
  if not found then
    raise exception 'tenant not found: %', p_tenant_id;
  end if;

  if v_is_parent then
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  else
    v_allowed := public.is_tenant_staff(p_tenant_id);
  end if;
  if not coalesce(v_allowed, false) then
    raise exception 'access denied';
  end if;

  if v_doc_type = 'shop_order' then
    select
      o.tenant_id,
      public.normalize_shop_order_procurement_status(o.status)
    into v_line_tenant_id, v_doc_status
    from public.shop_orders o
    where o.id = p_document_id
      and o.shop_type_snapshot = 'vendor_catalog';

    if v_line_tenant_id is null then
      raise exception 'shop order not found or not vendor catalog';
    end if;
  elsif v_doc_type = 'pbc_costing_file' then
    select
      f.tenant_id,
      public.normalize_pbc_procurement_status(f.status)
    into v_line_tenant_id, v_doc_status
    from public.product_based_costing_files f
    where f.id = p_document_id
      and f.profile_id is not null;

    if v_line_tenant_id is null then
      raise exception 'costing file not found';
    end if;
  else
    raise exception 'invalid document_type: %', p_document_type;
  end if;

  if not public.can_access_preorder_demand_tenant(p_tenant_id)
    and not public.can_access_preorder_demand_tenant(v_line_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_line_tenant_id <> p_tenant_id then
    if not exists (
      select 1
      from public.tenants t
      where t.id = v_line_tenant_id
        and t.parent_id = p_tenant_id
        and public.user_can_manage_parent_tenant(p_tenant_id)
    ) then
      raise exception 'tenant mismatch for demand document';
    end if;
  end if;

  if v_doc_status <> 'procuring' then
    raise exception 'document is not open for vendor updates';
  end if;

  if v_doc_type = 'shop_order' then
    with lines as (
      select
        o.tenant_id,
        oi.id as source_id
      from public.shop_order_items oi
      inner join public.shop_orders o on o.id = oi.order_id
      where o.id = p_document_id
        and o.shop_type_snapshot = 'vendor_catalog'
    ),
    upserted as (
      insert into public.preorder_demand (
        tenant_id,
        source_type,
        source_id,
        vendor_id,
        placed_quantity,
        delivered_quantity,
        stock_picks,
        updated_by_user_id
      )
      select
        l.tenant_id,
        'shop_order_item'::public.preorder_demand_source_type,
        l.source_id,
        p_vendor_id,
        0,
        0,
        '[]'::jsonb,
        auth.uid()
      from lines l
      on conflict (source_type, source_id) do update set
        vendor_id = excluded.vendor_id,
        updated_by_user_id = auth.uid(),
        updated_at = now()
      returning 1
    )
    select count(*)::integer into v_updated from upserted;
  else
    with lines as (
      select
        f.tenant_id,
        pci.id as source_id
      from public.product_based_costing_items pci
      inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
      where f.id = p_document_id
        and f.profile_id is not null
    ),
    upserted as (
      insert into public.preorder_demand (
        tenant_id,
        source_type,
        source_id,
        vendor_id,
        placed_quantity,
        delivered_quantity,
        stock_picks,
        updated_by_user_id
      )
      select
        l.tenant_id,
        'pbc_costing_item'::public.preorder_demand_source_type,
        l.source_id,
        p_vendor_id,
        0,
        0,
        '[]'::jsonb,
        auth.uid()
      from lines l
      on conflict (source_type, source_id) do update set
        vendor_id = excluded.vendor_id,
        updated_by_user_id = auth.uid(),
        updated_at = now()
      returning 1
    )
    select count(*)::integer into v_updated from upserted;
  end if;

  return jsonb_build_object(
    'document_type', v_doc_type,
    'document_id', p_document_id,
    'vendor_id', p_vendor_id,
    'updated_count', v_updated
  );
end;
$$;


CREATE OR REPLACE FUNCTION "public"."staff_set_catalog_ordered_qty"("p_order_id" bigint, "p_items" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order record;
  v_desk_tenant_id bigint;
  v_item_row record;
  v_target_qty integer;
  v_allocated integer;
  v_shortfall integer;
  v_product record;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    raise exception 'Order not found: %', p_order_id;
  end if;

  v_desk_tenant_id := coalesce(v_order.parent_tenant_id, v_order.tenant_id);

  if not public.is_tenant_staff(v_desk_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.shop_type_snapshot <> 'vendor_catalog' then
    raise exception 'staff_set_catalog_ordered_qty is only valid for vendor_catalog orders.';
  end if;

  if public.normalize_shop_order_procurement_status(v_order.status) <> 'procuring' then
    raise exception 'order must be procuring to mark packed';
  end if;

  update public.shop_orders
  set
    status = 'packed'::public.shop_order_status,
    placed_at = coalesce(placed_at, now()),
    updated_at = now()
  where id = p_order_id;

  for v_item_row in
    select oi.*
    from public.shop_order_items oi
    where oi.order_id = p_order_id
  loop
    v_target_qty := coalesce(v_item_row.confirmed_quantity, v_item_row.quantity, 0);

    select coalesce(pd.delivered_quantity, 0)
    into v_allocated
    from public.preorder_demand pd
    where pd.source_type = 'shop_order_item'
      and pd.source_id = v_item_row.id;

    v_shortfall := greatest(v_target_qty - coalesce(v_allocated, 0), 0);

    if v_shortfall > 0 and v_order.profile_id is not null then
        select p.barcode, p.product_code
        into v_product
        from public.products p
        where p.id = v_item_row.product_id;

        perform public.add_demand_bucket_item_internal(
          p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
          p_profile_id => v_order.profile_id,
          p_product_id => v_item_row.product_id,
          p_source_type => 'shop_order_item',
          p_source_id => v_item_row.id,
          p_snapshot => jsonb_build_object(
            'name', coalesce(v_item_row.name, ''),
            'image_url', v_item_row.image_url,
            'barcode', v_product.barcode,
            'product_code', v_product.product_code,
            'note', null
          ),
          p_quantity => v_shortfall
        );

        insert into public.customer_order_backlog_items (
          tenant_id,
          profile_id,
          product_id,
          order_id,
          order_item_id,
          requested_quantity,
          fulfilled_quantity,
          backlog_status
        ) values (
          v_order.tenant_id,
          v_order.profile_id,
          v_item_row.product_id,
          p_order_id,
          v_item_row.id,
          v_shortfall,
          0,
          'open'
        )
        on conflict (tenant_id, profile_id, product_id)
        do update set
          requested_quantity = customer_order_backlog_items.requested_quantity + excluded.requested_quantity,
          backlog_status = 'open',
          updated_at = now();
    end if;
  end loop;

  perform public.notify_catalog_shop_order(
    p_order_id := p_order_id,
    p_notify_staff := false,
    p_notify_customer := true,
    p_event_type := 'catalog.order.packed',
    p_title := format('%s is packing', v_order.order_no),
    p_body := 'We will mark it on the way when it ships.'
  );

  return public.get_shop_order_for_staff(v_desk_tenant_id, p_order_id);
end;
$$;

create or replace function public.staff_set_catalog_delivered_qty(
  p_order_id bigint,
  p_items jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_desk_tenant_id bigint;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    raise exception 'Order not found: %', p_order_id;
  end if;

  v_desk_tenant_id := coalesce(v_order.parent_tenant_id, v_order.tenant_id);

  if not public.is_tenant_staff(v_desk_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.shop_type_snapshot <> 'vendor_catalog' then
    raise exception 'staff_set_catalog_delivered_qty is only valid for vendor_catalog orders.';
  end if;

  update public.shop_orders
  set
    status = 'delivered'::public.shop_order_status,
    fulfilled_at = coalesce(fulfilled_at, now()),
    updated_at = now()
  where id = p_order_id;

  perform public.notify_catalog_shop_order(
    p_order_id := p_order_id,
    p_notify_staff := false,
    p_notify_customer := true,
    p_event_type := 'catalog.order.delivered',
    p_title := format('Order %s delivered', v_order.order_no),
    p_body := 'Open the order for details.'
  );

  return public.get_shop_order_for_staff(v_desk_tenant_id, p_order_id);
end;
$$;


CREATE OR REPLACE FUNCTION "public"."trg_fn_auto_upsert_pbc_backlog"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_file public.product_based_costing_files%rowtype;
  v_tenant_id bigint;
  v_other_id bigint;
  v_open_qty numeric;
  v_prod record;
  v_price_gbp numeric;
  v_name text;
begin
  if tg_op = 'DELETE' then
    if old.product_id is not null and old.product_based_costing_file_id is not null then
      select * into v_file
      from public.product_based_costing_files
      where id = old.product_based_costing_file_id;

      if v_file.id is not null then
        v_tenant_id := v_file.tenant_id;
        if v_tenant_id is null and v_file.profile_id is not null then
          select tenant_id into v_tenant_id
          from public.profiles
          where id = v_file.profile_id;
        end if;

        select pci.id into v_other_id
        from public.product_based_costing_items pci
        inner join public.product_based_costing_files pcf
          on pcf.id = pci.product_based_costing_file_id
        where pci.product_id = old.product_id
          and pcf.profile_id is not distinct from v_file.profile_id
        order by pci.updated_at desc nulls last, pci.id desc
        limit 1;

        if v_other_id is not null then
          perform public.upsert_pbc_backlog_from_item(v_other_id);
        elsif v_tenant_id is not null and v_file.profile_id is not null then
          v_open_qty := coalesce(old.confirmed_quantity, old.quantity, 0);

          if coalesce(v_file.status, 'pending') in ('pending', 'offered')
             and v_open_qty > 0
          then
            select
              p.name,
              p.image_url,
              p.list_price_amount,
              p.product_weight,
              p.package_weight,
              p.barcode,
              p.product_code,
              gc.code as list_price_currency_code
            into v_prod
            from public.products p
            left join public.global_currencies gc on gc.id = p.list_price_currency_id
            where p.id = old.product_id;

            v_name := coalesce(old.name, v_prod.name);
            v_price_gbp := coalesce(
              old.price_gbp,
              case
                when v_prod.list_price_currency_code is null or v_prod.list_price_currency_code = 'GBP'
                  then v_prod.list_price_amount
                else null
              end
            );

            if v_name is not null then
              insert into public.product_based_costing_backlog_items (
                tenant_id,
                profile_id,
                product_id,
                open_quantity,
                name,
                image_url,
                barcode,
                product_code,
                price_gbp,
                product_weight,
                package_weight,
                last_costing_file_id,
                last_costing_item_id,
                updated_at
              )
              values (
                v_tenant_id,
                v_file.profile_id,
                old.product_id,
                round(v_open_qty)::integer,
                v_name,
                coalesce(old.image_url, v_prod.image_url),
                coalesce(old.barcode, v_prod.barcode),
                coalesce(old.product_code, v_prod.product_code),
                v_price_gbp,
                coalesce(old.product_weight::numeric, v_prod.product_weight),
                coalesce(old.package_weight::numeric, v_prod.package_weight),
                v_file.id,
                null,
                now()
              )
              on conflict (tenant_id, profile_id, product_id)
              do update set
                open_quantity = excluded.open_quantity,
                name = excluded.name,
                image_url = excluded.image_url,
                barcode = excluded.barcode,
                product_code = excluded.product_code,
                price_gbp = excluded.price_gbp,
                product_weight = excluded.product_weight,
                package_weight = excluded.package_weight,
                last_costing_file_id = excluded.last_costing_file_id,
                last_costing_item_id = excluded.last_costing_item_id,
                updated_at = now();
            end if;
          else
            delete from public.product_based_costing_backlog_items
            where tenant_id = v_tenant_id
              and profile_id = v_file.profile_id
              and product_id = old.product_id;
          end if;
        end if;
      end if;
    end if;

    return old;
  end if;

  perform public.upsert_pbc_backlog_from_item(new.id);
  return new;
end;
$$;


CREATE OR REPLACE FUNCTION "public"."trg_fn_pbc_files_auto_tenant_id"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if new.tenant_id is not null then
    select coalesce(t.parent_id, t.id)
    into new.tenant_id
    from public.tenants t
    where t.id = new.tenant_id;
  elsif new.profile_id is not null then
    select coalesce(t.parent_id, t.id)
    into new.tenant_id
    from public.profiles pr
    inner join public.tenants t on t.id = pr.operating_tenant_id
    where pr.id = new.profile_id;
  end if;
  return new;
end;
$$;


CREATE OR REPLACE FUNCTION "public"."trg_fn_pbc_files_stamp_billing_profile"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if new.customer_group_id is not null then
    select bp.id
    into new.profile_id
    from public.profiles bp
    where bp.customer_group_id = new.customer_group_id;

    if new.profile_id is null then
      raise exception 'customer_group_id % has no linked customer profile', new.customer_group_id;
    end if;
  elsif tg_op = 'UPDATE' and new.customer_group_id is null and old.customer_group_id is not null then
    new.profile_id := null;
  end if;

  return new;
end;
$$;


CREATE OR REPLACE FUNCTION "public"."update_sales_invoice_from_payload"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_inv_patch jsonb;
  v_items jsonb;
  v_remove_ids jsonb;
  v_item_elem jsonb;
  v_invoice public.bills;
  v_parent_id bigint;
  v_item_id bigint;
  v_global_stock_id bigint;
  v_quantity numeric;
  v_sell_price numeric;
  v_line_discount numeric;
  v_line_total numeric;
  v_unit_cost numeric;
  v_shipment_item_id bigint;
  v_product_id bigint;
  v_name_snapshot text;
  v_barcode_snapshot text;
  v_product_code_snapshot text;
  v_assigned_child bigint;
  v_stock_parent bigint;
  v_db_item public.bill_lines;
  v_removed_ids bigint[] := '{}';
  v_remove_id bigint;
  v_result_items jsonb := '[]'::jsonb;
  v_has_changes boolean := false;
  v_recompute boolean := true;
  v_dropship_sync boolean := false;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied', 'code', 'ACCESS_DENIED');
  end if;

  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    return jsonb_build_object('success', false, 'error', 'payload must be a JSON object', 'code', 'VALIDATION_ERROR');
  end if;

  v_dropship_sync := coalesce((p_payload->'options'->>'dropship_sync')::boolean, false);

  select * into v_invoice
  from public.bills
  where id = p_invoice_id
  for update;

  if v_invoice.id is null then
    return jsonb_build_object('success', false, 'error', 'invoice not found', 'code', 'NOT_FOUND');
  end if;

  if v_invoice.issued_by_tenant_id <> p_tenant_id then
    return jsonb_build_object('success', false, 'error', 'invoice does not belong to tenant', 'code', 'ACCESS_DENIED');
  end if;

  if v_invoice.invoice_status not in (
    'draft'::public.global_invoice_status,
    'proforma_generated'::public.global_invoice_status
  ) then
    if not (
      v_dropship_sync
      and v_invoice.invoice_type = 'dropship'::public.global_invoice_type
      and v_invoice.invoice_status = 'issued'::public.global_invoice_status
    ) then
      return jsonb_build_object(
        'success', false,
        'error', format('invoice is not editable (status: %s)', v_invoice.invoice_status),
        'code', 'INVOICE_NOT_EDITABLE'
      );
    end if;
  end if;

  v_inv_patch := p_payload->'invoice';
  v_items := coalesce(p_payload->'items', '[]'::jsonb);
  v_remove_ids := coalesce(p_payload->'remove_item_ids', '[]'::jsonb);
  v_recompute := coalesce((p_payload->'options'->>'recompute_totals')::boolean, true);

  if v_dropship_sync and v_invoice.invoice_status = 'issued'::public.global_invoice_status then
    v_remove_ids := '[]'::jsonb;
  end if;

  if (v_inv_patch is null or v_inv_patch = '{}'::jsonb)
     and jsonb_array_length(v_items) = 0
     and jsonb_array_length(v_remove_ids) = 0 then
    return jsonb_build_object('success', false, 'error', 'nothing to update', 'code', 'EMPTY_PAYLOAD');
  end if;

  v_parent_id := v_invoice.parent_tenant_id;

  if v_inv_patch is not null and jsonb_typeof(v_inv_patch) = 'object' and v_inv_patch <> '{}'::jsonb then
    if v_inv_patch ? 'profile_id' and nullif(v_inv_patch->>'profile_id', '') is not null then
      if not exists (
        select 1 from public.profiles pr
        where pr.id = (v_inv_patch->>'profile_id')::bigint
          and pr.operating_tenant_id = p_tenant_id
      ) then
        return jsonb_build_object('success', false, 'error', 'billing profile must belong to tenant', 'code', 'VALIDATION_ERROR');
      end if;
    end if;

    if v_inv_patch ? 'recipient_profile_id' and nullif(v_inv_patch->>'recipient_profile_id', '') is not null then
      if not exists (
        select 1 from public.recipient_profiles rp
        where rp.id = (v_inv_patch->>'recipient_profile_id')::bigint
          and rp.tenant_id = p_tenant_id
      ) then
        return jsonb_build_object('success', false, 'error', 'recipient profile must belong to tenant', 'code', 'VALIDATION_ERROR');
      end if;
    end if;

    update public.bills
    set
      invoice_no = case
        when v_inv_patch ? 'invoice_no' then coalesce(nullif(trim(v_inv_patch->>'invoice_no'), ''), invoice_no)
        else invoice_no
      end,
      invoice_date = case
        when v_inv_patch ? 'invoice_date' then coalesce(nullif(v_inv_patch->>'invoice_date', '')::date, invoice_date)
        else invoice_date
      end,
      due_date = case
        when v_inv_patch ? 'due_date' then nullif(v_inv_patch->>'due_date', '')::date
        else due_date
      end,
      profile_id = case
        when v_inv_patch ? 'profile_id' then nullif(v_inv_patch->>'profile_id', '')::bigint
        else profile_id
      end,
      recipient_profile_id = case
        when v_inv_patch ? 'recipient_profile_id' then nullif(v_inv_patch->>'recipient_profile_id', '')::bigint
        else recipient_profile_id
      end,
      recipient_name = case
        when v_inv_patch ? 'recipient_name' then nullif(trim(v_inv_patch->>'recipient_name'), '')
        else recipient_name
      end,
      recipient_phone = case
        when v_inv_patch ? 'recipient_phone' then nullif(trim(v_inv_patch->>'recipient_phone'), '')
        else recipient_phone
      end,
      recipient_address = case
        when v_inv_patch ? 'recipient_address' then nullif(trim(v_inv_patch->>'recipient_address'), '')
        else recipient_address
      end,
      note = case
        when v_inv_patch ? 'note' then nullif(trim(v_inv_patch->>'note'), '')
        else note
      end,
      discount_amount = case
        when v_inv_patch ? 'discount_amount' then coalesce(nullif(v_inv_patch->>'discount_amount', '')::numeric, 0)
        else discount_amount
      end,
      shipping_charge = case
        when v_inv_patch ? 'shipping_charge' then coalesce(nullif(v_inv_patch->>'shipping_charge', '')::numeric, 0)
        else shipping_charge
      end,
      channel_meta = case
        when v_inv_patch ? 'channel_meta' and jsonb_typeof(v_inv_patch->'channel_meta') = 'object'
          then coalesce(channel_meta, '{}'::jsonb) || (v_inv_patch->'channel_meta')
        when v_inv_patch ? 'cod_charge_amount' then coalesce(channel_meta, '{}'::jsonb) || jsonb_build_object('cod_charge_amount', coalesce(nullif(v_inv_patch->>'cod_charge_amount', '')::numeric, 0))
        when v_inv_patch ? 'cod_charge' then coalesce(channel_meta, '{}'::jsonb) || jsonb_build_object('cod_charge_amount', coalesce(nullif(v_inv_patch->>'cod_charge', '')::numeric, 0))
        else channel_meta
      end,
      print_charge = case
        when v_inv_patch ? 'print_charge' then coalesce(nullif(v_inv_patch->>'print_charge', '')::numeric, 0)
        else print_charge
      end,
      wrapping_charge = case
        when v_inv_patch ? 'wrapping_charge' then coalesce(nullif(v_inv_patch->>'wrapping_charge', '')::numeric, 0)
        else wrapping_charge
      end,
      collection_source = case
        when v_inv_patch ? 'collection_source' and nullif(trim(v_inv_patch->>'collection_source'), '') is not null
          then (v_inv_patch->>'collection_source')::public.collection_source_type
        else collection_source
      end,
      updated_at = now()
    where id = p_invoice_id;

    v_has_changes := true;
  end if;

  if jsonb_typeof(v_remove_ids) = 'array' and jsonb_array_length(v_remove_ids) > 0 then
    for v_remove_id in
      select (value::text)::bigint
      from jsonb_array_elements(v_remove_ids) as t(value)
      where value is not null and value::text ~ '^[0-9]+$'
    loop
      delete from public.bill_lines
      where id = v_remove_id
        and invoice_id = p_invoice_id
      returning id into v_item_id;

      if v_item_id is not null then
        v_removed_ids := array_append(v_removed_ids, v_item_id);
        v_has_changes := true;
      end if;
    end loop;
  end if;

  if jsonb_typeof(v_items) = 'array' and jsonb_array_length(v_items) > 0 then
    for v_item_elem in select value from jsonb_array_elements(v_items) as t(value) loop
      v_item_id := nullif(v_item_elem->>'id', '')::bigint;

      if v_item_id is not null then
        select * into v_db_item
        from public.bill_lines
        where id = v_item_id
          and invoice_id = p_invoice_id;

        if v_db_item.id is null then
          return jsonb_build_object(
            'success', false,
            'error', format('invoice item %s not found on invoice', v_item_id),
            'code', 'NOT_FOUND'
          );
        end if;

        v_quantity := coalesce(
          case when v_item_elem ? 'quantity' then nullif(v_item_elem->>'quantity', '')::numeric else null end,
          v_db_item.quantity
        );
        v_sell_price := coalesce(
          case when v_item_elem ? 'sell_price_amount' then nullif(v_item_elem->>'sell_price_amount', '')::numeric else null end,
          v_db_item.sell_price_amount
        );
        v_line_discount := coalesce(
          case when v_item_elem ? 'line_discount_amount' then nullif(v_item_elem->>'line_discount_amount', '')::numeric else null end,
          v_db_item.line_discount_amount,
          0
        );

        if v_quantity <= 0 then
          return jsonb_build_object('success', false, 'error', 'quantity must be > 0', 'code', 'VALIDATION_ERROR');
        end if;
        if v_sell_price < 0 then
          return jsonb_build_object('success', false, 'error', 'sell_price_amount must be >= 0', 'code', 'VALIDATION_ERROR');
        end if;

        v_line_total := greatest((v_quantity * v_sell_price) - v_line_discount, 0);

        update public.bill_lines
        set
          quantity = v_quantity,
          sell_price_amount = v_sell_price,
          line_discount_amount = v_line_discount,
          line_total_amount = v_line_total,
          name_snapshot = case
            when v_item_elem ? 'name_snapshot' then coalesce(nullif(trim(v_item_elem->>'name_snapshot'), ''), name_snapshot)
            else name_snapshot
          end,
          updated_at = now()
        where id = v_item_id
        returning * into v_db_item;

        v_has_changes := true;
      elsif not v_dropship_sync then
        v_global_stock_id := nullif(v_item_elem->>'global_stock_id', '')::bigint;
        v_quantity := nullif(v_item_elem->>'quantity', '')::numeric;
        v_sell_price := nullif(v_item_elem->>'sell_price_amount', '')::numeric;
        v_line_discount := coalesce(nullif(v_item_elem->>'line_discount_amount', '')::numeric, 0);

        if v_global_stock_id is null then
          return jsonb_build_object('success', false, 'error', 'new items require global_stock_id', 'code', 'VALIDATION_ERROR');
        end if;
        if v_quantity is null or v_quantity <= 0 then
          return jsonb_build_object('success', false, 'error', 'new items require quantity > 0', 'code', 'VALIDATION_ERROR');
        end if;
        if v_sell_price is null or v_sell_price < 0 then
          return jsonb_build_object('success', false, 'error', 'new items require sell_price_amount >= 0', 'code', 'VALIDATION_ERROR');
        end if;

        select
          gs.parent_tenant_id,
          gs.shipment_item_id,
          gsi.name,
          gsi.barcode,
          gsi.product_code,
          sh.assigned_child_tenant_id,
          p.id
        into
          v_stock_parent,
          v_shipment_item_id,
          v_name_snapshot,
          v_barcode_snapshot,
          v_product_code_snapshot,
          v_assigned_child,
          v_product_id
        from public.global_stocks gs
        left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
        left join public.global_shipments sh on sh.id = gsi.shipment_id
        left join public.products p on p.id = gsi.product_id
        where gs.id = v_global_stock_id;

        if v_stock_parent is null then
          return jsonb_build_object('success', false, 'error', format('stock %s not found', v_global_stock_id), 'code', 'NOT_FOUND');
        end if;

        if v_stock_parent <> v_parent_id then
          return jsonb_build_object(
            'success', false,
            'error', format('stock %s does not belong to invoice parent tenant', v_global_stock_id),
            'code', 'VALIDATION_ERROR'
          );
        end if;

        v_shipment_item_id := coalesce(nullif(v_item_elem->>'shipment_item_id', '')::bigint, v_shipment_item_id);
        v_product_id := coalesce(nullif(v_item_elem->>'product_id', '')::bigint, v_product_id);
        v_name_snapshot := coalesce(nullif(trim(v_item_elem->>'name_snapshot'), ''), v_name_snapshot, 'Item');
        v_barcode_snapshot := coalesce(nullif(trim(v_item_elem->>'barcode_snapshot'), ''), v_barcode_snapshot);
        v_product_code_snapshot := coalesce(nullif(trim(v_item_elem->>'product_code_snapshot'), ''), v_product_code_snapshot);
        v_assigned_child := coalesce(nullif(v_item_elem->>'assigned_child_tenant_id', '')::bigint, v_assigned_child);
        v_line_total := greatest((v_quantity * v_sell_price) - v_line_discount, 0);

        insert into public.bill_lines (
          parent_tenant_id,
          invoice_id,
          global_stock_id,
          shipment_item_id,
          product_id,
          name_snapshot,
          barcode_snapshot,
          product_code_snapshot,
          quantity,
          sell_price_amount,
          line_discount_amount,
          line_total_amount,
          assigned_child_tenant_id
        )
        values (
          v_parent_id,
          p_invoice_id,
          v_global_stock_id,
          v_shipment_item_id,
          v_product_id,
          v_name_snapshot,
          v_barcode_snapshot,
          v_product_code_snapshot,
          v_quantity,
          v_sell_price,
          v_line_discount,
          v_line_total,
          v_assigned_child
        )
        returning * into v_db_item;

        v_has_changes := true;
      end if;
    end loop;
  end if;

  if not v_has_changes then
    return jsonb_build_object('success', false, 'error', 'nothing to update', 'code', 'EMPTY_PAYLOAD');
  end if;

  if v_recompute then
    perform public.recompute_global_invoice_totals(p_invoice_id);
  end if;

  select * into v_invoice from public.bills where id = p_invoice_id;

  if v_dropship_sync then
    if v_invoice.invoice_status in (
      'draft'::public.global_invoice_status,
      'proforma_generated'::public.global_invoice_status
    ) then
      perform public.post_sales_invoice(p_invoice_id);
      select * into v_invoice from public.bills where id = p_invoice_id;
    elsif v_invoice.payment_status not in ('paid', 'partially_paid') then
      update public.bills
      set
        payment_status = 'due',
        due_amount = greatest(coalesce(v_invoice.total_amount, 0) - coalesce(v_invoice.paid_amount, 0), 0),
        updated_at = now()
      where id = p_invoice_id;
      select * into v_invoice from public.bills where id = p_invoice_id;
    end if;
    perform public.recompute_global_invoice_payment_status(p_invoice_id);
    select * into v_invoice from public.bills where id = p_invoice_id;
  end if;

  select coalesce(jsonb_agg(to_jsonb(sii.*) order by sii.id), '[]'::jsonb)
  into v_result_items
  from public.bill_lines sii
  where sii.invoice_id = p_invoice_id;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_no', v_invoice.invoice_no,
    'invoice_type', v_invoice.invoice_type,
    'invoice_status', v_invoice.invoice_status,
    'payment_status', v_invoice.payment_status,
    'invoice', jsonb_build_object(
      'id', v_invoice.id,
      'parent_tenant_id', v_invoice.parent_tenant_id,
      'issued_by_tenant_id', v_invoice.issued_by_tenant_id,
      'invoice_type', v_invoice.invoice_type,
      'invoice_no', v_invoice.invoice_no,
      'invoice_status', v_invoice.invoice_status,
      'payment_status', v_invoice.payment_status,
      'profile_id', v_invoice.profile_id,
      'recipient_profile_id', v_invoice.recipient_profile_id,
      'recipient_name', v_invoice.recipient_name,
      'recipient_phone', v_invoice.recipient_phone,
      'recipient_address', v_invoice.recipient_address,
      'collection_source', v_invoice.collection_source,
      'subtotal_amount', v_invoice.subtotal_amount,
      'discount_amount', v_invoice.discount_amount,
      'shipping_charge', v_invoice.shipping_charge,
      'cod_charge_amount', coalesce((v_invoice.channel_meta->>'cod_charge_amount')::numeric, 0),
      'print_charge', v_invoice.print_charge,
      'wrapping_charge', v_invoice.wrapping_charge,
      'total_amount', v_invoice.total_amount,
      'paid_amount', v_invoice.paid_amount,
      'due_amount', v_invoice.due_amount,
      'note', v_invoice.note,
      'due_date', v_invoice.due_date,
      'invoice_date', v_invoice.invoice_date
    ),
    'items', v_result_items,
    'removed_item_ids', to_jsonb(v_removed_ids)
  );
exception
  when others then
    return jsonb_build_object('success', false, 'error', sqlerrm, 'code', 'VALIDATION_ERROR');
end;
$_$;;


CREATE OR REPLACE FUNCTION "public"."upsert_pbc_backlog_from_item"("p_costing_item_id" bigint) RETURNS "public"."product_based_costing_backlog_items"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_item public.product_based_costing_items%rowtype;
  v_file public.product_based_costing_files%rowtype;
  v_prod record;
  v_confirmed_qty numeric;
  v_open_qty numeric;
  v_backlog_row public.product_based_costing_backlog_items;
  v_tenant_id bigint;
  v_price_gbp numeric;
begin
  select * into v_item
  from public.product_based_costing_items
  where id = p_costing_item_id;

  if v_item.id is null then
    return null;
  end if;

  select * into v_file
  from public.product_based_costing_files
  where id = v_item.product_based_costing_file_id;

  if v_file.id is null then
    raise exception 'costing file % not found', v_item.product_based_costing_file_id;
  end if;

  v_tenant_id := v_file.tenant_id;
  if v_tenant_id is null and v_file.profile_id is not null then
    select tenant_id into v_tenant_id
    from public.profiles
    where id = v_file.profile_id;
  end if;

  if v_tenant_id is not null and not (
    public.can_admin_manage_costing_file(v_tenant_id)
    or public.can_staff_access_costing_file(v_tenant_id)
  ) then
    raise exception 'access denied for tenant %', v_tenant_id;
  end if;

  if v_tenant_id is null or v_file.profile_id is null or v_item.product_id is null then
    return null;
  end if;

  v_confirmed_qty := coalesce(v_item.confirmed_quantity, v_item.quantity, 0);
  v_open_qty := case
    when v_item.assigned_shipment_id is not null then 0
    when coalesce(v_file.status, 'pending') in ('pending', 'offered') then v_confirmed_qty
    else 0
  end;

  if v_confirmed_qty <= 0 or v_open_qty <= 0 then
    delete from public.product_based_costing_backlog_items
    where tenant_id = v_tenant_id
      and profile_id = v_file.profile_id
      and product_id = v_item.product_id;
    return null;
  end if;

  select
    p.name,
    p.image_url,
    p.list_price_amount,
    p.product_weight,
    p.package_weight,
    p.barcode,
    p.product_code,
    p.brand,
    gc.code as list_price_currency_code
  into v_prod
  from public.products p
  left join public.global_currencies gc on gc.id = p.list_price_currency_id
  where p.id = v_item.product_id;

  v_price_gbp := coalesce(
    v_item.price_gbp,
    case
      when v_prod.list_price_currency_code is null or v_prod.list_price_currency_code = 'GBP'
        then v_prod.list_price_amount
      else null
    end
  );

  insert into public.product_based_costing_backlog_items (
    tenant_id,
    profile_id,
    product_id,
    open_quantity,
    name,
    image_url,
    barcode,
    product_code,
    price_gbp,
    product_weight,
    package_weight,
    last_costing_file_id,
    last_costing_item_id,
    updated_at
  )
  values (
    v_tenant_id,
    v_file.profile_id,
    v_item.product_id,
    v_open_qty,
    coalesce(v_item.name, v_prod.name),
    coalesce(v_item.image_url, v_prod.image_url),
    coalesce(v_item.barcode, v_prod.barcode),
    coalesce(v_item.product_code, v_prod.product_code),
    v_price_gbp,
    coalesce(v_item.product_weight::numeric, v_prod.product_weight),
    coalesce(v_item.package_weight::numeric, v_prod.package_weight),
    v_file.id,
    v_item.id,
    now()
  )
  on conflict (tenant_id, profile_id, product_id)
  do update set
    open_quantity = excluded.open_quantity,
    name = excluded.name,
    image_url = excluded.image_url,
    barcode = excluded.barcode,
    product_code = excluded.product_code,
    price_gbp = excluded.price_gbp,
    product_weight = excluded.product_weight,
    package_weight = excluded.package_weight,
    last_costing_file_id = excluded.last_costing_file_id,
    last_costing_item_id = excluded.last_costing_item_id,
    updated_at = now()
  returning * into v_backlog_row;

  return v_backlog_row;
end;
$$;

CREATE OR REPLACE TRIGGER "trg_pbc_files_0_stamp_billing_profile" BEFORE INSERT OR UPDATE OF "customer_group_id" ON "public"."product_based_costing_files" FOR EACH ROW EXECUTE FUNCTION "public"."trg_fn_pbc_files_stamp_billing_profile"();

CREATE OR REPLACE TRIGGER "trg_pbc_files_auto_tenant_id" BEFORE INSERT OR UPDATE OF "profile_id", "tenant_id" ON "public"."product_based_costing_files" FOR EACH ROW EXECUTE FUNCTION "public"."trg_fn_pbc_files_auto_tenant_id"();

CREATE OR REPLACE TRIGGER "trg_pbc_items_auto_backlog" AFTER INSERT OR DELETE OR UPDATE OF "quantity", "confirmed_quantity", "product_id", "price_gbp" ON "public"."product_based_costing_items" FOR EACH ROW EXECUTE FUNCTION "public"."trg_fn_auto_upsert_pbc_backlog"();
