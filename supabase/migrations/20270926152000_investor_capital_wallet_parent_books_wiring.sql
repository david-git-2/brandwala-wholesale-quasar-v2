-- Wire investor capital RPCs to parent-books record_ledger_transaction API.
begin;
create or replace function public.record_investor_capital_in(
  p_tenant_id bigint,
  p_investor_id bigint,
  p_amount numeric,
  p_date date,
  p_method public.investor_payment_method,
  p_note text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_source_id text := gen_random_uuid()::text;
  v_currency text := 'BDT';
begin
  if not public.membership_has_module_action(p_tenant_id, 'investor_capital_ledger', 'create') then
    raise exception 'not allowed';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'amount must be positive';
  end if;

  select coalesce(i.currency_code, 'BDT') into v_currency
  from public.investors i
  where i.id = p_investor_id and i.tenant_id = p_tenant_id;

  if not found then
    raise exception 'investor not found';
  end if;

  perform public.record_ledger_transaction(
    p_parent_tenant_id => public.resolve_parent_tenant_id(p_tenant_id),
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => p_tenant_id,
    p_type => 'credit',
    p_amount => p_amount,
    p_currency_code => v_currency,
    p_exchange_rate => 1.000000,
    p_source_type => 'adjustment',
    p_source_id => v_source_id,
    p_metadata => jsonb_build_object(
      'section', 'investor_capital',
      'purpose', 'capital_in_tenant_cash',
      'transaction_type', 'capital_in',
      'label', 'Capital In Deposit',
      'investor_id', p_investor_id,
      'method', p_method,
      'date', p_date,
      'notes', p_note
    )
  );

  perform public.record_ledger_transaction(
    p_parent_tenant_id => public.resolve_parent_tenant_id(p_tenant_id),
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'investor',
    p_entity_id => p_investor_id,
    p_type => 'credit',
    p_amount => p_amount,
    p_currency_code => v_currency,
    p_exchange_rate => 1.000000,
    p_source_type => 'adjustment',
    p_source_id => v_source_id,
    p_metadata => jsonb_build_object(
      'section', 'investor_capital',
      'purpose', 'capital_in_investor_liability',
      'transaction_type', 'capital_in',
      'label', 'Capital Injected',
      'method', p_method,
      'date', p_date,
      'notes', p_note
    )
  );

  return jsonb_build_object(
    'ok', true,
    'source_id', v_source_id,
    'tenant_id', p_tenant_id,
    'investor_id', p_investor_id,
    'amount', p_amount,
    'date', p_date,
    'method', p_method,
    'transaction_type', 'capital_in',
    'note', p_note
  );
end;
$$;

create or replace function public.record_investor_withdrawal_paid(
  p_tenant_id bigint,
  p_investor_id bigint,
  p_amount numeric,
  p_date date,
  p_method public.investor_payment_method,
  p_note text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_source_id text := gen_random_uuid()::text;
  v_currency text := 'BDT';
begin
  if not public.membership_has_module_action(p_tenant_id, 'investor_capital_ledger', 'create') then
    raise exception 'not allowed';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'amount must be positive';
  end if;

  select coalesce(i.currency_code, 'BDT') into v_currency
  from public.investors i
  where i.id = p_investor_id and i.tenant_id = p_tenant_id;

  if not found then
    raise exception 'investor not found';
  end if;

  perform public.record_ledger_transaction(
    p_parent_tenant_id => public.resolve_parent_tenant_id(p_tenant_id),
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'investor',
    p_entity_id => p_investor_id,
    p_type => 'debit',
    p_amount => p_amount,
    p_currency_code => v_currency,
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_source_id,
    p_metadata => jsonb_build_object(
      'section', 'investor_capital',
      'purpose', 'investor_withdrawal_debit',
      'transaction_type', 'withdrawal_paid',
      'label', 'Capital Withdrawal Paid',
      'method', p_method,
      'date', p_date,
      'notes', p_note
    )
  );

  perform public.record_ledger_transaction(
    p_parent_tenant_id => public.resolve_parent_tenant_id(p_tenant_id),
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => p_tenant_id,
    p_type => 'debit',
    p_amount => p_amount,
    p_currency_code => v_currency,
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_source_id,
    p_metadata => jsonb_build_object(
      'section', 'investor_capital',
      'purpose', 'tenant_investor_cash_outflow',
      'transaction_type', 'withdrawal_paid',
      'label', 'Investor Withdrawal Outflow',
      'investor_id', p_investor_id,
      'method', p_method,
      'date', p_date,
      'notes', p_note
    )
  );

  return jsonb_build_object(
    'ok', true,
    'source_id', v_source_id,
    'tenant_id', p_tenant_id,
    'investor_id', p_investor_id,
    'amount', p_amount,
    'date', p_date,
    'method', p_method,
    'transaction_type', 'withdrawal_paid',
    'note', p_note
  );
end;
$$;

create or replace function public.record_investor_capital_adjustment(
  p_tenant_id bigint,
  p_investor_id bigint,
  p_amount numeric,
  p_date date,
  p_method public.investor_payment_method,
  p_note text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
$$;
commit;
