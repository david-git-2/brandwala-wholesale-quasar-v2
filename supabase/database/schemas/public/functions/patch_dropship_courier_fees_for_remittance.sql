CREATE FUNCTION public.patch_dropship_courier_fees_for_remittance (
  p_order_id bigint,
  p_delivery numeric,
  p_cod      numeric
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders;
  v_delivery_payer text := 'recipient';
  v_cod_payer text := 'recipient';
  v_charge_lines jsonb;
begin
  if p_delivery is null or p_cod is null then
    raise exception 'delivery and COD fees are required';
  end if;

  if coalesce(p_delivery, 0) < 0 or coalesce(p_cod, 0) < 0 then
    raise exception 'courier fees cannot be negative';
  end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    raise exception 'order not found';
  end if;

  select coalesce(cl.payer::text, 'recipient')
  into v_delivery_payer
  from public.dropship_order_settlements s
  inner join public.dropship_settlement_charge_lines cl
    on cl.settlement_id = s.id and cl.charge_type = 'delivery'::public.dropship_settlement_charge_type
  where s.shop_order_id = p_order_id
  limit 1;

  if not found then
    v_delivery_payer := case
      when coalesce(v_order.deduct_delivery_from_margin, false) then 'merchant'
      else 'recipient'
    end;
  end if;

  select coalesce(cl.payer::text, 'recipient')
  into v_cod_payer
  from public.dropship_order_settlements s
  inner join public.dropship_settlement_charge_lines cl
    on cl.settlement_id = s.id and cl.charge_type = 'cod'::public.dropship_settlement_charge_type
  where s.shop_order_id = p_order_id
  limit 1;

  if not found then
    v_cod_payer := case
      when coalesce(v_order.deduct_cod_from_margin, false) then 'merchant'
      else 'recipient'
    end;
  end if;

  v_charge_lines := jsonb_build_array(
    jsonb_build_object(
      'charge_type', 'delivery',
      'amount', round(coalesce(p_delivery, 0), 2),
      'payer', v_delivery_payer
    ),
    jsonb_build_object(
      'charge_type', 'cod',
      'amount', round(coalesce(p_cod, 0), 2),
      'payer', v_cod_payer
    )
  );

  perform public.apply_dropship_order_charge_lines(p_order_id, v_charge_lines);

  update public.dropship_settlement_charge_lines cl
  set
    amount = case cl.charge_type
      when 'delivery'::public.dropship_settlement_charge_type then round(coalesce(p_delivery, 0), 2)
      when 'cod'::public.dropship_settlement_charge_type then round(coalesce(p_cod, 0), 2)
      else cl.amount
    end,
    updated_at = now()
  from public.dropship_order_settlements s
  where cl.settlement_id = s.id
    and s.shop_order_id = p_order_id
    and cl.charge_type in (
      'delivery'::public.dropship_settlement_charge_type,
      'cod'::public.dropship_settlement_charge_type
    );
end;
$function$;

GRANT ALL ON FUNCTION public.patch_dropship_courier_fees_for_remittance(bigint, numeric, numeric) TO anon;

GRANT ALL ON FUNCTION public.patch_dropship_courier_fees_for_remittance(bigint, numeric, numeric) TO authenticated;

GRANT ALL ON FUNCTION public.patch_dropship_courier_fees_for_remittance(bigint, numeric, numeric) TO service_role;