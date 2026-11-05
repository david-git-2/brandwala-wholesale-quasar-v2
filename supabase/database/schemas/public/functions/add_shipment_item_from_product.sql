CREATE FUNCTION public.add_shipment_item_from_product (
  p_shipment_id bigint,
  p_product_id  bigint,
  p_quantity    integer
)
  RETURNS public.shipment_items
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_row public.shipment_items;
  v_tenant_id bigint;
  v_parent bigint;
  v_product record;
  v_quantity integer;
begin
  select tenant_id into v_tenant_id
  from public.shipments
  where id = p_shipment_id;

  if v_tenant_id is null then
    raise exception 'shipment not found';
  end if;

  if not public.can_manage_shipment(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_parent := public.resolve_parent_tenant_id(v_tenant_id);

  v_quantity := coalesce(p_quantity, 0);
  if v_quantity <= 0 then
    raise exception 'quantity must be greater than 0';
  end if;

  select
    p.id,
    p.name,
    p.barcode,
    p.product_code,
    p.image_url,
    p.product_weight,
    p.package_weight,
    coalesce(p.list_price_amount, 0) as price_gbp
  into v_product
  from public.products p
  where p.id = p_product_id
    and p.parent_tenant_id = v_parent;

  if v_product.id is null then
    raise exception 'product not found';
  end if;

  insert into public.shipment_items (
    shipment_id,
    name,
    quantity,
    barcode,
    product_code,
    product_id,
    image_url,
    product_weight,
    package_weight,
    price_gbp
  )
  values (
    p_shipment_id,
    v_product.name,
    v_quantity,
    v_product.barcode,
    v_product.product_code,
    v_product.id,
    v_product.image_url,
    v_product.product_weight,
    v_product.package_weight,
    v_product.price_gbp
  )
  returning * into v_row;

  return v_row;
end;
$function$;

GRANT ALL ON FUNCTION public.add_shipment_item_from_product(bigint, bigint, integer) TO anon;

GRANT ALL ON FUNCTION public.add_shipment_item_from_product(bigint, bigint, integer) TO authenticated;

GRANT ALL ON FUNCTION public.add_shipment_item_from_product(bigint, bigint, integer) TO service_role;