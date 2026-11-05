CREATE FUNCTION public.global_stock_hold_qty (
  p_global_stock_id bigint
)
  RETURNS numeric
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select
    coalesce((
      select sum(gii.quantity - coalesce(gii.return_quantity, 0))
      from public.global_invoice_items gii
      join public.bills gi on gi.id = gii.invoice_id
      where gii.global_stock_id = p_global_stock_id
        and gi.invoice_status = 'draft'::public.global_invoice_status
    ), 0)
    + coalesce((
      select sum(sci.quantity)
      from public.shop_cart_items sci
      where sci.global_stock_id = p_global_stock_id
    ), 0);
$function$;

GRANT ALL ON FUNCTION public.global_stock_hold_qty(bigint) TO anon;

GRANT ALL ON FUNCTION public.global_stock_hold_qty(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.global_stock_hold_qty(bigint) TO service_role;