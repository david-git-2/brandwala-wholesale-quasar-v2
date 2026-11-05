CREATE FUNCTION public.list_allocations_for_shop_pick (
  p_tenant_id bigint,
  p_shop_id   bigint
)
  RETURNS TABLE (
    allocation_id                  bigint,
    stock_id                       bigint,
    product_id                     bigint,
    product_name                   text,
    product_image_url              text,
    product_barcode                text,
    product_code                   text,
    product_brand                  text,
    product_category               text,
    allocated_quantity             integer,
    minimum_sell_price_amount      numeric,
    minimum_sell_price_currency_id bigint,
    unit_cost_amount               numeric,
    shipment_item_id               bigint,
    shipment_id                    bigint
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  -- Caller must be member of this tenant
  if not exists (
    select 1 from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'not allowed';
  end if;

  return query
  select
    gsa.id as allocation_id,
    gsa.stock_id,
    gsi.product_id,
    p.name as product_name,
    p.image_url as product_image_url,
    p.barcode as product_barcode,
    p.product_code as product_code,
    p.brand as product_brand,
    p.category as product_category,
    gsa.quantity as allocated_quantity,
    coalesce(
      public.calculate_landed_unit_cost(gs.shipment_item_id),
      gsi.purchase_price * coalesce(gship.product_conversion_rate, 1.0),
      0.00
    )::numeric as minimum_sell_price_amount,
    (select default_currency_id from public.shops where id = p_shop_id) as minimum_sell_price_currency_id,
    coalesce(
      public.calculate_landed_unit_cost(gs.shipment_item_id),
      gsi.purchase_price * coalesce(gship.product_conversion_rate, 1.0),
      0.00
    )::numeric as unit_cost_amount,
    gs.shipment_item_id,
    gsi.shipment_id
  from public.global_stock_allocations gsa
  join public.global_stocks gs on gs.id = gsa.stock_id
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  join public.global_shipments gship on gship.id = gsi.shipment_id
  join public.products p on p.id = gsi.product_id
  where gsa.child_tenant_id = p_tenant_id
    and not exists (
      select 1 from public.shop_product_listings spl
      where spl.shop_id = p_shop_id
        and spl.global_stock_allocation_id = gsa.id
    )
  order by p.name asc;
end;
$function$;

CREATE FUNCTION public.list_allocations_for_shop_pick (
  p_shop_id bigint,
  p_search  text   DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select jsonb_build_object('data', '[]'::jsonb, 'total', 0);
$function$;

GRANT ALL ON FUNCTION public.list_allocations_for_shop_pick(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.list_allocations_for_shop_pick(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_allocations_for_shop_pick(bigint, bigint) TO service_role;

GRANT ALL ON FUNCTION public.list_allocations_for_shop_pick(bigint, text) TO anon;

GRANT ALL ON FUNCTION public.list_allocations_for_shop_pick(bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.list_allocations_for_shop_pick(bigint, text) TO service_role;