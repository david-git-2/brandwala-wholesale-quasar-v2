-- BP24: commission / merchant profit payout on money spine (replaces dispense as writer).

ALTER TABLE public.pays DROP CONSTRAINT IF EXISTS pays_source_check;
ALTER TABLE public.pays ADD CONSTRAINT pays_source_check CHECK (
  source = ANY (ARRAY[
    'customer_cash'::text,
    'bank'::text,
    'store_credit'::text,
    'courier_remittance'::text,
    'ap_payout'::text,
    'commission'::text
  ])
);

CREATE OR REPLACE FUNCTION public._kernel_post_commission_payout(
  p_tenant_id bigint,
  p_profile_id bigint,
  p_paid_on date,
  p_amount numeric,
  p_note text DEFAULT NULL,
  p_reference text DEFAULT NULL,
  p_payout_method text DEFAULT 'bank_transfer',
  p_cashbook_point_id bigint DEFAULT NULL,
  p_cashbook_point_pot_id bigint DEFAULT NULL,
  p_source_id text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
) RETURNS public.pays
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_profile public.profiles;
  v_parent_tenant_id bigint;
  v_pot_id bigint := p_cashbook_point_pot_id;
  v_pay public.pays;
  v_existing public.pays;
  v_ledger_source_id text;
  v_method text := coalesce(nullif(btrim(p_payout_method), ''), 'bank_transfer');
  v_paid_on date := coalesce(p_paid_on, current_date);
begin
  if p_tenant_id is null then
    raise exception 'Tenant ID is required';
  end if;
  if p_profile_id is null then
    raise exception 'Billing profile ID is required';
  end if;
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Payout amount must be greater than 0';
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
    raise exception 'Permission denied for tenant %', p_tenant_id;
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);

  v_existing := public._kernel_claim_pay_idempotency(v_parent_tenant_id, p_idempotency_key);
  if v_existing.id is not null then
    return v_existing;
  end if;

  select * into v_profile
  from public.profiles
  where id = p_profile_id
    and profile_type = 'customer'::public.profile_party_type;

  if v_profile.id is null or not public.profile_valid_for_issuer(p_profile_id, p_tenant_id) then
    raise exception 'Customer profile #% not found for tenant %', p_profile_id, p_tenant_id;
  end if;

  if p_cashbook_point_id is null then
    raise exception 'Choose a cash point for this pay out';
  end if;

  if not exists (
    select 1
    from public.cashbook_points cp
    join public.cashbook_accounts ca on ca.id = cp.cashbook_account_id
    where cp.id = p_cashbook_point_id
      and cp.is_active = true
      and ca.parent_tenant_id = v_parent_tenant_id
      and ca.entity_type = 'tenant'
      and ca.entity_id = v_parent_tenant_id
  ) then
    raise exception 'Invalid cash point for this tenant';
  end if;

  if v_pot_id is null then
    select cpp.id
    into v_pot_id
    from public.cashbook_point_pots cpp
    where cpp.cashbook_point_id = p_cashbook_point_id
      and cpp.parent_tenant_id = v_parent_tenant_id
    order by case when upper(cpp.currency_code) = 'BDT' then 0 else 1 end, cpp.id
    limit 1;
  end if;

  if v_pot_id is null then
    raise exception 'No currency pot at this cash point';
  end if;

  perform public._kernel_lock_cashbook_point_pots(p_cashbook_point_id);

  insert into public.pays (
    tenant_id,
    profile_id,
    source,
    amount,
    unallocated_amount,
    payment_date,
    method,
    reference,
    note,
    settlement_currency_code,
    foreign_amount,
    exchange_rate,
    quote_currency_code,
    cashbook_point_id,
    cashbook_point_pot_id
  ) values (
    v_parent_tenant_id,
    p_profile_id,
    'commission',
    round(p_amount, 2),
    0.00,
    v_paid_on,
    v_method,
    coalesce(nullif(btrim(p_reference), ''), nullif(btrim(p_source_id), '')),
    p_note,
    'BDT',
    null,
    1.000000,
    'BDT',
    p_cashbook_point_id,
    v_pot_id
  ) returning * into v_pay;

  v_ledger_source_id := coalesce(nullif(btrim(p_source_id), ''), v_pay.id::text);

  perform public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_tenant_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_parent_tenant_id,
    p_type => 'debit',
    p_amount => round(p_amount, 2),
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_ledger_source_id,
    p_metadata => jsonb_build_object(
      'section', 'payout_earned',
      'purpose', 'middleman_payout_tenant_debit',
      'transaction_type', 'profit_paid_out',
      'label', 'Profit Paid Out',
      'profile_id', p_profile_id,
      'profile_name', v_profile.name,
      'payout_method', v_method,
      'notes', p_note,
      'cashbook_point_pot_id', v_pot_id,
      'pay_id', v_pay.id,
      'commission_source_id', nullif(btrim(p_source_id), '')
    ),
    p_cashbook_point_id => p_cashbook_point_id
  );

  perform public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_tenant_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'customer',
    p_entity_id => p_profile_id,
    p_type => 'debit',
    p_amount => round(p_amount, 2),
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_ledger_source_id,
    p_metadata => jsonb_build_object(
      'section', 'payout_earned',
      'purpose', 'middleman_payout_debit',
      'transaction_type', 'profit_paid_out',
      'label', 'Profit Paid Out',
      'payout_method', v_method,
      'notes', p_note,
      'pay_id', v_pay.id
    )
  );

  perform public.apply_dropship_payout_settlement_fifo(
    p_tenant_id,
    p_profile_id,
    round(p_amount, 2)
  );

  return public._kernel_finalize_pay_idempotency(v_pay.id, v_parent_tenant_id, p_idempotency_key);
end;
$$;

GRANT EXECUTE ON FUNCTION public._kernel_post_commission_payout(
  bigint, bigint, date, numeric, text, text, text, bigint, bigint, text, text
) TO authenticated, service_role;
