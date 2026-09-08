-- Dropship reseller profit: credit merchant wallet on transfer; cash withdrawal stays on dispense_middleman_payout_from_tenant.
-- Remittance no longer credits merchant_funds_held on the billing-profile wallet.

begin;

-- ---------------------------------------------------------------------------
-- 1. apply_dropship_payout_settlement_fifo — FIFO matches dropship_profit credits only
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
      and coalesce(u.metadata->>'transaction_type', '') = 'dropship_profit';

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
-- 2. transfer_dropship_reseller_profit — credit dropship_profit (no wallet debit)
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
  v_billing_profile_id bigint;
  v_amount numeric(15,2);
  v_parent_tenant_id bigint;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders
  where id = p_order_id and tenant_id = p_tenant_id for update;

  if not found then
    raise exception 'order not found';
  end if;

  select * into v_settlement
  from public.dropship_order_settlements
  where shop_order_id = p_order_id;

  if not found then
    raise exception 'settlement draft is required before crediting reseller profit';
  end if;

  if v_order.status = 'reseller_paid'::public.shop_order_status
     or v_settlement.merchant_payout_at is not null
     or v_settlement.status = 'confirmed' then
    return jsonb_build_object(
      'success', true,
      'already_recorded', true,
      'message', 'Reseller profit already credited to merchant wallet',
      'order_id', p_order_id,
      'status', coalesce(v_order.status::text, 'reseller_paid')
    );
  end if;

  if v_order.courier_remittance_ref is null
     and v_settlement.remittance_at is null
     and v_order.status <> 'payment_received'::public.shop_order_status then
    raise exception 'Courier remittance must be recorded before crediting reseller profit (current: %)', v_order.status;
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
    raise exception 'billing profile is required for reseller profit credit';
  end if;

  v_amount := coalesce(v_settlement.reseller_profit, 0);
  if v_amount <= 0 then
    raise exception 'reseller profit must be positive';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);

  if exists (
    select 1
    from public.universal_wallet_ledger u
    where u.parent_tenant_id = v_parent_tenant_id
      and u.source_type = 'shop_order'
      and u.source_id = p_order_id::text
      and u.entity_type in ('middleman', 'customer')
      and u.entity_id = v_billing_profile_id
      and u.type = 'credit'
      and coalesce(u.metadata->>'transaction_type', '') = 'dropship_profit'
  ) then
    return jsonb_build_object(
      'success', true,
      'already_recorded', true,
      'message', 'Reseller profit already credited to merchant wallet',
      'order_id', p_order_id,
      'amount', v_amount
    );
  end if;

  perform public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_tenant_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'customer',
    p_entity_id => v_billing_profile_id,
    p_type => 'credit',
    p_amount => v_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'shop_order',
    p_source_id => p_order_id::text,
    p_metadata => jsonb_build_object(
      'section', 'payout_earned',
      'transaction_type', 'dropship_profit',
      'label', 'Dropship profit earned',
      'order_no', v_order.order_no,
      'order_id', p_order_id,
      'shop_order_id', p_order_id::text,
      'invoice_id', v_order.global_invoice_id,
      'notes', coalesce(
        nullif(trim(p_payload->>'reference_notes'), ''),
        'Dropship reseller profit for order #' || v_order.order_no
      )
    )
  );

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
    'message', 'Reseller profit credited to merchant wallet',
    'order_id', p_order_id,
    'amount', v_amount,
    'status', 'reseller_paid',
    'billing_profile_id', v_billing_profile_id
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. get_my_dropship_wallet_summary — available from wallet_accounts; pending = uncredited profit
-- ---------------------------------------------------------------------------
create or replace function public.get_my_dropship_wallet_summary()
returns table (
  billing_profile_id bigint,
  available_balance numeric,
  pending_balance numeric,
  locked_balance numeric,
  currency text
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_email text := public.current_user_email();
  v_tenant_id bigint;
  v_group_id bigint;
  v_bp_id bigint;
  v_available numeric := 0;
  v_pending numeric := 0;
  v_locked numeric := 0;
begin
  if v_email is null or length(trim(v_email)) = 0 then
    raise exception 'Not authenticated';
  end if;

  select cg.tenant_id, cgm.customer_group_id
  into v_tenant_id, v_group_id
  from public.customer_group_members cgm
  join public.customer_groups cg on cg.id = cgm.customer_group_id
  where lower(trim(cgm.email)) = lower(trim(v_email))
    and cgm.is_active = true
    and cg.is_active = true
  order by cgm.id
  limit 1;

  if v_tenant_id is null or v_group_id is null then
    raise exception 'No active customer group membership';
  end if;

  v_bp_id := public.resolve_billing_profile_for_customer_group(v_tenant_id, v_group_id);
  if v_bp_id is null then
    raise exception 'No billing profile linked for your customer group';
  end if;

  select coalesce(w.available_balance, 0)
  into v_available
  from public.wallet_accounts w
  where w.parent_tenant_id = public.resolve_parent_tenant_id(v_tenant_id)
    and w.entity_type = 'customer'
    and w.entity_id = v_bp_id
    and w.currency_code = 'BDT';

  select coalesce(sum(s.reseller_profit), 0)
  into v_pending
  from public.shop_orders o
  join public.dropship_order_settlements s on s.shop_order_id = o.id
  where o.tenant_id = v_tenant_id
    and o.billing_profile_id = v_bp_id
    and o.shop_type_snapshot = 'dropship'
    and o.status = 'payment_received'::public.shop_order_status
    and coalesce(s.reseller_profit, 0) > 0
    and s.merchant_payout_at is null;

  select coalesce(sum(greatest(coalesce(o.cod_collect_amount, 0), 0)), 0)
  into v_locked
  from public.shop_orders o
  where o.tenant_id = v_tenant_id
    and o.billing_profile_id = v_bp_id
    and o.shop_type_snapshot = 'dropship'
    and o.status = 'delivered'
    and o.courier_remittance_ref is null
    and coalesce(o.collection_source, 'recipient') = 'recipient';

  return query select
    v_bp_id,
    v_available,
    v_pending,
    v_locked,
    'BDT'::text;
end;
$$;

grant execute on function public.transfer_dropship_reseller_profit(bigint, bigint, jsonb) to authenticated;
grant execute on function public.apply_dropship_payout_settlement_fifo(bigint, bigint, numeric) to authenticated;
grant execute on function public.get_my_dropship_wallet_summary() to authenticated;

commit;
