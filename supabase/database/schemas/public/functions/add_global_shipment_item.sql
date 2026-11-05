CREATE FUNCTION public.add_global_shipment_item (
  p_shipment_id bigint,
  p_item        jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.add_global_shipment_item(bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.add_global_shipment_item(bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.add_global_shipment_item(bigint, jsonb) TO service_role;