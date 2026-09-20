-- Receipt history list, instrument typo patch, void-and-re-enter for wholesale collect.

begin;

alter table public.global_payments
  add column if not exists voided_at timestamptz null;

create index if not exists global_payments_voided_at_idx
  on public.global_payments (voided_at)
  where voided_at is not null;

create or replace function public.list_customer_group_receipts(
  p_tenant_id bigint,
  p_customer_group_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path to public
as $$
declare
  v_parent_id bigint;
  v_result jsonb;
begin
  if p_tenant_id is null or p_customer_group_id is null then
    raise exception 'Tenant and customer group are required.';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_result
  from (
    select
      gp.id,
      gp.payment_date,
      gp.amount,
      gp.unallocated_amount,
      gp.method,
      gp.reference,
      gp.note,
      gp.voided_at,
      gp.billing_profile_id,
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'id', gpi.id,
              'payment_method_code', gpi.payment_method_code,
              'amount', gpi.amount,
              'reference', gpi.reference,
              'bd_bank_id', gpi.bd_bank_id,
              'bank_name', b.name,
              'cheque_number', gpi.cheque_number,
              'cheque_date', gpi.cheque_date,
              'sort_order', gpi.sort_order
            )
            order by gpi.sort_order, gpi.id
          )
          from public.global_payment_instruments gpi
          left join public.bd_banks b on b.id = gpi.bd_bank_id
          where gpi.payment_id = gp.id
        ),
        '[]'::jsonb
      ) as instruments,
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'invoice_id', ip.global_invoice_id,
              'invoice_no', si.invoice_no,
              'amount', ip.amount
            )
            order by si.invoice_no
          )
          from public.invoice_payments ip
          join public.sales_invoices si on si.id = ip.global_invoice_id
          where ip.payment_id = gp.id
        ),
        '[]'::jsonb
      ) as allocations
    from public.global_payments gp
    where gp.tenant_id = p_tenant_id
      and (
        gp.customer_group_id = p_customer_group_id
        or gp.billing_profile_id in (
          select bp.id from public.billing_profiles bp where bp.customer_group_id = p_customer_group_id
        )
      )
      and coalesce(gp.method, '') <> 'wallet_credit'
    order by gp.voided_at nulls first, gp.payment_date desc, gp.id desc
  ) r;

  return v_result;
end;
$$;

create or replace function public.update_payment_instrument_details(
  p_tenant_id bigint,
  p_instrument_id bigint,
  p_reference text default null,
  p_bd_bank_id bigint default null,
  p_cheque_number text default null,
  p_cheque_date date default null
)
returns jsonb
language plpgsql
security definer
set search_path to public
as $$
declare
  v_line public.global_payment_instruments;
  v_payment public.global_payments;
  v_method text;
begin
  if p_tenant_id is null or p_instrument_id is null then
    raise exception 'Tenant and instrument are required.';
  end if;

  select gpi.* into v_line
  from public.global_payment_instruments gpi
  where gpi.id = p_instrument_id;

  if v_line.id is null then
    raise exception 'Instrument line not found.';
  end if;

  select * into v_payment
  from public.global_payments gp
  where gp.id = v_line.payment_id
    and gp.tenant_id = p_tenant_id;

  if v_payment.id is null then
    raise exception 'Payment not found for tenant.';
  end if;

  if v_payment.voided_at is not null then
    raise exception 'Cannot edit a voided receipt.';
  end if;

  v_method := upper(trim(v_line.payment_method_code));

  if v_method = 'CHEQUE' then
    if p_bd_bank_id is null then
      raise exception 'Cheque line requires a bank.';
    end if;
    if nullif(trim(coalesce(p_cheque_number, '')), '') is null then
      raise exception 'Cheque line requires a cheque number.';
    end if;
    if p_cheque_date is null then
      raise exception 'Cheque line requires a cheque date.';
    end if;
    if not exists (
      select 1 from public.bd_banks b
      where b.id = p_bd_bank_id and b.is_active = true
    ) then
      raise exception 'Invalid bank for cheque line.';
    end if;
  elsif v_method = 'BANK_TRANSFER' then
    if p_bd_bank_id is null then
      raise exception 'Bank transfer line requires a bank.';
    end if;
    if not exists (
      select 1 from public.bd_banks b
      where b.id = p_bd_bank_id and b.is_active = true
    ) then
      raise exception 'Invalid bank for bank transfer line.';
    end if;
  end if;

  update public.global_payment_instruments
  set
    reference = nullif(trim(coalesce(p_reference, '')), ''),
    bd_bank_id = case when v_method in ('CHEQUE', 'BANK_TRANSFER') then p_bd_bank_id else null end,
    cheque_number = case when v_method = 'CHEQUE' then nullif(trim(coalesce(p_cheque_number, '')), '') else null end,
    cheque_date = case when v_method in ('CHEQUE', 'BANK_TRANSFER') then p_cheque_date else null end
  where id = p_instrument_id
  returning * into v_line;

  return jsonb_build_object(
    'success', true,
    'instrument_id', v_line.id,
    'payment_id', v_line.payment_id
  );
end;
$$;

create or replace function public.void_customer_receipt(
  p_tenant_id bigint,
  p_payment_id bigint,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path to public
as $$
declare
  v_payment public.global_payments;
  v_parent_id bigint;
  v_invoice_id bigint;
  v_leftover numeric(12,2);
begin
  if p_tenant_id is null or p_payment_id is null then
    raise exception 'Tenant and payment are required.';
  end if;

  if nullif(trim(coalesce(p_reason, '')), '') is null then
    raise exception 'A reason is required to void a receipt.';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  select * into v_payment
  from public.global_payments
  where id = p_payment_id
    and tenant_id = p_tenant_id
  for update;

  if v_payment.id is null then
    raise exception 'Payment not found.';
  end if;

  if v_payment.voided_at is not null then
    raise exception 'Payment is already voided.';
  end if;

  if coalesce(v_payment.method, '') = 'wallet_credit' then
    raise exception 'Store-credit application receipts cannot be voided from this screen.';
  end if;

  for v_invoice_id in
    select distinct ip.global_invoice_id
    from public.invoice_payments ip
    where ip.payment_id = v_payment.id
  loop
    delete from public.invoice_payments
    where payment_id = v_payment.id
      and global_invoice_id = v_invoice_id;
    perform public.recompute_global_invoice_payment_status(v_invoice_id);
  end loop;

  v_leftover := coalesce(v_payment.unallocated_amount, 0.00);

  if coalesce(v_payment.amount, 0.00) > 0.00 then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_id,
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_parent_id,
      p_type => 'debit',
      p_amount => v_payment.amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'sales_invoice',
      p_source_id => v_payment.id::text,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'void_batch_payment_received',
        'payment_id', v_payment.id,
        'reason', p_reason
      ),
      p_allow_overdraft => true
    );
  end if;

  if v_leftover > 0.00 and v_payment.billing_profile_id is not null then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_id,
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_payment.billing_profile_id,
      p_type => 'debit',
      p_amount => v_leftover,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'sales_invoice',
      p_source_id => v_payment.id::text,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'void_store_credit',
        'payment_id', v_payment.id,
        'reason', p_reason
      ),
      p_allow_overdraft => true
    );
  end if;

  update public.global_payments
  set
    voided_at = now(),
    note = trim(
      coalesce(note, '')
      || case when coalesce(note, '') = '' then '' else E'\n' end
      || '[VOIDED] ' || trim(p_reason)
    )
  where id = v_payment.id;

  return jsonb_build_object(
    'success', true,
    'payment_id', v_payment.id,
    'customer_group_id', v_payment.customer_group_id
  );
end;
$$;

grant execute on function public.list_customer_group_receipts(bigint, bigint) to authenticated;
grant execute on function public.list_customer_group_receipts(bigint, bigint) to service_role;
grant execute on function public.update_payment_instrument_details(bigint, bigint, text, bigint, text, date) to authenticated;
grant execute on function public.update_payment_instrument_details(bigint, bigint, text, bigint, text, date) to service_role;
grant execute on function public.void_customer_receipt(bigint, bigint, text) to authenticated;
grant execute on function public.void_customer_receipt(bigint, bigint, text) to service_role;

commit;
