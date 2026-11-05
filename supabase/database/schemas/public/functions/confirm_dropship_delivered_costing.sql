CREATE FUNCTION public.confirm_dropship_delivered_costing (
  p_order_id        bigint,
  p_cod_amount      numeric DEFAULT NULL::numeric,
  p_delivery_charge numeric DEFAULT NULL::numeric,
  p_courier_notes   text    DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders;
  v_cod numeric(15,4) := 0.0000;
  v_delivery_charge numeric(15,4) := 0.0000;
begin
  select * into v_order
  from public.shop_orders
  where id = p_order_id for update;

  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', format('Shop order #%s not found', p_order_id));
  end if;

  if not (
    public.is_superadmin()
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_order.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    return jsonb_build_object('success', false, 'error', format('Permission denied for tenant %s', v_order.tenant_id));
  end if;

  if v_order.status not in ('delivered', 'payment_received') then
    return jsonb_build_object(
      'success', false,
      'error', format('Order #%s status is "%s" (must be delivered or payment_received)', v_order.order_no, v_order.status)
    );
  end if;

  v_cod := coalesce(p_cod_amount, v_order.cod_collect_amount, 0.0000);
  v_delivery_charge := coalesce(p_delivery_charge, v_order.delivery_charge_amount, 0.0000);

  update public.shop_orders
  set
    cod_collect_amount = v_cod,
    delivery_charge_amount = v_delivery_charge,
    driver_notes = coalesce(nullif(trim(p_courier_notes), ''), driver_notes),
    updated_at = now()
  where id = p_order_id;

  perform public.ensure_dropship_courier_cod_receivable(p_order_id);

  return jsonb_build_object(
    'success', true,
    'message', 'Delivered costing fields saved; courier COD receivable booked when applicable',
    'order_id', p_order_id,
    'cod_amount', v_cod,
    'delivery_charge', v_delivery_charge
  );
end;
$function$;

GRANT ALL ON FUNCTION public.confirm_dropship_delivered_costing(bigint, numeric, numeric, text) TO anon;

GRANT ALL ON FUNCTION public.confirm_dropship_delivered_costing(bigint, numeric, numeric, text) TO authenticated;

GRANT ALL ON FUNCTION public.confirm_dropship_delivered_costing(bigint, numeric, numeric, text) TO service_role;