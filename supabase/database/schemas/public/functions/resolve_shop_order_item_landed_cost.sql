CREATE FUNCTION public.resolve_shop_order_item_landed_cost (
  p_global_stock_id        bigint,
  p_cost_price_amount      numeric DEFAULT NULL::numeric,
  p_unit_list_price_amount numeric DEFAULT NULL::numeric
)
  RETURNS numeric
  LANGUAGE sql
  STABLE
  SET search_path TO 'public'
  AS $function$
  select coalesce(
    p_cost_price_amount,
    (
      select coalesce(
        gsi.landed_cost_bdt,
        public.calculate_landed_unit_cost(gs.shipment_item_id)
      )
      from public.global_stocks gs
      join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
      where gs.id = p_global_stock_id
    ),
    p_unit_list_price_amount,
    0::numeric
  );
$function$;

GRANT ALL ON FUNCTION public.resolve_shop_order_item_landed_cost(bigint, numeric, numeric) TO anon;

GRANT ALL ON FUNCTION public.resolve_shop_order_item_landed_cost(bigint, numeric, numeric) TO authenticated;

GRANT ALL ON FUNCTION public.resolve_shop_order_item_landed_cost(bigint, numeric, numeric) TO service_role;