CREATE FUNCTION public.get_pending_order_qty (
  p_allocation_id bigint
)
  RETURNS integer
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select coalesce(sum(oi.quantity)::integer, 0)
  from public.shop_order_items oi
  join public.shop_orders o on o.id = oi.order_id
  where oi.global_stock_allocation_id = p_allocation_id
    and o.status not in ('cancelled', 'fulfilled');
$function$;

GRANT ALL ON FUNCTION public.get_pending_order_qty(bigint) TO anon;

GRANT ALL ON FUNCTION public.get_pending_order_qty(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_pending_order_qty(bigint) TO service_role;