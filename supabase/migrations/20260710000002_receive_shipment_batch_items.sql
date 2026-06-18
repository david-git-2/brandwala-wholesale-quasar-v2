-- Batch shipment item receive updates + always set status to Added to Inventory
begin;

drop function if exists public.receive_shipment_to_global_stock(bigint);

create or replace function public.receive_shipment_to_global_stock(
  p_shipment_id bigint,
  p_items jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shipment public.shipments;
  v_item record;
  v_payload jsonb;
  v_stock_id bigint;
  v_cost numeric(12,2);
  v_split jsonb;
  v_split_type text;
  v_split_qty integer;
  v_status public.global_stock_status;
  v_created_count integer := 0;
  v_parent_tenant_id bigint;
begin
  select * into v_shipment
  from public.shipments
  where id = p_shipment_id;

  if v_shipment.id is null then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(public.resolve_parent_tenant_id(v_shipment.tenant_id)) then
    raise exception 'not allowed';
  end if;

  if v_shipment.inventory_added is true then
    raise exception 'shipment already received to stock';
  end if;

  if p_items is not null and jsonb_typeof(p_items) = 'array' then
    for v_payload in select value from jsonb_array_elements(p_items)
    loop
      update public.shipment_items
      set
        receiving_splits = coalesce(v_payload->'receiving_splits', receiving_splits),
        cost_bdt = coalesce(nullif(v_payload->>'cost_bdt', '')::numeric, cost_bdt),
        inspected = true
      where id = (v_payload->>'id')::bigint
        and shipment_id = p_shipment_id;

      if not found then
        raise exception 'shipment item % not found on shipment %', v_payload->>'id', p_shipment_id;
      end if;
    end loop;
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_shipment.tenant_id);

  for v_item in
    select *
    from public.shipment_items
    where shipment_id = p_shipment_id
  loop
    v_cost := coalesce(v_item.cost_bdt, 0);

    insert into public.global_stocks (
      tenant_id,
      parent_tenant_id,
      name,
      cost,
      shipment_id,
      shipment_item_id,
      image_url,
      product_code,
      barcode,
      product_id,
      shipment_type,
      price_currency,
      source_module,
      source_type,
      source_id
    )
    values (
      v_parent_tenant_id,
      v_parent_tenant_id,
      coalesce(nullif(trim(v_item.name), ''), 'Unnamed item'),
      v_cost,
      p_shipment_id,
      v_item.id,
      v_item.image_url,
      v_item.product_code,
      v_item.barcode,
      v_item.product_id,
      coalesce(v_shipment.shipment_type, 'international'),
      case when coalesce(v_shipment.shipment_type, 'international') = 'international' then 'GBP' else 'BDT' end,
      'wholesale',
      'shipment',
      v_item.id
    )
    returning id into v_stock_id;

    if v_item.receiving_splits is not null and jsonb_typeof(v_item.receiving_splits) = 'array' then
      for v_split in select value from jsonb_array_elements(v_item.receiving_splits)
      loop
        v_split_type := lower(trim(coalesce(v_split->>'type', 'standard')));
        v_split_qty := greatest(coalesce((v_split->>'qty')::integer, 0), 0);
        if v_split_qty = 0 then
          continue;
        end if;

        v_status := case v_split_type
          when 'boxless' then 'box_less'::public.global_stock_status
          when 'box_less' then 'box_less'::public.global_stock_status
          when 'box_damage' then 'box_damage'::public.global_stock_status
          when 'expired' then 'expired'::public.global_stock_status
          when 'stolen' then 'stolen'::public.global_stock_status
          when 'reserved' then 'reserved'::public.global_stock_status
          else 'excellent'::public.global_stock_status
        end;

        insert into public.global_stock_quantities (stock_id, status, quantity)
        values (v_stock_id, v_status, v_split_qty)
        on conflict (stock_id, status)
        do update set quantity = global_stock_quantities.quantity + excluded.quantity;
      end loop;
    elsif v_item.receiving_splits is not null and jsonb_typeof(v_item.receiving_splits) = 'object' then
      for v_split_type, v_split in
        select key, value from jsonb_each(v_item.receiving_splits)
      loop
        v_split_qty := greatest(coalesce((v_split->>'qty')::integer, 0), 0);
        if v_split_qty = 0 then
          continue;
        end if;

        v_status := case lower(trim(v_split_type))
          when 'boxless' then 'box_less'::public.global_stock_status
          when 'box_less' then 'box_less'::public.global_stock_status
          when 'box_damage' then 'box_damage'::public.global_stock_status
          when 'expired' then 'expired'::public.global_stock_status
          when 'stolen' then 'stolen'::public.global_stock_status
          when 'reserved' then 'reserved'::public.global_stock_status
          else 'excellent'::public.global_stock_status
        end;

        insert into public.global_stock_quantities (stock_id, status, quantity)
        values (v_stock_id, v_status, v_split_qty)
        on conflict (stock_id, status)
        do update set quantity = global_stock_quantities.quantity + excluded.quantity;
      end loop;
    else
      insert into public.global_stock_quantities (stock_id, status, quantity)
      values (v_stock_id, 'excellent', greatest(coalesce(v_item.quantity, 0), 0))
      on conflict (stock_id, status)
      do update set quantity = global_stock_quantities.quantity + excluded.quantity;
    end if;

    v_created_count := v_created_count + 1;
  end loop;

  update public.shipments
  set inventory_added = true,
      status = 'Added to Inventory'
  where id = p_shipment_id
  returning * into v_shipment;

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'stocks_created', v_created_count,
    'shipment', to_jsonb(v_shipment)
  );
end;
$$;

grant execute on function public.receive_shipment_to_global_stock(bigint, jsonb) to authenticated;

commit;
