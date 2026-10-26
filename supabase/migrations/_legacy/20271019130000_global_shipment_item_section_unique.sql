-- Per-section line identity: same catalog product may appear in different sections, not twice in one section.

create or replace function public.global_shipment_item_conflicts_in_section(
  p_shipment_id bigint,
  p_section_id bigint,
  p_product_id bigint,
  p_barcode text,
  p_product_code text,
  p_exclude_item_id bigint default null
) returns boolean
language sql
stable
set search_path to public
as $$
  select exists (
    select 1
    from public.global_shipment_items i
    where i.shipment_id = p_shipment_id
      and i.section_id is not distinct from p_section_id
      and (p_exclude_item_id is null or i.id <> p_exclude_item_id)
      and (
        (p_product_id is not null and i.product_id = p_product_id)
        or (
          p_barcode is not null
          and btrim(p_barcode) <> ''
          and i.barcode is not distinct from p_barcode
        )
        or (
          p_product_code is not null
          and btrim(p_product_code) <> ''
          and i.product_code is not distinct from p_product_code
        )
      )
  );
$$;

create or replace function public.add_global_shipment_item(
  p_shipment_id bigint,
  p_item jsonb
) returns jsonb
language plpgsql
security definer
set search_path to public
as $$
declare
  v_parent_tenant_id bigint;
  v_next_sort integer;
  v_section_id bigint;
  v_product_id bigint;
  v_row public.global_shipment_items;
  v_outcome public.global_shipment_item_outcomes;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  v_section_id := nullif((p_item->>'section_id'), '')::bigint;
  v_product_id := nullif((p_item->>'product_id'), '')::bigint;

  if public.global_shipment_item_conflicts_in_section(
    p_shipment_id,
    v_section_id,
    v_product_id,
    p_item->>'barcode',
    p_item->>'product_code',
    null
  ) then
    raise exception 'This product is already on this shipment section';
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
    nullif((p_item->>'vendor_id'), '')::bigint,
    coalesce(p_item->>'name', 'Unnamed Item'),
    greatest(1, coalesce((p_item->>'ordered_quantity')::integer, 1)),
    p_item->>'image_url',
    coalesce((p_item->>'add_method')::public.global_shipment_item_add_method, 'manual'::public.global_shipment_item_add_method),
    greatest(0, coalesce((p_item->>'purchase_price')::numeric, 0)),
    greatest(0, coalesce((p_item->>'product_weight')::numeric, 0)),
    greatest(0, coalesce((p_item->>'package_weight')::numeric, 0)),
    p_item->>'barcode',
    p_item->>'product_code',
    nullif((p_item->>'source_child_tenant_id'), '')::bigint,
    p_item->>'source_type',
    nullif((p_item->>'source_id'), '')::bigint,
    coalesce((p_item->>'sort_order')::integer, v_next_sort)
  )
  returning * into v_row;

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
    v_row.id,
    v_row.ordered_quantity,
    'sellable'::public.global_shipment_outcome_kind,
    'ordered'::public.global_shipment_outcome_reason,
    greatest(0, coalesce(v_row.purchase_price, 0)),
    v_row.landed_cost_bdt
  )
  returning * into v_outcome;

  return jsonb_build_object(
    'item', to_jsonb(v_row),
    'ordered_outcome', to_jsonb(v_outcome)
  );
end;
$$;

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
