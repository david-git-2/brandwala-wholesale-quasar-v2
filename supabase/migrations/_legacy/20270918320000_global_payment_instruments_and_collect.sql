begin;

-- =========================================================
-- Receipt instrument lines (split tender) + collect RPC
-- =========================================================

create table if not exists public.global_payment_instruments (
  id bigserial primary key,
  payment_id bigint not null references public.global_payments(id) on delete cascade,
  payment_method_code text not null references public.payment_methods(code),
  amount numeric(12, 2) not null,
  reference text null,
  bd_bank_id bigint null references public.bd_banks(id),
  cheque_number text null,
  cheque_date date null,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  constraint global_payment_instruments_amount_positive check (amount > 0),
  constraint global_payment_instruments_cheque_fields check (
    payment_method_code <> 'CHEQUE'
    or (
      bd_bank_id is not null
      and nullif(trim(cheque_number), '') is not null
      and cheque_date is not null
    )
  )
);

create index if not exists global_payment_instruments_payment_id_idx
  on public.global_payment_instruments(payment_id);

create index if not exists global_payment_instruments_method_code_idx
  on public.global_payment_instruments(payment_method_code);

alter table public.global_payment_instruments enable row level security;

drop policy if exists superadmin_can_manage_global_payment_instruments on public.global_payment_instruments;

create policy superadmin_can_manage_global_payment_instruments
on public.global_payment_instruments
for all
to authenticated
using (public.is_superadmin())
with check (public.is_superadmin());

grant select, insert, update, delete on table public.global_payment_instruments to authenticated;
grant usage, select on sequence public.global_payment_instruments_id_seq to authenticated;

drop function if exists public.collect_wholesale_invoice_payment(bigint, numeric, text, numeric, numeric);

create or replace function public.collect_wholesale_invoice_payment(
  p_invoice_id bigint,
  p_instruments jsonb default '[]'::jsonb,
  p_wallet_amount numeric default 0,
  p_settlement_amount numeric default 0,
  p_note text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.sales_invoices;
  v_wallet numeric(12, 2);
  v_settle numeric(12, 2);
  v_cash numeric(12, 2);
  v_due numeric(12, 2);
  v_tenant_id bigint;
  v_operating_tenant_id bigint;
  v_payment_id bigint;
  v_line record;
  v_method_code text;
  v_line_amount numeric(12, 2);
  v_line_count int;
  v_header_method text;
  v_sort int := 0;
begin
  if p_invoice_id is null then
    raise exception 'Invoice ID is required';
  end if;

  v_wallet := greatest(coalesce(p_wallet_amount, 0.00), 0.00);
  v_settle := greatest(coalesce(p_settlement_amount, 0.00), 0.00);
  v_cash := 0.00;
  v_line_count := 0;

  if coalesce(jsonb_typeof(p_instruments), 'null') = 'array' then
    for v_line in
      select value, ordinality - 1 as idx
      from jsonb_array_elements(p_instruments) with ordinality
    loop
      v_method_code := upper(trim(coalesce(v_line.value ->> 'payment_method_code', '')));
      v_line_amount := round(coalesce((v_line.value ->> 'amount')::numeric, 0.00), 2);

      if v_line_amount <= 0 then
        continue;
      end if;

      if not exists (
        select 1
        from public.payment_methods pm
        where pm.code = v_method_code
          and pm.is_active = true
      ) then
        raise exception 'Invalid payment method: %', v_method_code;
      end if;

      if v_method_code = 'CHEQUE' then
        if (v_line.value ->> 'bd_bank_id') is null then
          raise exception 'Cheque line requires a bank';
        end if;
        if nullif(trim(coalesce(v_line.value ->> 'cheque_number', '')), '') is null then
          raise exception 'Cheque line requires a cheque number';
        end if;
        if (v_line.value ->> 'cheque_date') is null then
          raise exception 'Cheque line requires a cheque date';
        end if;
        if not exists (
          select 1
          from public.bd_banks b
          where b.id = (v_line.value ->> 'bd_bank_id')::bigint
            and b.is_active = true
        ) then
          raise exception 'Invalid bank for cheque line';
        end if;
      end if;

      v_cash := v_cash + v_line_amount;
      v_line_count := v_line_count + 1;
    end loop;
  end if;

  if v_cash <= 0 and v_wallet <= 0 and v_settle <= 0 then
    raise exception 'Enter at least one payment line, store credit, or settlement';
  end if;

  select * into v_invoice
  from public.sales_invoices
  where id = p_invoice_id
  for update;

  if v_invoice.id is null then
    raise exception 'Invoice not found';
  end if;

  if v_invoice.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'Payments can only be recorded on issued invoices';
  end if;

  if v_invoice.billing_profile_id is null then
    raise exception 'Billing profile is required';
  end if;

  v_due := coalesce(v_invoice.due_amount, 0.00);
  if (v_cash + v_wallet + v_settle) > v_due then
    raise exception 'Payment total cannot exceed due';
  end if;

  v_tenant_id := coalesce(v_invoice.parent_tenant_id, v_invoice.tenant_id);
  v_operating_tenant_id := coalesce(v_invoice.issued_by_tenant_id, v_tenant_id);

  if v_cash > 0 then
    if v_line_count = 1 then
      select upper(trim(coalesce(value ->> 'payment_method_code', 'CASH')))
      into v_header_method
      from jsonb_array_elements(p_instruments) as t(value)
      where round(coalesce((value ->> 'amount')::numeric, 0.00), 2) > 0
      limit 1;
      v_header_method := lower(v_header_method);
    else
      v_header_method := 'split';
    end if;

    insert into public.global_payments (
      tenant_id,
      billing_profile_id,
      amount,
      unallocated_amount,
      payment_date,
      method,
      note
    ) values (
      v_tenant_id,
      v_invoice.billing_profile_id,
      v_cash,
      0.00,
      current_date,
      v_header_method,
      nullif(trim(p_note), '')
    ) returning id into v_payment_id;

    for v_line in
      select value, ordinality - 1 as idx
      from jsonb_array_elements(p_instruments) with ordinality
    loop
      v_method_code := upper(trim(coalesce(v_line.value ->> 'payment_method_code', '')));
      v_line_amount := round(coalesce((v_line.value ->> 'amount')::numeric, 0.00), 2);

      if v_line_amount <= 0 then
        continue;
      end if;

      v_sort := v_sort + 1;

      insert into public.global_payment_instruments (
        payment_id,
        payment_method_code,
        amount,
        reference,
        bd_bank_id,
        cheque_number,
        cheque_date,
        sort_order
      ) values (
        v_payment_id,
        v_method_code,
        v_line_amount,
        nullif(trim(coalesce(v_line.value ->> 'reference', '')), ''),
        case when v_method_code = 'CHEQUE' then (v_line.value ->> 'bd_bank_id')::bigint else null end,
        case when v_method_code = 'CHEQUE' then nullif(trim(v_line.value ->> 'cheque_number'), '') else null end,
        case when v_method_code = 'CHEQUE' then (v_line.value ->> 'cheque_date')::date else null end,
        v_sort
      );
    end loop;

    insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
    values (v_tenant_id, v_payment_id, p_invoice_id, v_cash);

    update public.sales_invoices
    set paid_amount = coalesce(paid_amount, 0.00) + v_cash,
        updated_at = now()
    where id = p_invoice_id;

    perform public.recompute_global_invoice_payment_status(p_invoice_id);

    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_tenant_id,
      p_operating_tenant_id => v_operating_tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_tenant_id,
      p_type => 'credit',
      p_amount => v_cash,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'sales_invoice',
      p_source_id => v_payment_id::text,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'tenant_payment_received',
        'transaction_type', 'payment_received',
        'label', 'Payment Received',
        'invoice_id', p_invoice_id,
        'payment_id', v_payment_id,
        'method', v_header_method,
        'instrument_count', v_line_count
      )
    );
  end if;

  if v_wallet > 0 then
    insert into public.wallet_accounts (
      tenant_id, entity_type, entity_id, currency_code,
      available_balance, locked_balance, pending_balance
    ) values (
      v_tenant_id, 'customer', v_invoice.billing_profile_id, 'BDT',
      0.0000, 0.0000, 0.0000
    ) on conflict (tenant_id, entity_type, entity_id, currency_code) do nothing;

    insert into public.global_payments (
      tenant_id, billing_profile_id, amount, unallocated_amount,
      payment_date, method, note
    ) values (
      v_tenant_id, v_invoice.billing_profile_id, v_wallet, 0.00,
      current_date, 'wallet_credit',
      coalesce(nullif(trim(p_note), ''), 'Wholesale invoice collect (store credit)')
    ) returning id into v_payment_id;

    insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
    values (v_tenant_id, v_payment_id, p_invoice_id, v_wallet);

    update public.sales_invoices
    set paid_amount = coalesce(paid_amount, 0.00) + v_wallet,
        updated_at = now()
    where id = p_invoice_id;

    perform public.recompute_global_invoice_payment_status(p_invoice_id);

    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_tenant_id,
      p_operating_tenant_id => v_operating_tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_invoice.billing_profile_id,
      p_type => 'debit',
      p_amount => v_wallet,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'sales_invoice',
      p_source_id => v_payment_id::text,
      p_allow_overdraft => false,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'apply_store_credit',
        'transaction_type', 'wallet_credit',
        'label', 'Applied store credit',
        'invoice_id', p_invoice_id,
        'payment_id', v_payment_id
      )
    );
  end if;

  if v_settle > 0 then
    perform public.apply_global_invoice_settlement_discount(
      p_invoice_id,
      v_settle,
      coalesce(nullif(trim(p_note), ''), 'Wholesale collect settlement')
    );
  end if;

  select * into v_invoice from public.sales_invoices where id = p_invoice_id;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'paid_amount', v_invoice.paid_amount,
    'due_amount', v_invoice.due_amount,
    'payment_status', v_invoice.payment_status,
    'settlement_discount_amount', v_invoice.settlement_discount_amount
  );
end;
$$;

alter function public.collect_wholesale_invoice_payment(bigint, jsonb, numeric, numeric, text) owner to postgres;

grant all on function public.collect_wholesale_invoice_payment(bigint, jsonb, numeric, numeric, text) to authenticated;
grant all on function public.collect_wholesale_invoice_payment(bigint, jsonb, numeric, numeric, text) to service_role;

commit;
