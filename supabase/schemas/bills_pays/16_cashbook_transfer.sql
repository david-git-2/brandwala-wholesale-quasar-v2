-- BP15-t: move cash between tenant cash points (same currency pot v1)

CREATE OR REPLACE FUNCTION public.transfer_cashbook_point(
  p_tenant_id bigint,
  p_from_point_id bigint,
  p_to_point_id bigint,
  p_currency_code text,
  p_amount numeric,
  p_note text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_parent_id bigint;
  v_ccy text := upper(trim(coalesce(p_currency_code, 'BDT')));
  v_amt numeric(12, 2);
  v_from public.cashbook_points;
  v_to public.cashbook_points;
  v_from_pot_id bigint;
  v_to_pot_id bigint;
  v_transfer_id text := gen_random_uuid()::text;
  v_note text := nullif(trim(coalesce(p_note, '')), '');
begin
  if p_tenant_id is null then
    raise exception 'Tenant is required.';
  end if;
  if p_from_point_id is null or p_to_point_id is null then
    raise exception 'From and to cash points are required.';
  end if;
  if p_from_point_id = p_to_point_id then
    raise exception 'From and to cash points must differ.';
  end if;

  v_amt := round(coalesce(p_amount, 0), 2);
  if v_amt <= 0 then
    raise exception 'Transfer amount must be greater than zero.';
  end if;
  if v_ccy = '' then
    v_ccy := 'BDT';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  if not public.membership_has_module_action(p_tenant_id, 'payments', 'collect_payment') then
    raise exception 'Permission denied.';
  end if;

  select * into v_from
  from public.cashbook_points cp
  where cp.id = p_from_point_id
    and cp.parent_tenant_id = v_parent_id
    and cp.is_active = true;

  if v_from.id is null then
    raise exception 'From cash point not found or inactive.';
  end if;

  select * into v_to
  from public.cashbook_points cp
  where cp.id = p_to_point_id
    and cp.parent_tenant_id = v_parent_id
    and cp.is_active = true;

  if v_to.id is null then
    raise exception 'To cash point not found or inactive.';
  end if;

  v_from_pot_id := public._kernel_ensure_cashbook_point_pot(v_parent_id, p_from_point_id, v_ccy);
  v_to_pot_id := public._kernel_ensure_cashbook_point_pot(v_parent_id, p_to_point_id, v_ccy);

  perform public._kernel_lock_cashbook_points_for_transfer(
    p_from_point_id,
    p_to_point_id,
    v_ccy
  );

  perform public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_parent_id,
    p_type => 'debit',
    p_amount => v_amt,
    p_currency_code => v_ccy,
    p_exchange_rate => 1.000000,
    p_source_type => 'point_transfer',
    p_source_id => v_transfer_id,
    p_metadata => jsonb_build_object(
      'section', 'cashbook',
      'purpose', 'point_transfer_out',
      'transaction_type', 'point_transfer',
      'label', 'Cash moved out',
      'from_point_id', p_from_point_id,
      'to_point_id', p_to_point_id,
      'note', v_note,
      'cashbook_point_pot_id', v_from_pot_id
    ),
    p_allow_overdraft => true,
    p_cashbook_point_id => p_from_point_id
  );

  perform public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_parent_id,
    p_type => 'credit',
    p_amount => v_amt,
    p_currency_code => v_ccy,
    p_exchange_rate => 1.000000,
    p_source_type => 'point_transfer',
    p_source_id => v_transfer_id,
    p_metadata => jsonb_build_object(
      'section', 'cashbook',
      'purpose', 'point_transfer_in',
      'transaction_type', 'point_transfer',
      'label', 'Cash moved in',
      'from_point_id', p_from_point_id,
      'to_point_id', p_to_point_id,
      'note', v_note,
      'cashbook_point_pot_id', v_to_pot_id
    ),
    p_allow_overdraft => false,
    p_cashbook_point_id => p_to_point_id
  );

  return jsonb_build_object(
    'success', true,
    'transfer_id', v_transfer_id,
    'amount', v_amt,
    'currency_code', v_ccy,
    'from_point_id', p_from_point_id,
    'to_point_id', p_to_point_id
  );
end;
$$;

GRANT EXECUTE ON FUNCTION public.transfer_cashbook_point(
  bigint, bigint, bigint, text, numeric, text
) TO authenticated, service_role;
