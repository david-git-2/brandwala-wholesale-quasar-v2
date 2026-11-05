CREATE FUNCTION public.global_shipment_item_conflicts_in_section (
  p_shipment_id     bigint,
  p_section_id      bigint,
  p_product_id      bigint,
  p_barcode         text,
  p_product_code    text,
  p_exclude_item_id bigint DEFAULT NULL::bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.global_shipment_item_conflicts_in_section(bigint, bigint, bigint, text, text, bigint) TO anon;

GRANT ALL ON FUNCTION public.global_shipment_item_conflicts_in_section(bigint, bigint, bigint, text, text, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.global_shipment_item_conflicts_in_section(bigint, bigint, bigint, text, text, bigint) TO service_role;