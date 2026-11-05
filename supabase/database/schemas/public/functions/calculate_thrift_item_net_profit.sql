CREATE FUNCTION public.calculate_thrift_item_net_profit()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_landed numeric(12, 2);
begin
  if tg_op = 'INSERT' or new.landed_unit_cost_at_sale is null or new.landed_unit_cost_at_sale = 0 then
    v_landed := coalesce(public.compute_thrift_landed_unit_cost(new.stock_id), 0.00);
    new.landed_unit_cost_at_sale := v_landed;
  else
    v_landed := new.landed_unit_cost_at_sale;
  end if;

  new.net_profit := (new.sold_price - v_landed) * new.quantity
                    - new.platform_fees
                    - new.shipping_cost_paid_by_shop;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.calculate_thrift_item_net_profit() TO anon;

GRANT ALL ON FUNCTION public.calculate_thrift_item_net_profit() TO authenticated;

GRANT ALL ON FUNCTION public.calculate_thrift_item_net_profit() TO service_role;