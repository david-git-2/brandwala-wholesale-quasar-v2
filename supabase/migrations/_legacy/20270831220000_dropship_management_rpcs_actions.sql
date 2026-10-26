-- Migration: Dropship management orchestration RPCs (DROPSHIP_MANAGEMENT.md §7)

begin;

create or replace function public.mark_dropship_order_delivered(
  p_tenant_id bigint,
  p_order_id bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_save jsonb;
  v_advance jsonb;
  v_costing jsonb;
  v_delivery_amount numeric(15,2);
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders
  where id = p_order_id and tenant_id = p_tenant_id for update;

  if not found then raise exception 'order not found'; end if;
  if v_order.status <> 'shipped' then
    raise exception 'mark as delivered requires shipped status (current: %)', v_order.status;
  end if;

  v_save := public.save_dropship_settlement_draft(p_tenant_id, p_order_id, p_payload);
  if coalesce(v_save->>'success', 'false') <> 'true' then
    return v_save;
  end if;

  v_advance := public.advance_dropship_order_status(p_order_id, 'delivered'::public.shop_order_status);
  if coalesce(v_advance->>'success', 'false') <> 'true' then
    return v_advance;
  end if;

  select coalesce(cl.amount, 0) into v_delivery_amount
  from public.dropship_order_settlements s
  join public.dropship_settlement_charge_lines cl
    on cl.settlement_id = s.id and cl.charge_type = 'delivery'
  where s.shop_order_id = p_order_id;

  v_costing := public.confirm_dropship_delivered_costing(
    p_order_id,
    coalesce((p_payload->>'collected_cod_amount')::numeric, 0),
    v_delivery_amount,
    null
  );

  if coalesce(v_costing->>'success', 'false') <> 'true' then
    return v_costing;
  end if;

  update public.dropship_order_settlements
  set courier_cod_booked_at = now(), updated_at = now()
  where shop_order_id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'message', 'Order marked as delivered',
    'order_id', p_order_id
  );
end;
$$;

create or replace function public.record_dropship_courier_bank_transfer(
  p_tenant_id bigint,
  p_order_id bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_save jsonb;
  v_remit jsonb;
  v_net_amount numeric(15,2);
  v_courier_charge numeric(15,2);
  v_remittance_ref text;
  v_bank_trx_id text;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders
  where id = p_order_id and tenant_id = p_tenant_id for update;

  if not found then raise exception 'order not found'; end if;
  if v_order.status <> 'delivered' then
    raise exception 'bank transfer requires delivered status (current: %)', v_order.status;
  end if;

  v_net_amount := coalesce((p_payload->>'net_amount')::numeric, 0);
  v_courier_charge := coalesce((p_payload->>'courier_charge')::numeric, 0);
  v_remittance_ref := nullif(trim(coalesce(p_payload->>'remittance_ref', '')), '');
  v_bank_trx_id := nullif(trim(coalesce(p_payload->>'bank_trx_id', '')), '');

  if v_remittance_ref is null then
    raise exception 'remittance_ref is required';
  end if;
  if v_net_amount <= 0 then
    raise exception 'net_amount must be positive';
  end if;

  v_save := public.save_dropship_settlement_draft(p_tenant_id, p_order_id, p_payload);
  if coalesce(v_save->>'success', 'false') <> 'true' then
    return v_save;
  end if;

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

  update public.dropship_order_settlements
  set remittance_at = now(), updated_at = now()
  where shop_order_id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'message', 'Courier bank transfer recorded',
    'order_id', p_order_id,
    'remittance', v_remit
  );
end;
$$;

create or replace function public.transfer_dropship_reseller_profit(
  p_tenant_id bigint,
  p_order_id bigint,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_settlement public.dropship_order_settlements;
  v_save jsonb;
  v_payout jsonb;
  v_billing_profile_id bigint;
  v_amount numeric(15,2);
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders
  where id = p_order_id and tenant_id = p_tenant_id for update;

  if not found then raise exception 'order not found'; end if;
  if v_order.status not in ('delivered', 'payment_received') then
    raise exception 'reseller payout requires delivered or payment_received (current: %)', v_order.status;
  end if;

  if p_payload is not null and p_payload <> '{}'::jsonb then
    v_save := public.save_dropship_settlement_draft(p_tenant_id, p_order_id, p_payload);
    if coalesce(v_save->>'success', 'false') <> 'true' then
      return v_save;
    end if;
  end if;

  select * into v_settlement
  from public.dropship_order_settlements
  where shop_order_id = p_order_id;

  if not found then
    raise exception 'settlement draft is required before reseller payout';
  end if;

  if v_settlement.status = 'confirmed' then
    raise exception 'settlement already confirmed';
  end if;

  v_billing_profile_id := coalesce(v_order.billing_profile_id, v_settlement.billing_profile_id);
  if v_billing_profile_id is null then
    raise exception 'billing profile is required for reseller payout';
  end if;

  v_amount := coalesce(v_settlement.reseller_profit, 0);
  if v_amount <= 0 then
    raise exception 'reseller profit must be positive';
  end if;

  v_payout := public.dispense_middleman_payout_from_tenant(
    p_tenant_id,
    v_billing_profile_id,
    v_amount,
    coalesce(nullif(trim(p_payload->>'payout_method'), ''), 'bank_transfer'),
    coalesce(nullif(trim(p_payload->>'reference_notes'), ''), 'Dropship management desk payout for order #' || v_order.order_no)
  );

  if coalesce(v_payout->>'success', 'false') <> 'true' then
    return v_payout;
  end if;

  update public.dropship_order_settlements
  set
    status = 'confirmed',
    confirmed_at = now(),
    confirmed_by = auth.uid(),
    merchant_payout_at = now(),
    updated_at = now()
  where id = v_settlement.id;

  update public.shop_orders
  set payout_settlement_status = 'paid', updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'message', 'Reseller profit transferred',
    'order_id', p_order_id,
    'amount', v_amount,
    'payout', v_payout
  );
end;
$$;

grant execute on function public.mark_dropship_order_delivered(bigint, bigint, jsonb) to authenticated;
grant execute on function public.record_dropship_courier_bank_transfer(bigint, bigint, jsonb) to authenticated;
grant execute on function public.transfer_dropship_reseller_profit(bigint, bigint, jsonb) to authenticated;

commit;
