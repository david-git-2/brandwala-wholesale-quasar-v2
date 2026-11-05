CREATE FUNCTION public.list_shop_product_listings (
  p_shop_id bigint
)
  RETURNS TABLE (
    id                             bigint,
    tenant_id                      bigint,
    shop_id                        bigint,
    global_stock_allocation_id     bigint,
    global_stock_id                bigint,
    product_id                     bigint,
    sell_price_amount              numeric,
    sell_price_currency_id         bigint,
    minimum_sell_price_amount      numeric,
    minimum_sell_price_currency_id bigint,
    show_quantity                  boolean,
    display_quantity_override      integer,
    is_active                      boolean,
    created_at                     timestamp with time zone,
    updated_at                     timestamp with time zone,
    product_name                   text,
    product_image_url              text,
    product_barcode                text,
    product_code                   text,
    product_brand                  text,
    product_category               text,
    allocated_quantity             integer,
    available_to_sell              integer,
    unit_cost_amount               numeric,
    shipment_item_id               bigint,
    shipment_id                    bigint
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tenant_id bigint;
begin
  select s.tenant_id into v_tenant_id
  from public.shops s
  where s.id = p_shop_id
    and s.deleted_at is null;
  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.has_active_tenant_membership(v_tenant_id)
     and not public.has_active_tenant_membership(public.resolve_parent_tenant_id(v_tenant_id))
     and not public.is_superadmin() then
    raise exception 'not allowed';
  end if;

  return query
  select
    l.id,
    l.tenant_id,
    l.shop_id,
    l.global_stock_allocation_id,
    coalesce(l.global_stock_id, gs.id) as global_stock_id,
    l.product_id,
    l.sell_price_amount,
    l.sell_price_currency_id,
    l.minimum_sell_price_amount,
    l.minimum_sell_price_currency_id,
    l.show_quantity,
    l.display_quantity_override,
    l.is_active,
    l.created_at,
    l.updated_at,
    gsi.name as product_name,
    gsi.image_url as product_image_url,
    gsi.barcode as product_barcode,
    gsi.product_code as product_code,
    p.brand as product_brand,
    p.category as product_category,
    gs.quantity::integer as allocated_quantity,
    greatest(0, floor(public.global_stock_atp_qty(coalesce(l.global_stock_id, gs.id))))::integer as available_to_sell,
    coalesce(public.calculate_landed_unit_cost(gs.shipment_item_id), 0.00)::numeric as unit_cost_amount,
    gs.shipment_item_id as shipment_item_id,
    gsi.shipment_id as shipment_id
  from public.shop_product_listings l
  left join public.products p on p.id = l.product_id
  left join public.global_stocks gs on gs.id = l.global_stock_id
  left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  where l.shop_id = p_shop_id
  order by gsi.name asc;
end;
$function$;

GRANT ALL ON FUNCTION public.list_shop_product_listings(bigint) TO anon;

GRANT ALL ON FUNCTION public.list_shop_product_listings(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_shop_product_listings(bigint) TO service_role;