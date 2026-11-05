CREATE FUNCTION public.record_investor_capital_adjustment (
  p_tenant_id   bigint,
  p_investor_id bigint,
  p_amount      numeric,
  p_date        date,
  p_method      public.investor_payment_method,
  p_note        text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_source_id text := gen_random_uuid()::text;
  v_currency text := 'BDT';
  v_abs numeric(12,2);
begin
  if not public.membership_has_module_action(p_tenant_id, 'investor_capital_ledger', 'edit') then
    raise exception 'not allowed';
  end if;

  if p_amount is null or p_amount = 0 then
    raise exception 'amount must be non-zero';
  end if;

  v_abs := abs(p_amount);

  select coalesce(i.currency_code, 'BDT') into v_currency
  from public.investors i
  where i.id = p_investor_id and i.tenant_id = p_tenant_id;

  if not found then
    raise exception 'investor not found';
  end if;

  if p_amount > 0 then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => public.resolve_parent_tenant_id(p_tenant_id),
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'investor',
      p_entity_id => p_investor_id,
      p_type => 'credit',
      p_amount => v_abs,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'adjustment',
      p_source_id => v_source_id,
      p_metadata => jsonb_build_object(
        'section', 'investor_capital',
        'transaction_type', 'capital_adjustment',
        'method', p_method,
        'date', p_date,
        'notes', p_note
      )
    );
  else
    perform public.record_ledger_transaction(
      p_parent_tenant_id => public.resolve_parent_tenant_id(p_tenant_id),
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'investor',
      p_entity_id => p_investor_id,
      p_type => 'debit',
      p_amount => v_abs,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'adjustment',
      p_source_id => v_source_id,
      p_metadata => jsonb_build_object(
        'section', 'investor_capital',
        'transaction_type', 'capital_adjustment',
        'method', p_method,
        'date', p_date,
        'notes', p_note
      )
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'source_id', v_source_id,
    'tenant_id', p_tenant_id,
    'investor_id', p_investor_id,
    'amount', p_amount,
    'date', p_date,
    'method', p_method,
    'transaction_type', 'capital_adjustment',
    'note', p_note
  );
end;
$function$;

GRANT ALL ON FUNCTION public.record_investor_capital_adjustment(bigint, bigint, numeric, date, public.investor_payment_method, text) TO anon;

GRANT ALL ON FUNCTION public.record_investor_capital_adjustment(bigint, bigint, numeric, date, public.investor_payment_method, text) TO authenticated;

GRANT ALL ON FUNCTION public.record_investor_capital_adjustment(bigint, bigint, numeric, date, public.investor_payment_method, text) TO service_role;