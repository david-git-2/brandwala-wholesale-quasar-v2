CREATE FUNCTION public.confirm_shop_order (
  p_order_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tenant_id bigint;
  v_is_negotiable boolean;
begin
  select tenant_id, is_negotiable_snapshot into v_tenant_id, v_is_negotiable from public.shop_orders where id = p_order_id;
  
  if v_tenant_id is null then
    raise exception 'order not found';
  end if;

  if not public.is_tenant_staff(v_tenant_id) then
    raise exception 'access denied';
  end if;

  -- Finalize pricing: set final price to staff offer or customer offer
  update public.shop_order_items
  set
    final_price_amount = coalesce(staff_offer_amount, customer_offer_amount, unit_sell_price_amount, unit_list_price_amount),
    final_price_currency_id = coalesce(staff_offer_currency_id, customer_offer_currency_id, unit_sell_price_currency_id, unit_list_price_currency_id)
  where order_id = p_order_id;

  update public.shop_orders
  set
    status = 'confirmed',
    updated_at = now()
  where id = p_order_id;
end;
$function$;

GRANT ALL ON FUNCTION public.confirm_shop_order(bigint) TO anon;

GRANT ALL ON FUNCTION public.confirm_shop_order(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.confirm_shop_order(bigint) TO service_role;