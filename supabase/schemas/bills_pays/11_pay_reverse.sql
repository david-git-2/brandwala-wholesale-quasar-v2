-- BP12 + BP11 custody + WA13 bounce (source for migrations).

ALTER TABLE public.pay_instruments
  ADD COLUMN IF NOT EXISTS bounced_at timestamptz;

-- ---------------------------------------------------------------------------
-- BP12: settlements-aware payment reverse
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._kernel_reverse_payment(
  p_tenant_id bigint,
  p_payment_id bigint,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_payment public.pays;
  v_parent_id bigint;
  v_bill_id bigint;
  v_bill_ids bigint[] := '{}';
  v_leftover numeric(12, 2);
  v_reason text;
  v_shipment_ids bigint[] := '{}';
  v_sid bigint;
  v_cashbook_point_id bigint;
begin
  if p_tenant_id is null or p_payment_id is null then
    raise exception 'Tenant and payment are required.';
  end if;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  if v_reason is null then
    raise exception 'A reason is required to void a payment.';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  select * into v_payment
  from public.pays
  where id = p_payment_id
    and tenant_id = v_parent_id
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

  if v_payment.source = 'store_credit' then
    raise exception 'Store-credit application payments cannot be voided here.';
  end if;

  select coalesce(array_agg(distinct x.bid), '{}')
  into v_bill_ids
  from (
    select coalesce(pa.bill_id, pa.global_invoice_id) as bid
    from public.pay_allocations pa
    where pa.payment_id = v_payment.id
    union
    select bs.bill_id as bid
    from public.bill_settlements bs
    where bs.allocator_kind = 'pay'
      and bs.allocator_id = v_payment.id
    union
    select bs.bill_id as bid
    from public.bill_settlements bs
    join public.pay_allocations pa on pa.id = bs.pay_allocation_id
    where pa.payment_id = v_payment.id
  ) x
  where x.bid is not null;

  foreach v_bill_id in array v_bill_ids
  loop
    perform public._kernel_lock_bills(array[v_bill_id]);
    select b.ap_shipment_id into v_sid
    from public.bills b
    where b.id = v_bill_id and b.ap_shipment_id is not null;
    if v_sid is not null and not (v_sid = any(v_shipment_ids)) then
      v_shipment_ids := array_append(v_shipment_ids, v_sid);
    end if;
  end loop;

  delete from public.bill_settlements bs
  where bs.pay_allocation_id in (
    select pa.id from public.pay_allocations pa where pa.payment_id = v_payment.id
  );

  delete from public.bill_settlements bs
  where bs.allocator_kind = 'pay'
    and bs.allocator_id = v_payment.id;

  delete from public.pay_allocations
  where payment_id = v_payment.id;

  foreach v_bill_id in array v_bill_ids
  loop
    perform public.recompute_global_invoice_payment_status(v_bill_id);
  end loop;

  v_leftover := coalesce(v_payment.unallocated_amount, 0.00);

  if v_payment.source = 'ap_payout' then
    select pi.cashbook_point_id into v_cashbook_point_id
    from public.pay_instruments pi
    where pi.payment_id = v_payment.id
    order by pi.sort_order, pi.id
    limit 1;

    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_id,
      p_operating_tenant_id => coalesce(v_payment.tenant_id, p_tenant_id),
      p_entity_type => 'tenant',
      p_entity_id => v_parent_id,
      p_type => 'credit',
      p_amount => v_payment.amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'payout',
      p_source_id => v_payment.id::text,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'void_ap_payout',
        'transaction_type', 'ap_payout_reversal',
        'label', 'Void AP payout',
        'payment_id', v_payment.id,
        'reason', v_reason
      ),
      p_allow_overdraft => true,
      p_cashbook_point_id => coalesce(v_cashbook_point_id, v_payment.cashbook_point_id)
    );
  elsif v_payment.source in ('customer_cash', 'bank', 'courier_remittance') then
    if coalesce(v_payment.amount, 0.00) > 0.00 then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => v_parent_id,
        p_operating_tenant_id => p_tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => v_parent_id,
        p_type => 'debit',
        p_amount => case
          when coalesce(v_payment.source_currency_code, 'BDT') <> 'BDT'
            then coalesce(v_payment.source_amount, v_payment.amount)
          else v_payment.amount
        end,
        p_currency_code => coalesce(nullif(trim(v_payment.source_currency_code), ''), 'BDT'),
        p_exchange_rate => coalesce(v_payment.transaction_rate, 1.000000),
        p_source_type => case
          when v_payment.source = 'courier_remittance' then 'shop_order'
          else 'sales_invoice'
        end,
        p_source_id => case
          when v_payment.source = 'courier_remittance' then coalesce(v_payment.shop_order_id::text, v_payment.id::text)
          else v_payment.id::text
        end,
        p_metadata => jsonb_build_object(
          'section', 'payments',
          'purpose', 'void_batch_payment_received',
          'payment_id', v_payment.id,
          'reason', v_reason
        ),
        p_allow_overdraft => true,
        p_cashbook_point_id => v_payment.cashbook_point_id
      );
    end if;

    if v_leftover > 0.00 and v_payment.profile_id is not null
       and v_payment.source in ('customer_cash', 'bank') then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => v_parent_id,
        p_operating_tenant_id => p_tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_payment.profile_id,
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
          'reason', v_reason
        ),
        p_allow_overdraft => true
      );
    end if;
  else
    raise exception 'Cannot void payment source %.', v_payment.source;
  end if;

  update public.pays
  set
    voided_at = now(),
    note = trim(
      coalesce(note, '')
      || case when coalesce(note, '') = '' then '' else E'\n' end
      || '[VOIDED] ' || v_reason
    )
  where id = v_payment.id;

  if coalesce(array_length(v_shipment_ids, 1), 0) > 0 then
    foreach v_sid in array v_shipment_ids
    loop
      perform public.refresh_global_shipment_fx_from_ap_payments(v_sid);
    end loop;
  end if;

  return jsonb_build_object(
    'success', true,
    'payment_id', v_payment.id,
    'customer_group_id', v_payment.customer_group_id
  );
end;
$$;

CREATE OR REPLACE FUNCTION public.void_customer_receipt(
  p_tenant_id bigint,
  p_payment_id bigint,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  return public._kernel_reverse_payment(p_tenant_id, p_payment_id, p_reason);
end;
$$;

CREATE OR REPLACE FUNCTION public.reverse_pay(
  p_payment_id bigint,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_pay public.pays;
  v_reason text;
begin
  select * into v_pay from public.pays where id = p_payment_id;
  if v_pay.id is null then
    raise exception 'Payment not found.';
  end if;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  if v_reason is null then
    raise exception 'A reason is required.';
  end if;

  perform public._kernel_reverse_payment(v_pay.tenant_id, p_payment_id, v_reason);
end;
$$;

-- ---------------------------------------------------------------------------
-- BP11: profile custody → bill
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._kernel_apply_custody_to_bill(
  p_tenant_id bigint,
  p_bill_id bigint,
  p_books_amount numeric
)
RETURNS public.bill_settlements
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill public.bills;
  v_parent_id bigint;
  v_avail numeric(18, 4);
  v_books numeric(12, 2);
  v_open numeric(12, 2);
  v_row public.bill_settlements;
  v_txn numeric(12, 2);
  v_rate numeric(15, 6);
  v_delta numeric(12, 2);
  v_ledger jsonb;
  v_entry_id uuid;
  v_anchor bigint;
  v_source_key text;
begin
  if not public.membership_has_module_action(p_tenant_id, 'payments', 'allocate_payment') then
    raise exception 'Permission denied.';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_books := round(coalesce(p_books_amount, 0), 2);
  if v_books <= 0 then
    raise exception 'Amount must be greater than zero.';
  end if;

  perform public._kernel_lock_bills(array[p_bill_id]);

  select * into v_bill from public.bills where id = p_bill_id;
  if v_bill.id is null then raise exception 'Bill not found.'; end if;
  if v_bill.parent_tenant_id <> v_parent_id then raise exception 'Bill tenant mismatch.'; end if;
  if v_bill.profile_id is null then raise exception 'Bill has no profile.'; end if;
  if v_bill.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'Bill is not issued.';
  end if;
  if coalesce(v_bill.document_kind, 'standard'::public.bill_document_kind)
    <> 'standard'::public.bill_document_kind then
    raise exception 'Custody applies to standard bills only.';
  end if;

  v_open := coalesce(
    (public.get_bill_net_balances(p_bill_id)->>'open_books')::numeric,
    v_bill.due_amount,
    0
  );
  if v_books > v_open then
    raise exception 'Amount % exceeds open bill balance %.', v_books, v_open;
  end if;

  select coalesce(ca.available_balance, 0)
  into v_avail
  from public.cashbook_accounts ca
  where ca.parent_tenant_id = v_parent_id
    and ca.entity_type = 'customer'
    and ca.entity_id = v_bill.profile_id
    and ca.currency_code = 'BDT';

  if v_avail < v_books then
    raise exception 'Insufficient profile custody (available %).', v_avail;
  end if;

  v_source_key := 'custody_apply:' || p_bill_id::text || ':' || gen_random_uuid()::text;

  v_ledger := public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'customer',
    p_entity_id => v_bill.profile_id,
    p_type => 'debit',
    p_amount => v_books,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'bill_settlement',
    p_source_id => v_source_key,
    p_metadata => jsonb_build_object(
      'section', 'payments',
      'purpose', 'apply_custody_to_bill',
      'transaction_type', 'custody_apply',
      'label', 'Applied custody to bill',
      'bill_id', p_bill_id
    ),
    p_allow_overdraft => false
  );

  v_entry_id := (v_ledger->>'id')::uuid;
  v_anchor := abs(hashtext(v_entry_id::text));

  select sa.allocated_txn_amount, sa.allocated_books_amount, sa.books_rate_at_alloc, sa.fx_realized_books_delta
  into v_txn, v_books, v_rate, v_delta
  from public._kernel_settlement_amounts_from_pay_alloc(v_bill, null, v_books) sa;

  insert into public.bill_settlements (
    parent_tenant_id, bill_id, allocator_kind, allocator_id,
    allocated_txn_amount, allocated_books_amount, books_rate_at_alloc, fx_realized_books_delta
  ) values (
    v_bill.parent_tenant_id, p_bill_id, 'custody_entry', v_anchor,
    v_txn, v_books, v_rate, v_delta
  )
  returning * into v_row;

  update public.cashbook_entries
  set metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
    'bill_settlement_id', v_row.id,
    'custody_entry_uuid', v_entry_id
  )
  where id = v_entry_id;

  perform public.recompute_global_invoice_payment_status(p_bill_id);

  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- WA13: cheque bounce (whole pay)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.bounce_cheque_instrument(
  p_tenant_id bigint,
  p_instrument_id bigint,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_inst public.pay_instruments;
  v_pay public.pays;
  v_reason text;
begin
  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  if v_reason is null then
    raise exception 'A reason is required.';
  end if;

  select * into v_inst
  from public.pay_instruments
  where id = p_instrument_id
  for update;

  if v_inst.id is null then
    raise exception 'Instrument not found.';
  end if;

  if upper(trim(v_inst.payment_method_code)) <> 'CHEQUE' then
    raise exception 'Instrument is not a cheque.';
  end if;

  if v_inst.bounced_at is not null then
    raise exception 'Cheque already marked bounced.';
  end if;

  select * into v_pay from public.pays where id = v_inst.payment_id for update;
  if v_pay.voided_at is not null then
    raise exception 'Payment is already voided.';
  end if;

  update public.pay_instruments
  set bounced_at = now()
  where id = v_inst.id;

  perform public.reverse_pay(
    v_pay.id,
    'Cheque bounced: ' || v_reason
  );

  return jsonb_build_object(
    'success', true,
    'payment_id', v_pay.id,
    'instrument_id', v_inst.id
  );
end;
$$;

GRANT EXECUTE ON FUNCTION public._kernel_reverse_payment(bigint, bigint, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.reverse_pay(bigint, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._kernel_apply_custody_to_bill(bigint, bigint, numeric) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bounce_cheque_instrument(bigint, bigint, text) TO authenticated, service_role;
