CREATE FUNCTION public.compute_dropship_order_reseller_purchase (
  p_order_id bigint
)
  RETURNS TABLE (
    reseller_unit_purchase_cost numeric,
    reseller_purchase_cost      numeric,
    order_item_quantity         integer
  )
  LANGUAGE sql
  STABLE
  SET search_path TO 'public'
  AS $function$
  select
    case
      when coalesce(sum(soi.quantity), 0) > 0 then
        coalesce(sum(coalesce(soi.unit_sell_price_amount, 0) * soi.quantity), 0) / sum(soi.quantity)
      else 0::numeric
    end,
    coalesce(sum(coalesce(soi.unit_sell_price_amount, 0) * soi.quantity), 0),
    coalesce(sum(soi.quantity), 0)::integer
  from public.shop_order_items soi
  inner join public.shop_orders o on o.id = soi.order_id
  where soi.order_id = p_order_id;
$function$;

GRANT ALL ON FUNCTION public.compute_dropship_order_reseller_purchase(bigint) TO anon;

GRANT ALL ON FUNCTION public.compute_dropship_order_reseller_purchase(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.compute_dropship_order_reseller_purchase(bigint) TO service_role;