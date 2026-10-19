-- Bulk add: skip lines already in the target section; insert the rest.

create or replace function public.bulk_add_global_shipment_items(
  p_shipment_id bigint,
  p_items jsonb
) returns setof public.global_shipment_items
language plpgsql
security definer
set search_path to public
as $$
declare
  v_item jsonb;
  v_next_sort integer;
  v_parent_tenant_id bigint;
  v_section_id bigint;
  v_product_id bigint;
  v_new_item public.global_shipment_items;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  select s.parent_tenant_id
  into v_parent_tenant_id
  from public.global_shipments s
  where s.id = p_shipment_id;

  if v_parent_tenant_id is null then
    raise exception 'Shipment not found';
  end if;

  select coalesce(max(sort_order), 0) + 10
  into v_next_sort
  from public.global_shipment_items
  where shipment_id = p_shipment_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_section_id := nullif((v_item->>'section_id'), '')::bigint;
    v_product_id := nullif((v_item->>'product_id'), '')::bigint;

    if public.global_shipment_item_conflicts_in_section(
      p_shipment_id,
      v_section_id,
      v_product_id,
      v_item->>'barcode',
      v_item->>'product_code',
      null
    ) then
      continue;
    end if;

    insert into public.global_shipment_items (
      shipment_id,
      section_id,
      product_id,
      vendor_id,
      name,
      ordered_quantity,
      image_url,
      add_method,
      purchase_price,
      product_weight,
      package_weight,
      barcode,
      product_code,
      source_child_tenant_id,
      source_type,
      source_id,
      sort_order
    )
    values (
      p_shipment_id,
      v_section_id,
      v_product_id,
      nullif((v_item->>'vendor_id'), '')::bigint,
      coalesce(v_item->>'name', 'Unnamed Item'),
      greatest(1, coalesce((v_item->>'ordered_quantity')::integer, 1)),
      v_item->>'image_url',
      coalesce((v_item->>'add_method')::public.global_shipment_item_add_method, 'manual'::public.global_shipment_item_add_method),
      greatest(0, coalesce((v_item->>'purchase_price')::numeric, 0)),
      greatest(0, coalesce((v_item->>'product_weight')::numeric, 0)),
      greatest(0, coalesce((v_item->>'package_weight')::numeric, 0)),
      v_item->>'barcode',
      v_item->>'product_code',
      nullif((v_item->>'source_child_tenant_id'), '')::bigint,
      v_item->>'source_type',
      nullif((v_item->>'source_id'), '')::bigint,
      coalesce((v_item->>'sort_order')::integer, v_next_sort)
    )
    returning * into v_new_item;

    insert into public.global_shipment_item_outcomes (
      parent_tenant_id,
      shipment_item_id,
      quantity,
      kind,
      reason,
      purchase_price,
      cost
    )
    values (
      v_parent_tenant_id,
      v_new_item.id,
      v_new_item.ordered_quantity,
      'sellable'::public.global_shipment_outcome_kind,
      'ordered'::public.global_shipment_outcome_reason,
      greatest(0, coalesce(v_new_item.purchase_price, 0)),
      v_new_item.landed_cost_bdt
    );

    v_next_sort := v_next_sort + 10;
  end loop;

  return query
  select *
  from public.global_shipment_items
  where shipment_id = p_shipment_id
  order by sort_order asc, id asc;
end;
$$;
