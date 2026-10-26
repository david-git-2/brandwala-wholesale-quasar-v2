-- Single round-trip line update: item patch, ordered outcome sync, landed-cost stamp, full item list for cache.

create or replace function public.update_global_shipment_item(
  p_item_id bigint,
  p_patch jsonb
) returns jsonb
language plpgsql
security definer
set search_path to public
as $$
declare
  v_item public.global_shipment_items;
  v_ship public.global_shipments;
  v_outcome public.global_shipment_item_outcomes;
  v_items jsonb;
  v_sync_outcome boolean := false;
begin
  if p_item_id is null then
    raise exception 'item_id is required';
  end if;
  if p_patch is null or jsonb_typeof(p_patch) <> 'object' then
    raise exception 'patch object is required';
  end if;

  select i.* into v_item
  from public.global_shipment_items i
  where i.id = p_item_id;

  if not found then
    raise exception 'shipment item not found';
  end if;

  select * into v_ship
  from public.global_shipments
  where id = v_item.shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  if public.global_shipment_costs_are_locked(v_ship) then
    raise exception 'shipment costs are locked';
  end if;

  v_sync_outcome := (
    p_patch ? 'ordered_quantity'
    or p_patch ? 'purchase_price'
    or p_patch ? 'landed_cost_bdt'
  );

  perform set_config('app.skip_item_landed_restamp', '1', true);

  update public.global_shipment_items
  set
    section_id = case
      when p_patch ? 'section_id' then nullif((p_patch->>'section_id'), '')::bigint
      else section_id
    end,
    vendor_id = case
      when p_patch ? 'vendor_id' then nullif((p_patch->>'vendor_id'), '')::bigint
      else vendor_id
    end,
    ordered_quantity = case
      when p_patch ? 'ordered_quantity' and (p_patch->>'ordered_quantity') is not null
        then greatest(1, (p_patch->>'ordered_quantity')::integer)
      else ordered_quantity
    end,
    purchase_price = case
      when p_patch ? 'purchase_price' and (p_patch->>'purchase_price') is not null
        then greatest(0, (p_patch->>'purchase_price')::numeric)
      else purchase_price
    end,
    product_weight = case
      when p_patch ? 'product_weight' and (p_patch->>'product_weight') is not null
        then greatest(0, (p_patch->>'product_weight')::numeric)
      else product_weight
    end,
    package_weight = case
      when p_patch ? 'package_weight' and (p_patch->>'package_weight') is not null
        then greatest(0, (p_patch->>'package_weight')::numeric)
      else package_weight
    end,
    landed_cost_bdt = case
      when p_patch ? 'landed_cost_bdt' then nullif((p_patch->>'landed_cost_bdt'), '')::numeric
      else landed_cost_bdt
    end,
    barcode = case
      when p_patch ? 'barcode' then p_patch->>'barcode'
      else barcode
    end,
    product_code = case
      when p_patch ? 'product_code' then p_patch->>'product_code'
      else product_code
    end,
    name = case
      when p_patch ? 'name' and (p_patch->>'name') is not null then p_patch->>'name'
      else name
    end,
    image_url = case
      when p_patch ? 'image_url' then p_patch->>'image_url'
      else image_url
    end,
    updated_at = now()
  where id = p_item_id and shipment_id = v_item.shipment_id
  returning * into v_item;

  if v_sync_outcome then
    update public.global_shipment_item_outcomes o
    set
      quantity = case
        when p_patch ? 'ordered_quantity' and (p_patch->>'ordered_quantity') is not null
          then greatest(1, (p_patch->>'ordered_quantity')::integer)
        else o.quantity
      end,
      purchase_price = case
        when p_patch ? 'purchase_price' and (p_patch->>'purchase_price') is not null
          then greatest(0, (p_patch->>'purchase_price')::numeric)
        else o.purchase_price
      end,
      cost = case
        when p_patch ? 'landed_cost_bdt' then nullif((p_patch->>'landed_cost_bdt'), '')::numeric
        else o.cost
      end,
      updated_at = now()
    where o.shipment_item_id = p_item_id
      and o.reason = 'ordered'::public.global_shipment_outcome_reason
    returning * into v_outcome;
  end if;

  perform set_config('app.skip_item_landed_restamp', '0', true);

  if exists (select 1 from public.global_shipment_items where shipment_id = v_item.shipment_id) then
    perform public.stamp_global_shipment_landed_costs(v_item.shipment_id);
  end if;

  select coalesce(jsonb_agg(to_jsonb(i) order by i.sort_order asc, i.id asc), '[]'::jsonb)
  into v_items
  from public.global_shipment_items i
  where i.shipment_id = v_item.shipment_id;

  return jsonb_build_object(
    'items', v_items,
    'ordered_outcome', case when v_outcome.id is not null then to_jsonb(v_outcome) else null end
  );
end;
$$;

grant execute on function public.update_global_shipment_item(bigint, jsonb) to authenticated, service_role;
