CREATE FUNCTION public.add_shipment_item_manual (
  p_shipment_id       bigint,
  p_name              text    DEFAULT NULL::text,
  p_quantity          integer DEFAULT NULL::integer,
  p_barcode           text    DEFAULT NULL::text,
  p_product_code      text    DEFAULT NULL::text,
  p_product_id        bigint  DEFAULT NULL::bigint,
  p_image_url         text    DEFAULT NULL::text,
  p_product_weight    numeric DEFAULT NULL::numeric,
  p_package_weight    numeric DEFAULT NULL::numeric,
  p_price_gbp         numeric DEFAULT NULL::numeric,
  p_received_quantity integer DEFAULT NULL::integer,
  p_damaged_quantity  integer DEFAULT NULL::integer,
  p_stolen_quantity   integer DEFAULT NULL::integer
)
  RETURNS public.shipment_items
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_row public.shipment_items;
  v_tenant_id bigint;
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
    price_gbp,
    received_quantity,
    damaged_quantity,
    stolen_quantity
  )
  values (
    p_shipment_id,
    nullif(trim(coalesce(p_name, '')), ''),
    greatest(coalesce(p_quantity, 0), 0),
    nullif(trim(coalesce(p_barcode, '')), ''),
    nullif(trim(coalesce(p_product_code, '')), ''),
    p_product_id,
    nullif(trim(coalesce(p_image_url, '')), ''),
    p_product_weight,
    p_package_weight,
    p_price_gbp,
    greatest(coalesce(p_received_quantity, 0), 0),
    greatest(coalesce(p_damaged_quantity, 0), 0),
    greatest(coalesce(p_stolen_quantity, 0), 0)
  )
  returning * into v_row;

  return v_row;
end;
$function$;

CREATE FUNCTION public.add_shipment_item_manual (
  p_shipment_id      bigint,
  p_name             text    DEFAULT NULL::text,
  p_quantity         integer DEFAULT NULL::integer,
  p_barcode          text    DEFAULT NULL::text,
  p_product_code     text    DEFAULT NULL::text,
  p_product_id       bigint  DEFAULT NULL::bigint,
  p_image_url        text    DEFAULT NULL::text,
  p_product_weight   numeric DEFAULT NULL::numeric,
  p_package_weight   numeric DEFAULT NULL::numeric,
  p_price_gbp        numeric DEFAULT NULL::numeric,
  p_receiving_splits jsonb   DEFAULT NULL::jsonb,
  p_cost_bdt         numeric DEFAULT NULL::numeric
)
  RETURNS public.shipment_items
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_row public.shipment_items;
  v_tenant_id bigint;
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
    price_gbp,
    receiving_splits,
    cost_bdt
  )
  values (
    p_shipment_id,
    nullif(trim(coalesce(p_name, '')), ''),
    greatest(coalesce(p_quantity, 0), 0),
    nullif(trim(coalesce(p_barcode, '')), ''),
    nullif(trim(coalesce(p_product_code, '')), ''),
    p_product_id,
    nullif(trim(coalesce(p_image_url, '')), ''),
    p_product_weight,
    p_package_weight,
    p_price_gbp,
    p_receiving_splits,
    p_cost_bdt
  )
  returning * into v_row;

  return v_row;
end;
$function$;

GRANT ALL ON FUNCTION public.add_shipment_item_manual(bigint, text, integer, text, text, bigint, text, numeric, numeric, numeric, integer, integer, integer) TO anon;

GRANT ALL ON FUNCTION public.add_shipment_item_manual(bigint, text, integer, text, text, bigint, text, numeric, numeric, numeric, integer, integer, integer) TO authenticated;

GRANT ALL ON FUNCTION public.add_shipment_item_manual(bigint, text, integer, text, text, bigint, text, numeric, numeric, numeric, integer, integer, integer) TO service_role;

GRANT ALL ON FUNCTION public.add_shipment_item_manual(bigint, text, integer, text, text, bigint, text, numeric, numeric, numeric, jsonb, numeric) TO anon;

GRANT ALL ON FUNCTION public.add_shipment_item_manual(bigint, text, integer, text, text, bigint, text, numeric, numeric, numeric, jsonb, numeric) TO authenticated;

GRANT ALL ON FUNCTION public.add_shipment_item_manual(bigint, text, integer, text, text, bigint, text, numeric, numeric, numeric, jsonb, numeric) TO service_role;