CREATE FUNCTION public._kernel_apply_custody_to_bill (
  p_tenant_id    bigint,
  p_bill_id      bigint,
  p_books_amount numeric
)
  RETURNS public.bill_settlements
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public._kernel_apply_custody_to_bill(bigint, bigint, numeric) TO anon;

GRANT ALL ON FUNCTION public._kernel_apply_custody_to_bill(bigint, bigint, numeric) TO authenticated;

GRANT ALL ON FUNCTION public._kernel_apply_custody_to_bill(bigint, bigint, numeric) TO service_role;