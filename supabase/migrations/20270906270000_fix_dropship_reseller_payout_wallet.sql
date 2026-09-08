-- Fix dropship reseller payout: credit merchant profit hold (not full invoice) on remittance;
-- debit that hold on transfer; stop FIFO from marking orders paid without wallet coverage.

begin;

-- ---------------------------------------------------------------------------
-- 1. record_dropship_courier_remittance — customer wallet gets profit hold only
-- ---------------------------------------------------------------------------
create or replace function public.record_dropship_courier_remittance(
  p_order_id bigint,
  p_net_amount numeric,
  p_remittance_ref text,
  p_bank_trx_id text default null,
  p_payment_date date default null,
  p_method text default 'cash',
  p_note text default null,
  p_courier_charge numeric default 0.00
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_invoice public.global_invoices;
  v_parent_tenant_id bigint;
  v_payment_id bigint;
  v_ref text;
  v_cod numeric(12,2);
  v_charge numeric(12,2);
  v_net numeric(12,2);
  v_invoice_due numeric(12,2);
  v_invoice_pay numeric(12,2);
  v_profit_hold numeric(12,2);
  v_currency text := 'BDT';
  v_already_remitted boolean := false;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'Order is not a dropship order';
  end if;

  if v_order.status not in ('delivered', 'payment_received') then
    raise exception 'Courier remittance requires order status delivered or payment_received (current: %)', v_order.status;
  end if;

  if v_order.global_invoice_id is null then
    raise exception 'Accounting invoice is required before recording courier remittance';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  select exists (
    select 1 from public.universal_wallet_ledger
    where parent_tenant_id = v_parent_tenant_id
      and entity_type = 'tenant'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'tenant_remittance_received'
  ) into v_already_remitted;

  if v_already_remitted then
    return jsonb_build_object(
      'success', true,
      'already_recorded', true,
      'invoice_id', v_order.global_invoice_id,
      'order_id', p_order_id,
      'status', v_order.status
    );
  end if;

  v_ref := nullif(trim(coalesce(p_remittance_ref, '')), '');
  if v_ref is null then
    raise exception 'Remittance reference is required';
  end if;

  v_net := coalesce(p_net_amount, 0.00);
  v_charge := coalesce(p_courier_charge, 0.00);

  select coalesce(s.collected_cod_amount, v_order.cod_collect_amount, 0.00)
  into v_cod
  from public.dropship_order_settlements s
  where s.shop_order_id = p_order_id;

  if not found then
    v_cod := coalesce(v_order.cod_collect_amount, 0.00);
  end if;

  if v_net <= 0.00 then
    raise exception 'Net remittance amount must be positive';
  end if;

  if v_charge < 0.00 then
    raise exception 'Courier charge cannot be negative';
  end if;

  if v_cod > 0 and (v_net + v_charge) > (v_cod + 0.01) then
    raise exception 'Remittance net (%) + charge (%) exceeds COD collect (%)', v_net, v_charge, v_cod;
  end if;

  if not (
    public.user_can_manage_parent_tenant(v_parent_tenant_id)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_order.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: Staff or Admin role required';
  end if;

  select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id for update;
  if v_invoice.id is null then
    raise exception 'Invoice not found';
  end if;
  if v_invoice.collection_source <> 'recipient'::public.collection_source_type then
    raise exception 'This invoice does not collect from recipient.';
  end if;

  v_invoice_due := greatest(coalesce(v_invoice.total_amount, 0.00) - coalesce(v_invoice.paid_amount, 0.00), 0.00);
  v_invoice_pay := least(v_net, v_invoice_due);
  v_profit_hold := greatest(v_net - v_invoice_pay, 0.00);

  perform public.process_dropship_courier_remittance_uwl(
    p_order_id => p_order_id,
    p_net_amount => v_net,
    p_courier_charge => v_charge,
    p_remittance_ref => v_ref
  );

  update public.universal_wallet_ledger
  set metadata = metadata || jsonb_build_object(
    'invoice_allocated', v_invoice_pay,
    'merchant_funds_held', v_profit_hold
  )
  where parent_tenant_id = v_parent_tenant_id
    and entity_type = 'tenant'
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'tenant_remittance_received';

  if v_invoice_pay > 0 then
    insert into public.global_payments (
      tenant_id,
      billing_profile_id,
      collection_source,
      amount,
      unallocated_amount,
      payment_date,
      method,
      reference,
      note
    )
    values (
      v_invoice.tenant_id,
      null,
      'recipient'::public.collection_source_type,
      v_invoice_pay,
      0.00,
      coalesce(p_payment_date, current_date),
      coalesce(nullif(trim(p_method), ''), 'cash'),
      v_ref,
      coalesce(
        nullif(trim(p_note), ''),
        'Courier remittance order #' || v_order.order_no
          || coalesce(' bank:' || nullif(trim(p_bank_trx_id), ''), '')
          || ' (invoice ' || v_invoice_pay::text || ' / held ' || v_profit_hold::text || ')'
      )
    )
    returning id into v_payment_id;

    insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
    values (v_invoice.tenant_id, v_payment_id, v_order.global_invoice_id, v_invoice_pay);

    update public.global_invoices
    set
      paid_amount = coalesce(paid_amount, 0.00) + v_invoice_pay,
      note = coalesce(nullif(trim(p_note), ''), note),
      updated_at = now()
    where id = v_order.global_invoice_id;

    perform public.recompute_global_invoice_payment_status(v_order.global_invoice_id);
  end if;

  if v_profit_hold > 0
     and v_invoice.billing_profile_id is not null
     and not exists (
       select 1 from public.universal_wallet_ledger
       where parent_tenant_id = v_parent_tenant_id
         and entity_type = 'customer'
         and entity_id = v_invoice.billing_profile_id
         and source_type = 'shop_order'
         and source_id = p_order_id::text
         and coalesce(metadata->>'transaction_type', '') in ('merchant_funds_held', 'invoice_collection')
     ) then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_tenant_id,
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_invoice.billing_profile_id,
      p_type => 'credit',
      p_amount => v_profit_hold,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'receivable',
        'transaction_type', 'merchant_funds_held',
        'label', 'Merchant profit held from COD remittance',
        'order_no', v_order.order_no,
        'invoice_id', v_order.global_invoice_id,
        'invoice_no', v_invoice.invoice_no,
        'remittance_ref', v_ref,
        'merchant_funds_held', v_profit_hold
      )
    );
  end if;

  update public.shop_orders
  set
    status = 'payment_received'::public.shop_order_status,
    courier_remittance_ref = v_ref,
    courier_bank_trx_id = coalesce(nullif(trim(p_bank_trx_id), ''), courier_bank_trx_id),
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_order.global_invoice_id,
    'payment_id', v_payment_id,
    'order_id', p_order_id,
    'status', 'payment_received',
    'invoice_allocated', v_invoice_pay,
    'merchant_funds_held', v_profit_hold
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. dispense_middleman_payout_from_tenant — require merchant wallet balance
-- ---------------------------------------------------------------------------
create or replace function public.dispense_middleman_payout_from_tenant(
  p_tenant_id bigint,
  p_billing_profile_id bigint,
  p_amount numeric,
  p_payout_method text default 'bank_transfer',
  p_reference_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile public.billing_profiles;
  v_payout_id text;
  v_parent_tenant_id bigint;
  v_customer_avail numeric(18,4) := 0;
begin
  if p_tenant_id is null then
    return jsonb_build_object('success', false, 'error', 'Tenant ID is required');
  end if;

  if p_billing_profile_id is null then
    return jsonb_build_object('success', false, 'error', 'Billing Profile ID is required');
  end if;

  if coalesce(p_amount, 0) <= 0 then
    return jsonb_build_object('success', false, 'error', 'Payout amount must be greater than 0');
  end if;

  if not (
    public.is_superadmin()
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    return jsonb_build_object('success', false, 'error', format('Permission denied for tenant %s', p_tenant_id));
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);

  select * into v_profile
  from public.billing_profiles
  where id = p_billing_profile_id and tenant_id = p_tenant_id;

  if v_profile.id is null then
    return jsonb_build_object('success', false, 'error', format('Billing profile #%s not found for tenant %s', p_billing_profile_id, p_tenant_id));
  end if;

  select coalesce(w.available_balance, 0)
  into v_customer_avail
  from public.wallet_accounts w
  where w.parent_tenant_id = v_parent_tenant_id
    and w.entity_type = 'customer'
    and w.entity_id = p_billing_profile_id
    and w.currency_code = 'BDT';

  if v_customer_avail + 0.0001 < p_amount then
    return jsonb_build_object(
      'success', false,
      'error', format(
        'Insufficient merchant wallet balance. Available: %s, payout: %s',
        v_customer_avail,
        p_amount
      )
    );
  end if;

  v_payout_id := 'PO-' || gen_random_uuid()::text;

  perform public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_tenant_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_parent_tenant_id,
    p_type => 'debit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_payout_id,
    p_metadata => jsonb_build_object(
      'section', 'payout_earned',
      'purpose', 'middleman_payout_tenant_debit',
      'transaction_type', 'profit_paid_out',
      'label', 'Profit Paid Out',
      'billing_profile_id', p_billing_profile_id,
      'billing_profile_name', v_profile.name,
      'payout_method', p_payout_method,
      'notes', p_reference_notes
    )
  );

  perform public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_tenant_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'customer',
    p_entity_id => p_billing_profile_id,
    p_type => 'debit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_payout_id,
    p_metadata => jsonb_build_object(
      'section', 'payout_earned',
      'purpose', 'middleman_payout_debit',
      'transaction_type', 'profit_paid_out',
      'label', 'Profit Paid Out',
      'payout_method', p_payout_method,
      'notes', p_reference_notes
    )
  );

  perform public.apply_dropship_payout_settlement_fifo(
    p_tenant_id,
    p_billing_profile_id,
    p_amount
  );

  return jsonb_build_object(
    'success', true,
    'payout_id', v_payout_id,
    'billing_profile_id', p_billing_profile_id,
    'amount', p_amount
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. apply_dropship_payout_settlement_fifo — match merchant hold credits
-- ---------------------------------------------------------------------------
create or replace function public.apply_dropship_payout_settlement_fifo(
  p_tenant_id bigint,
  p_billing_profile_id bigint,
  p_amount numeric
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_remaining numeric := greatest(coalesce(p_amount, 0), 0);
  v_parent_tenant_id bigint;
  r record;
  v_hold numeric;
  v_paid numeric;
  v_outstanding numeric;
begin
  if v_remaining <= 0 then
    return;
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);

  for r in
    select o.id
    from public.shop_orders o
    where o.tenant_id = p_tenant_id
      and o.billing_profile_id = p_billing_profile_id
      and o.shop_type_snapshot = 'dropship'
      and o.global_invoice_id is not null
      and coalesce(o.payout_settlement_status, 'unpaid') in ('unpaid', 'partial')
    order by o.created_at asc, o.id asc
  loop
    exit when v_remaining <= 0;

    select coalesce(sum(u.amount), 0)
    into v_hold
    from public.universal_wallet_ledger u
    where u.parent_tenant_id = v_parent_tenant_id
      and u.source_type = 'shop_order'
      and u.source_id = r.id::text
      and u.entity_type in ('middleman', 'customer')
      and u.type = 'credit'
      and coalesce(u.metadata->>'transaction_type', '') in (
        'merchant_funds_held',
        'invoice_collection',
        'dropship_profit'
      );

    select coalesce(sum(u.amount), 0)
    into v_paid
    from public.universal_wallet_ledger u
    where u.parent_tenant_id = v_parent_tenant_id
      and u.entity_type in ('middleman', 'customer')
      and u.entity_id = p_billing_profile_id
      and u.type = 'debit'
      and coalesce(u.metadata->>'transaction_type', '') = 'profit_paid_out'
      and coalesce(u.metadata->>'shop_order_id', u.metadata->>'order_id', '') = r.id::text;

    v_outstanding := greatest(v_hold - v_paid, 0);

    if v_outstanding <= 0 then
      continue;
    end if;

    if v_remaining >= v_outstanding then
      update public.shop_orders
      set payout_settlement_status = 'paid',
          updated_at = now()
      where id = r.id;
      v_remaining := v_remaining - v_outstanding;
    else
      update public.shop_orders
      set payout_settlement_status = 'partial',
          updated_at = now()
      where id = r.id;
      v_remaining := 0;
    end if;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. transfer_dropship_reseller_profit — payout capped to held funds / wallet
-- ---------------------------------------------------------------------------
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
  v_parent_tenant_id bigint;
  v_merchant_funds_held numeric(15,2);
  v_order_hold numeric(15,2);
  v_customer_avail numeric(18,4);
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders
  where id = p_order_id and tenant_id = p_tenant_id for update;

  if not found then raise exception 'order not found'; end if;

  select * into v_settlement
  from public.dropship_order_settlements
  where shop_order_id = p_order_id;

  if not found then
    raise exception 'settlement draft is required before reseller payout';
  end if;

  if v_order.status = 'reseller_paid'::public.shop_order_status
     or v_settlement.merchant_payout_at is not null
     or v_settlement.status = 'confirmed' then
    return jsonb_build_object(
      'success', true,
      'already_recorded', true,
      'message', 'Reseller profit already transferred',
      'order_id', p_order_id,
      'status', coalesce(v_order.status::text, 'reseller_paid')
    );
  end if;

  if v_order.status not in ('delivered', 'payment_received') then
    raise exception 'reseller payout requires delivered or payment_received (current: %)', v_order.status;
  end if;

  if p_payload is not null and p_payload <> '{}'::jsonb then
    v_save := public.save_dropship_settlement_draft(p_tenant_id, p_order_id, p_payload);
    if coalesce(v_save->>'success', 'false') <> 'true' then
      return v_save;
    end if;

    select * into v_settlement
    from public.dropship_order_settlements
    where shop_order_id = p_order_id;
  end if;

  v_billing_profile_id := coalesce(v_order.billing_profile_id, v_settlement.billing_profile_id);
  if v_billing_profile_id is null then
    raise exception 'billing profile is required for reseller payout';
  end if;

  v_amount := coalesce(v_settlement.reseller_profit, 0);
  if v_amount <= 0 then
    raise exception 'reseller profit must be positive';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);

  select (u.metadata->>'merchant_funds_held')::numeric
  into v_merchant_funds_held
  from public.universal_wallet_ledger u
  where u.parent_tenant_id = v_parent_tenant_id
    and u.entity_type = 'tenant'
    and u.source_type = 'shop_order'
    and u.source_id = p_order_id::text
    and u.metadata->>'purpose' = 'tenant_remittance_received'
  limit 1;

  select coalesce(sum(u.amount), 0)
  into v_order_hold
  from public.universal_wallet_ledger u
  where u.parent_tenant_id = v_parent_tenant_id
    and u.entity_type = 'customer'
    and u.entity_id = v_billing_profile_id
    and u.source_type = 'shop_order'
    and u.source_id = p_order_id::text
    and u.type = 'credit'
    and coalesce(u.metadata->>'transaction_type', '') in ('merchant_funds_held', 'invoice_collection');

  select coalesce(w.available_balance, 0)
  into v_customer_avail
  from public.wallet_accounts w
  where w.parent_tenant_id = v_parent_tenant_id
    and w.entity_type = 'customer'
    and w.entity_id = v_billing_profile_id
    and w.currency_code = 'BDT';

  if v_merchant_funds_held is not null then
    v_amount := least(v_amount, v_merchant_funds_held);
  end if;

  if v_order_hold > 0 then
    v_amount := least(v_amount, v_order_hold);
  end if;

  v_amount := least(v_amount, v_customer_avail);

  if v_amount <= 0 then
    raise exception
      'No merchant funds available to pay out for this order. Record courier bank transfer first or check settlement profit.';
  end if;

  v_payout := public.dispense_middleman_payout_from_tenant(
    p_tenant_id,
    v_billing_profile_id,
    v_amount,
    coalesce(nullif(trim(p_payload->>'payout_method'), ''), 'bank_transfer'),
    coalesce(
      nullif(trim(p_payload->>'reference_notes'), ''),
      'Dropship management desk payout for order #' || v_order.order_no
    ) || ' [order_id=' || p_order_id::text || ']'
  );

  if coalesce(v_payout->>'success', 'false') <> 'true' then
    return v_payout;
  end if;

  update public.universal_wallet_ledger
  set metadata = metadata || jsonb_build_object('shop_order_id', p_order_id::text)
  where parent_tenant_id = v_parent_tenant_id
    and entity_type = 'customer'
    and entity_id = v_billing_profile_id
    and source_type = 'payout'
    and source_id = v_payout->>'payout_id';

  update public.dropship_order_settlements
  set
    status = 'confirmed',
    confirmed_at = now(),
    confirmed_by = auth.uid(),
    merchant_payout_at = now(),
    updated_at = now()
  where id = v_settlement.id;

  update public.shop_orders
  set
    status = 'reseller_paid'::public.shop_order_status,
    payout_settlement_status = 'paid',
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'message', 'Reseller profit transferred',
    'order_id', p_order_id,
    'amount', v_amount,
    'status', 'reseller_paid',
    'payout', v_payout
  );
end;
$$;

grant execute on function public.record_dropship_courier_remittance(
  bigint, numeric, text, text, date, text, text, numeric
) to authenticated;

grant execute on function public.dispense_middleman_payout_from_tenant(
  bigint, bigint, numeric, text, text
) to authenticated, service_role;

grant execute on function public.apply_dropship_payout_settlement_fifo(bigint, bigint, numeric) to authenticated;

grant execute on function public.transfer_dropship_reseller_profit(bigint, bigint, jsonb) to authenticated;

commit;
