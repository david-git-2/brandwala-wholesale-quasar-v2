-- Customer / dropship cash out: tenant debit must name cash point + pot.
DROP FUNCTION IF EXISTS public.dispense_middleman_payout_from_tenant(bigint, bigint, numeric, text, text);
CREATE OR REPLACE FUNCTION "public"."dispense_middleman_payout_from_tenant"("p_tenant_id" bigint, "p_profile_id" bigint, "p_amount" numeric, "p_payout_method" "text" DEFAULT 'bank_transfer'::"text", "p_reference_notes" "text" DEFAULT NULL::"text", "p_cashbook_point_id" bigint DEFAULT NULL::bigint, "p_cashbook_point_pot_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_profile public.profiles;
  v_payout_id text;
  v_parent_tenant_id bigint;
  v_pot_id bigint := p_cashbook_point_pot_id;
begin
  if p_tenant_id is null then
    return jsonb_build_object('success', false, 'error', 'Tenant ID is required');
  end if;

  if p_profile_id is null then
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

  select * into v_profile
  from public.profiles
  where id = p_profile_id
    and profile_type = 'customer'::public.profile_party_type;

  if v_profile.id is null or not public.profile_valid_for_issuer(p_profile_id, p_tenant_id) then
    return jsonb_build_object('success', false, 'error', format('Customer profile #%s not found for tenant %s', p_profile_id, p_tenant_id));
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_payout_id := 'PO-' || gen_random_uuid()::text;

  if p_cashbook_point_id is null then
    return jsonb_build_object('success', false, 'error', 'Choose a cash point for this pay out');
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
    return jsonb_build_object('success', false, 'error', 'Invalid cash point for this tenant');
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
    return jsonb_build_object('success', false, 'error', 'No currency pot at this cash point');
  end if;

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
      'profile_id', p_profile_id,
      'profile_name', v_profile.name,
      'payout_method', p_payout_method,
      'notes', p_reference_notes,
      'cashbook_point_pot_id', v_pot_id
    ),
    p_cashbook_point_id => p_cashbook_point_id
  );

  perform public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_tenant_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'customer',
    p_entity_id => p_profile_id,
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
    p_profile_id,
    p_amount
  );

  return jsonb_build_object(
    'success', true,
    'payout_id', v_payout_id,
    'profile_id', p_profile_id,
    'amount', p_amount
  );
end;
$$;

GRANT ALL ON FUNCTION public.dispense_middleman_payout_from_tenant(bigint, bigint, numeric, text, text, bigint, bigint) TO authenticated;
GRANT ALL ON FUNCTION public.dispense_middleman_payout_from_tenant(bigint, bigint, numeric, text, text, bigint, bigint) TO service_role;
