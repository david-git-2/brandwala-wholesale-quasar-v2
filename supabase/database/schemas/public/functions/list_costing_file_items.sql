CREATE FUNCTION public.list_costing_file_items (
  p_costing_file_id bigint
)
  RETURNS TABLE (
    id                   bigint,
    costing_file_id      bigint,
    name                 text,
    image_url            text,
    website_url          text,
    quantity             integer,
    product_weight       integer,
    package_weight       integer,
    price_in_web_gbp     numeric,
    delivery_price_gbp   numeric,
    auxiliary_price_gbp  numeric,
    item_price_gbp       numeric,
    cargo_rate           numeric,
    costing_price_gbp    numeric,
    costing_price_bdt    integer,
    offer_price_bdt      integer,
    customer_profit_rate numeric,
    status               public.costing_file_item_status,
    created_by_email     text,
    assigned_shipment_id bigint,
    created_at           timestamp with time zone,
    updated_at           timestamp with time zone
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select
    cfi.id,
    cfi.costing_file_id,
    cfi.name,
    cfi.image_url,
    cfi.website_url,
    cfi.quantity,
    cfi.product_weight,
    cfi.package_weight,
    cfi.price_in_web_gbp,
    cfi.delivery_price_gbp,
    cfi.auxiliary_price_gbp,
    cfi.item_price_gbp,
    cfi.cargo_rate,
    cfi.costing_price_gbp,
    cfi.costing_price_bdt,
    cfi.offer_price_bdt,
    cfi.customer_profit_rate,
    cfi.status,
    cfi.created_by_email,
    cfi.assigned_shipment_id,
    cfi.created_at,
    cfi.updated_at
  from public.costing_file_items cfi
  where cfi.costing_file_id = p_costing_file_id
    and public.can_view_costing_file(cfi.costing_file_id)
  order by cfi.id asc;
$function$;

GRANT ALL ON FUNCTION public.list_costing_file_items(bigint) TO anon;

GRANT ALL ON FUNCTION public.list_costing_file_items(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_costing_file_items(bigint) TO service_role;