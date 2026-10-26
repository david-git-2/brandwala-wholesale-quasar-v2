-- Dropship step ②: split courier remittance wallet legs (net payout + fee retained)
-- and drop settlement draft save from record_dropship_courier_bank_transfer.

begin;

create or replace function public.process_dropship_courier_remittance_uwl(
  p_order_id bigint,
  p_net_amount numeric,
  p_courier_charge numeric default 0.00,
  p_remittance_ref text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_courier_id bigint := 0;
  v_cod numeric(12,2) := 0.00;
  v_charge numeric(12,2) := 0.00;
  v_net numeric(12,2) := 0.00;
  v_currency text;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    raise exception 'Shop order #% not found', p_order_id;
  end if;

  v_currency := 'BDT';
  v_cod := coalesce(v_order.cod_collect_amount, 0.00);
  v_charge := greatest(coalesce(p_courier_charge, 0.00), 0.00);
  v_net := greatest(coalesce(p_net_amount, 0.00), 0.00);

  if v_order.courier_service_id is not null then
    select coalesce(wallet_entity_id, 0) into v_courier_id
    from public.courier_services
    where id = v_order.courier_service_id;

    if v_courier_id is null then
      v_courier_id := 0;
    end if;
  else
    v_courier_id := 0;
  end if;

  -- Leg 1: Courier debit — net cash remitted to tenant bank
  if v_net > 0 and not exists (
    select 1 from public.universal_wallet_ledger
    where tenant_id = v_order.tenant_id
      and entity_type = 'courier'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'courier_remittance'
  ) then
    perform public.record_ledger_transaction(
      p_tenant_id => v_order.tenant_id,
      p_entity_type => 'courier',
      p_entity_id => v_courier_id,
      p_type => 'debit',
      p_amount => v_net,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'cod_pending',
        'purpose', 'courier_remittance',
        'transaction_type', 'courier_remittance',
        'label', 'COD Remittance to Tenant',
        'order_no', v_order.order_no,
        'courier_charge', v_charge,
        'net_remitted', v_net,
        'gross_cod', v_cod,
        'remittance_ref', p_remittance_ref,
        'courier_service_id', v_order.courier_service_id
      )
    );
  end if;

  -- Leg 2: Courier debit — fee retained by courier
  if v_charge > 0 and not exists (
    select 1 from public.universal_wallet_ledger
    where tenant_id = v_order.tenant_id
      and entity_type = 'courier'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'courier_fee_retained'
  ) then
    perform public.record_ledger_transaction(
      p_tenant_id => v_order.tenant_id,
      p_entity_type => 'courier',
      p_entity_id => v_courier_id,
      p_type => 'debit',
      p_amount => v_charge,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'cod_pending',
        'purpose', 'courier_fee_retained',
        'transaction_type', 'courier_fee_retained',
        'label', 'Courier COD / Delivery Fee Retained',
        'order_no', v_order.order_no,
        'courier_charge', v_charge,
        'net_remitted', v_net,
        'gross_cod', v_cod,
        'remittance_ref', p_remittance_ref,
        'courier_service_id', v_order.courier_service_id
      )
    );
  end if;

  -- Leg 3: Tenant credit — net cash received
  if not exists (
    select 1 from public.universal_wallet_ledger
    where tenant_id = v_order.tenant_id
      and entity_type = 'tenant'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'tenant_remittance_received'
  ) then
    perform public.record_ledger_transaction(
      p_tenant_id => v_order.tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_order.tenant_id,
      p_type => 'credit',
      p_amount => v_net,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'payment_received',
        'purpose', 'tenant_remittance_received',
        'transaction_type', 'courier_remittance_received',
        'label', 'Courier Remittance Received',
        'order_no', v_order.order_no,
        'gross_cod', v_cod,
        'courier_charge', v_charge,
        'net_remitted', v_net,
        'remittance_ref', p_remittance_ref
      )
    );
  end if;
end;
$$;

grant execute on function public.process_dropship_courier_remittance_uwl(bigint, numeric, numeric, text) to authenticated;
grant execute on function public.process_dropship_courier_remittance_uwl(bigint, numeric, numeric, text) to service_role;

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

  select * into v_order from public.shop_orders
  where id = p_order_id and tenant_id = p_tenant_id for update;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.status <> 'delivered' then
    raise exception 'bank transfer requires delivered status (current: %)', v_order.status;
  end if;

  select * into v_settlement
  from public.dropship_order_settlements
  where shop_order_id = p_order_id;

  if not found then
    raise exception 'settlement is required before recording courier bank transfer';
  end if;

  if v_settlement.remittance_at is not null then
    raise exception 'courier bank transfer already recorded for this order';
  end if;

  v_remittance_ref := nullif(trim(coalesce(p_payload->>'remittance_ref', '')), '');
  v_bank_trx_id := nullif(trim(coalesce(p_payload->>'bank_trx_id', '')), '');

  if v_remittance_ref is null then
    raise exception 'remittance_ref is required';
  end if;

  select coalesce(amount, 0) into v_courier_charge
  from public.dropship_settlement_charge_lines
  where settlement_id = v_settlement.id
    and charge_type = 'cod'::public.dropship_settlement_charge_type;

  v_courier_charge := coalesce(
    nullif((p_payload->>'courier_charge')::numeric, null),
    v_courier_charge,
    v_order.cod_charge_amount,
    0
  );

  v_collected_cod := coalesce(
    v_settlement.collected_cod_amount,
    v_order.cod_collect_amount,
    0
  );

  v_net_amount := coalesce(
    nullif((p_payload->>'net_amount')::numeric, null),
    greatest(v_collected_cod - v_courier_charge, 0)
  );

  if v_net_amount <= 0 then
    raise exception 'net_amount must be positive';
  end if;

  if v_courier_charge < 0 then
    raise exception 'courier_charge cannot be negative';
  end if;

  if v_collected_cod > 0 and (v_net_amount + v_courier_charge) > (v_collected_cod + 0.01) then
    raise exception 'Remittance net (%) + charge (%) exceeds collected COD (%)',
      v_net_amount, v_courier_charge, v_collected_cod;
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

  if coalesce(v_remit->>'success', 'false') <> 'true' then
    return v_remit;
  end if;

  update public.dropship_order_settlements
  set remittance_at = now(), updated_at = now()
  where shop_order_id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'message', 'Courier bank transfer recorded',
    'order_id', p_order_id,
    'net_amount', v_net_amount,
    'courier_charge', v_courier_charge,
    'remittance', v_remit
  );
end;
$$;

grant execute on function public.record_dropship_courier_bank_transfer(bigint, bigint, jsonb) to authenticated;

commit;
