begin;

-- Extend collect + batch payment RPCs: received date, bank transfer bank/date on instrument lines.

drop function if exists public.collect_wholesale_invoice_payment(bigint, jsonb, numeric, numeric, text);

create or replace function public.collect_wholesale_invoice_payment(
  p_invoice_id bigint,
  p_instruments jsonb default '[]'::jsonb,
  p_wallet_amount numeric default 0,
  p_settlement_amount numeric default 0,
  p_note text default null,
  p_received_on date default null
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
  v_received_on date := coalesce(p_received_on, current_date);
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
        select 1 from public.payment_methods pm
        where pm.code = v_method_code and pm.is_active = true
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
      end if;

      if v_method_code = 'BANK_TRANSFER' and (v_line.value ->> 'bd_bank_id') is null then
        raise exception 'Bank transfer line requires a bank';
      end if;

      if v_method_code in ('CHEQUE', 'BANK_TRANSFER') and not exists (
        select 1 from public.bd_banks b
        where b.id = (v_line.value ->> 'bd_bank_id')::bigint and b.is_active = true
      ) then
        raise exception 'Invalid bank on payment line';
      end if;

      v_cash := v_cash + v_line_amount;
      v_line_count := v_line_count + 1;
    end loop;
  end if;

  if v_cash <= 0 and v_wallet <= 0 and v_settle <= 0 then
    raise exception 'Enter at least one payment line, store credit, or settlement';
  end if;

  select * into v_invoice from public.sales_invoices where id = p_invoice_id for update;

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
      tenant_id, billing_profile_id, amount, unallocated_amount,
      payment_date, method, note
    ) values (
      v_tenant_id, v_invoice.billing_profile_id, v_cash, 0.00,
      v_received_on, v_header_method, nullif(trim(p_note), '')
    ) returning id into v_payment_id;

    for v_line in
      select value from jsonb_array_elements(p_instruments)
    loop
      v_method_code := upper(trim(coalesce(v_line.value ->> 'payment_method_code', '')));
      v_line_amount := round(coalesce((v_line.value ->> 'amount')::numeric, 0.00), 2);
      if v_line_amount <= 0 then continue; end if;

      v_sort := v_sort + 1;
      insert into public.global_payment_instruments (
        payment_id, payment_method_code, amount, reference,
        bd_bank_id, cheque_number, cheque_date, sort_order
      ) values (
        v_payment_id,
        v_method_code,
        v_line_amount,
        nullif(trim(coalesce(v_line.value ->> 'reference', '')), ''),
        case when v_method_code in ('CHEQUE', 'BANK_TRANSFER') then (v_line.value ->> 'bd_bank_id')::bigint else null end,
        case when v_method_code = 'CHEQUE' then nullif(trim(v_line.value ->> 'cheque_number'), '') else null end,
        case
          when v_method_code in ('CHEQUE', 'BANK_TRANSFER') then (v_line.value ->> 'cheque_date')::date
          else null
        end,
        v_sort
      );
    end loop;

    insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
    values (v_tenant_id, v_payment_id, p_invoice_id, v_cash);

    update public.sales_invoices
    set paid_amount = coalesce(paid_amount, 0.00) + v_cash, updated_at = now()
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
      v_received_on, 'wallet_credit',
      coalesce(nullif(trim(p_note), ''), 'Wholesale invoice collect (store credit)')
    ) returning id into v_payment_id;

    insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
    values (v_tenant_id, v_payment_id, p_invoice_id, v_wallet);

    update public.sales_invoices
    set paid_amount = coalesce(paid_amount, 0.00) + v_wallet, updated_at = now()
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
      p_invoice_id, v_settle, coalesce(nullif(trim(p_note), ''), 'Wholesale collect settlement')
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

grant all on function public.collect_wholesale_invoice_payment(bigint, jsonb, numeric, numeric, text, date) to authenticated;
grant all on function public.collect_wholesale_invoice_payment(bigint, jsonb, numeric, numeric, text, date) to service_role;

drop function if exists public.record_batch_customer_payment(bigint, bigint, bigint, numeric, date, text, text, text, jsonb, jsonb);

create or replace function public.record_batch_customer_payment(
  p_tenant_id bigint,
  p_customer_group_id bigint default null,
  p_billing_profile_id bigint default null,
  p_amount numeric default 0,
  p_payment_date date default current_date,
  p_method text default 'bank_transfer',
  p_reference text default null,
  p_note text default null,
  p_allocations jsonb default '[]'::jsonb,
  p_write_offs jsonb default '[]'::jsonb,
  p_instruments jsonb default '[]'::jsonb
) returns jsonb
language plpgsql security definer
set search_path to public
as $$
declare
  v_parent_id bigint;
  v_payment public.global_payments;
  v_alloc jsonb;
  v_wo jsonb;
  v_invoice_id bigint;
  v_alloc_amount numeric(12,2);
  v_wo_amount numeric(12,2);
  v_wo_reason text;
  v_wo_note text;
  v_total_alloc numeric(12,2) := 0.00;
  v_total_wo numeric(12,2) := 0.00;
  v_primary_bp_id bigint := p_billing_profile_id;
  v_amount numeric(12,2) := coalesce(p_amount, 0.00);
  v_line record;
  v_method_code text;
  v_line_amount numeric(12,2);
  v_line_count int := 0;
  v_header_method text := lower(coalesce(p_method, 'bank_transfer'));
  v_sort int := 0;
begin
  if p_tenant_id is null then
    raise exception 'Tenant is required.';
  end if;

  if coalesce(jsonb_typeof(p_instruments), 'null') = 'array' then
    v_amount := 0.00;
    for v_line in select value from jsonb_array_elements(p_instruments)
    loop
      v_method_code := upper(trim(coalesce(v_line.value ->> 'payment_method_code', '')));
      v_line_amount := round(coalesce((v_line.value ->> 'amount')::numeric, 0.00), 2);
      if v_line_amount <= 0 then continue; end if;

      if not exists (select 1 from public.payment_methods pm where pm.code = v_method_code and pm.is_active = true) then
        raise exception 'Invalid payment method: %', v_method_code;
      end if;
      if v_method_code = 'CHEQUE' and (
        (v_line.value ->> 'bd_bank_id') is null
        or nullif(trim(coalesce(v_line.value ->> 'cheque_number', '')), '') is null
        or (v_line.value ->> 'cheque_date') is null
      ) then
        raise exception 'Cheque line requires bank, cheque number, and date';
      end if;
      if v_method_code = 'BANK_TRANSFER' and (v_line.value ->> 'bd_bank_id') is null then
        raise exception 'Bank transfer line requires a bank';
      end if;

      v_amount := v_amount + v_line_amount;
      v_line_count := v_line_count + 1;
    end loop;

    if v_line_count = 1 then
      select lower(upper(trim(coalesce(value ->> 'payment_method_code', 'CASH'))))
      into v_header_method
      from jsonb_array_elements(p_instruments) as t(value)
      where round(coalesce((value ->> 'amount')::numeric, 0.00), 2) > 0
      limit 1;
    elsif v_line_count > 1 then
      v_header_method := 'split';
    end if;
  end if;

  if v_amount < 0 then
    raise exception 'Payment amount cannot be negative.';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  if v_primary_bp_id is null and p_customer_group_id is not null then
    select id into v_primary_bp_id
    from public.billing_profiles
    where customer_group_id = p_customer_group_id
    limit 1;
  end if;

  insert into public.global_payments (
    tenant_id, customer_group_id, billing_profile_id, amount, unallocated_amount,
    payment_date, method, reference, note
  ) values (
    p_tenant_id, p_customer_group_id, v_primary_bp_id, v_amount, v_amount,
    coalesce(p_payment_date, current_date), v_header_method, p_reference, p_note
  ) returning * into v_payment;

  if v_line_count > 0 then
    for v_line in select value from jsonb_array_elements(p_instruments)
    loop
      v_method_code := upper(trim(coalesce(v_line.value ->> 'payment_method_code', '')));
      v_line_amount := round(coalesce((v_line.value ->> 'amount')::numeric, 0.00), 2);
      if v_line_amount <= 0 then continue; end if;
      v_sort := v_sort + 1;
      insert into public.global_payment_instruments (
        payment_id, payment_method_code, amount, reference,
        bd_bank_id, cheque_number, cheque_date, sort_order
      ) values (
        v_payment.id, v_method_code, v_line_amount,
        nullif(trim(coalesce(v_line.value ->> 'reference', '')), ''),
        case when v_method_code in ('CHEQUE', 'BANK_TRANSFER') then (v_line.value ->> 'bd_bank_id')::bigint else null end,
        case when v_method_code = 'CHEQUE' then nullif(trim(v_line.value ->> 'cheque_number'), '') else null end,
        case when v_method_code in ('CHEQUE', 'BANK_TRANSFER') then (v_line.value ->> 'cheque_date')::date else null end,
        v_sort
      );
    end loop;
  end if;

  if jsonb_typeof(coalesce(p_allocations, '[]'::jsonb)) = 'array' then
    for v_alloc in select * from jsonb_array_elements(p_allocations)
    loop
      v_invoice_id := (v_alloc->>'invoice_id')::bigint;
      v_alloc_amount := coalesce((v_alloc->>'amount')::numeric, 0.00);
      if v_invoice_id is not null and v_alloc_amount > 0.00 then
        insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
        values (p_tenant_id, v_payment.id, v_invoice_id, v_alloc_amount);
        perform public.recompute_global_invoice_payment_status(v_invoice_id);
        v_total_alloc := v_total_alloc + v_alloc_amount;
      end if;
    end loop;
  end if;

  if jsonb_typeof(coalesce(p_write_offs, '[]'::jsonb)) = 'array' then
    for v_wo in select * from jsonb_array_elements(p_write_offs)
    loop
      v_invoice_id := (v_wo->>'invoice_id')::bigint;
      v_wo_amount := coalesce((v_wo->>'amount')::numeric, 0.00);
      v_wo_reason := coalesce(v_wo->>'reason', 'dispute_settlement');
      v_wo_note := v_wo->>'note';
      if v_invoice_id is not null and v_wo_amount > 0.00 then
        insert into public.invoice_write_offs (
          tenant_id, parent_tenant_id, invoice_id, payment_id, amount, reason, note, approved_by
        ) values (
          p_tenant_id, v_parent_id, v_invoice_id, v_payment.id, v_wo_amount, v_wo_reason, v_wo_note, auth.uid()
        );
        perform public.recompute_global_invoice_payment_status(v_invoice_id);
        v_total_wo := v_total_wo + v_wo_amount;
      end if;
    end loop;
  end if;

  if v_total_alloc > v_amount then
    raise exception 'Total allocations (% BDT) exceed payment received (% BDT).', v_total_alloc, v_amount;
  end if;

  update public.global_payments
  set unallocated_amount = v_amount - v_total_alloc
  where id = v_payment.id;

  if v_amount > 0.00 then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_id,
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_parent_id,
      p_type => 'credit',
      p_amount => v_amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'sales_invoice',
      p_source_id => v_payment.id::text,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'batch_payment_received',
        'payment_id', v_payment.id,
        'customer_group_id', p_customer_group_id,
        'reference', p_reference
      )
    );

    if v_primary_bp_id is not null then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => v_parent_id,
        p_operating_tenant_id => p_tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_primary_bp_id,
        p_type => 'credit',
        p_amount => v_amount,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'sales_invoice',
        p_source_id => v_payment.id::text,
        p_metadata => jsonb_build_object(
          'section', 'payments',
          'purpose', 'customer_ar_reduction',
          'payment_id', v_payment.id,
          'reference', p_reference
        )
      );
    end if;
  end if;

  return jsonb_build_object(
    'payment_id', v_payment.id,
    'total_amount', v_amount,
    'total_allocated', v_total_alloc,
    'total_written_off', v_total_wo,
    'unallocated_amount', v_amount - v_total_alloc,
    'payment_date', v_payment.payment_date,
    'reference', v_payment.reference
  );
end;
$$;

grant execute on function public.record_batch_customer_payment(bigint, bigint, bigint, numeric, date, text, text, text, jsonb, jsonb, jsonb) to authenticated;
grant execute on function public.record_batch_customer_payment(bigint, bigint, bigint, numeric, date, text, text, text, jsonb, jsonb, jsonb) to service_role;

commit;
