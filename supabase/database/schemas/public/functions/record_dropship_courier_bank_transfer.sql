CREATE FUNCTION public.record_dropship_courier_bank_transfer (
  p_tenant_id bigint,
  p_order_id  bigint,
  p_payload   jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders;
  v_settlement public.dropship_order_settlements;
  v_remit jsonb;
  v_net_amount numeric(15,2);
  v_courier_charge numeric(15,2);
  v_collected_cod numeric(15,2);
  v_remittance_ref text;
  v_bank_trx_id text;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id
     and v_order.parent_tenant_id is distinct from p_tenant_id then
    raise exception 'order not found';
  end if;

  select * into v_settlement
  from public.dropship_order_settlements
  where shop_order_id = p_order_id;

  if not found then
    raise exception 'settlement is required before recording courier bank transfer';
  end if;

  if v_settlement.remittance_at is not null then
    return jsonb_build_object(
      'success', true,
      'already_recorded', true,
      'message', 'Courier bank transfer already recorded',
      'order_id', p_order_id,
      'remittance', null
    );
  end if;

  if v_order.status not in ('delivered', 'payment_received') then
    raise exception 'bank transfer requires delivered or payment_received status (current: %)', v_order.status;
  end if;

  v_remittance_ref := nullif(trim(coalesce(p_payload->>'remittance_ref', '')), '');
  v_bank_trx_id := nullif(trim(coalesce(p_payload->>'bank_trx_id', '')), '');

  if v_remittance_ref is null then
    raise exception 'remittance_ref is required';
  end if;

  v_collected_cod := coalesce(
    v_settlement.collected_cod_amount,
    v_order.cod_collect_amount,
    0
  );

  v_net_amount := coalesce((p_payload->>'net_amount')::numeric, 0);

  if v_net_amount <= 0 then
    raise exception 'net_amount must be positive';
  end if;

  if v_collected_cod > 0 and v_net_amount > (v_collected_cod + 0.01) then
    raise exception 'Net remittance (%) exceeds collected COD (%)', v_net_amount, v_collected_cod;
  end if;

  v_courier_charge := greatest(v_collected_cod - v_net_amount, 0);

  v_remit := public.record_dropship_courier_remittance(
    p_order_id,
    v_net_amount,
    v_remittance_ref,
    v_bank_trx_id,
    null,
    'bank_transfer',
    null,
    v_courier_charge
  );

  if coalesce(v_remit->>'success', 'false') <> 'true' then
    return v_remit;
  end if;

  update public.dropship_order_settlements
  set remittance_at = now(), updated_at = now()
  where shop_order_id = p_order_id;

  update public.shop_orders
  set
    courier_remittance_ref = coalesce(v_remittance_ref, courier_remittance_ref),
    courier_bank_trx_id = coalesce(v_bank_trx_id, courier_bank_trx_id),
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'message', 'Courier bank transfer recorded; invoice paid and merchant wallet credited from remittance remainder',
    'order_id', p_order_id,
    'net_amount', v_net_amount,
    'courier_charge', v_courier_charge,
    'collected_cod', v_collected_cod,
    'remittance', v_remit
  );
end;
$function$;

GRANT ALL ON FUNCTION public.record_dropship_courier_bank_transfer(bigint, bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.record_dropship_courier_bank_transfer(bigint, bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.record_dropship_courier_bank_transfer(bigint, bigint, jsonb) TO service_role;