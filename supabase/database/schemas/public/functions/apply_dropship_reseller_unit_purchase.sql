CREATE FUNCTION public.apply_dropship_reseller_unit_purchase (
  p_order_id               bigint,
  p_unit_sell_price_amount numeric
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if p_unit_sell_price_amount is null or p_unit_sell_price_amount < 0 then
    raise exception 'reseller unit purchase cost must be zero or positive';
  end if;

  update public.shop_order_items soi
  set
    unit_sell_price_amount = p_unit_sell_price_amount,
    updated_at = now()
  where soi.order_id = p_order_id;

  if not found then
    raise exception 'order has no line items';
  end if;
end;
$function$;

GRANT ALL ON FUNCTION public.apply_dropship_reseller_unit_purchase(bigint, numeric) TO anon;

GRANT ALL ON FUNCTION public.apply_dropship_reseller_unit_purchase(bigint, numeric) TO authenticated;

GRANT ALL ON FUNCTION public.apply_dropship_reseller_unit_purchase(bigint, numeric) TO service_role;