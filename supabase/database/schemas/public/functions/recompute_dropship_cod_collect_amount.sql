CREATE FUNCTION public.recompute_dropship_cod_collect_amount (
  p_order_id bigint
)
  RETURNS numeric
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders%rowtype;
  v_items_resell_delivered numeric := 0;
  v_recipient_charge_total numeric := 0;
  v_cod_collect_amount numeric;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    raise exception 'order not found';
  end if;

  select coalesce(
    sum(
      coalesce(soi.customer_sell_price_amount, soi.final_price_amount, soi.unit_sell_price_amount, 0)
      * coalesce(soi.confirmed_quantity, 0)
    ),
    0
  )
  into v_items_resell_delivered
  from public.shop_order_items soi
  where soi.order_id = p_order_id;

  v_recipient_charge_total :=
    case when not coalesce(v_order.deduct_delivery_from_margin, false)
      then coalesce(v_order.delivery_charge_amount, 0) else 0 end +
    case when not coalesce(v_order.deduct_cod_from_margin, false)
      then coalesce(v_order.cod_charge_amount, 0) else 0 end +
    case when not coalesce(v_order.deduct_print_from_margin, false)
      then coalesce(v_order.print_charge_amount, 0) else 0 end +
    case when not coalesce(v_order.deduct_packing_from_margin, false)
      then coalesce(v_order.packing_charge_amount, 0) else 0 end;

  v_cod_collect_amount :=
    v_items_resell_delivered + v_recipient_charge_total - coalesce(v_order.discount_amount, 0);

  update public.shop_orders
  set cod_collect_amount = v_cod_collect_amount, updated_at = now()
  where id = p_order_id;

  return v_cod_collect_amount;
end;
$function$;

GRANT ALL ON FUNCTION public.recompute_dropship_cod_collect_amount(bigint) TO anon;

GRANT ALL ON FUNCTION public.recompute_dropship_cod_collect_amount(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.recompute_dropship_cod_collect_amount(bigint) TO service_role;