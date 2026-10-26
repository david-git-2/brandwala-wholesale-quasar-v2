-- Return close: if pick still points at sellable stock, stamp pick only (no held→sellable move).

create or replace function public.close_preorder_demand_document(
  p_tenant_id bigint,
  p_document_type text,
  p_document_id bigint,
  p_close_action text
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_close_action text := lower(trim(coalesce(p_close_action, '')));
  v_operating_tenant_id bigint;
  v_billing_profile_id bigint;
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
      o.billing_profile_id,
      o.global_invoice_id,
      public.normalize_shop_order_procurement_status(o.status)
    into v_operating_tenant_id, v_billing_profile_id, v_global_invoice_id, v_doc_status
    from public.shop_orders o
    where o.id = p_document_id
      and o.shop_type_snapshot = 'vendor_catalog';

    if v_operating_tenant_id is null then
      raise exception 'shop order not found or not vendor_catalog';
    end if;
  elsif v_doc_type = 'pbc_costing_file' then
    select
      f.tenant_id,
      f.billing_profile_id,
      f.invoice_id,
      public.normalize_pbc_procurement_status(f.status)
    into v_operating_tenant_id, v_billing_profile_id, v_pbc_invoice_id, v_doc_status
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

  if v_billing_profile_id is null and v_close_action in ('take', 'condition') then
    raise exception 'billing_profile_id is required on document';
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
        'billing_profile_id', v_billing_profile_id,
        'channel_meta', jsonb_build_object('delivery_kind', v_delivery_kind)
      ),
      'items', v_items,
      'issue', true
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
$$;
