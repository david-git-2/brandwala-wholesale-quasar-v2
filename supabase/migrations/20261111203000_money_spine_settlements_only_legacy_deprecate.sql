-- money-spine-v2: settlements-only alloc; legacy table deprecation
-- Legacy money kernel deprecation (money-spine-v2).
-- Apply via backend:schema:sync when cutover blockers in docs/features/bills_pays/00-gaps.md are cleared.
-- Phase 1: comments + revoke client DML. Phase 2: DROP (uncomment bottom).

COMMENT ON TABLE public.cashbook_entries IS
  'DEPRECATED money-spine-v2: parallel ledger; drop after cutover. See docs/features/bills_pays/money-spine-v2/06-legacy-drop.md';

COMMENT ON TABLE public.pay_allocations IS
  'DEPRECATED money-spine-v2: replaced by bill_settlements; drop after cutover.';

COMMENT ON TABLE public.pay_instruments IS
  'DEPRECATED money-spine-v2: drop after cheque meta on pays; see 06-legacy-drop.md';

COMMENT ON TABLE public.money_purposes IS
  'DEPRECATED money-spine-v2: replaced by pays.kind + bill_kind_registry; drop after cutover.';

COMMENT ON TABLE public.invoice_write_offs IS
  'DEPRECATED money-spine-v2: use bills.written_off_amount; backfill 07-backfill-cutover.sql.';

COMMENT ON TABLE public.sales_invoice_counters IS
  'DEPRECATED money-spine-v2: use invoice_no_counters when v2 counter table exists.';

REVOKE INSERT, UPDATE, DELETE ON public.pay_allocations FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.cashbook_entries FROM authenticated;

CREATE OR REPLACE FUNCTION public._kernel_record_pay_bill_settlement(
  p_tenant_id bigint,
  p_payment_id bigint,
  p_bill_id bigint,
  p_books_amount numeric,
  p_update_unallocated boolean DEFAULT true
) RETURNS public.pay_allocations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill public.bills;
  v_pay public.pays;
  v_row public.pay_allocations;
  v_settle_id bigint;
  v_txn numeric(12, 2);
  v_books numeric(12, 2);
  v_rate numeric(15, 6);
  v_delta numeric(12, 2);
  v_parent_id bigint;
begin
  if p_tenant_id is null or p_payment_id is null or p_bill_id is null then
    raise exception 'Tenant, payment and bill are required.';
  end if;
  if coalesce(p_books_amount, 0) <= 0 then
    raise exception 'Settlement amount must be greater than zero.';
  end if;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);
  v_books := round(p_books_amount, 2);

  select * into v_bill from public.bills where id = p_bill_id;
  if v_bill.id is null then
    raise exception 'Bill not found.';
  end if;
  if v_bill.tenant_id <> v_parent_id then
    raise exception 'Bill tenant mismatch.';
  end if;

  select * into v_pay from public.pays where id = p_payment_id;
  if v_pay.id is null then
    raise exception 'Payment not found.';
  end if;
  if v_pay.tenant_id <> p_tenant_id then
    raise exception 'Payment tenant mismatch.';
  end if;

  select sa.allocated_txn_amount, sa.allocated_books_amount, sa.books_rate_at_alloc, sa.fx_realized_books_delta
  into v_txn, v_books, v_rate, v_delta
  from public._kernel_settlement_amounts_from_pay_alloc(v_bill, v_pay, v_books) sa;

  insert into public.bill_settlements (
    tenant_id,
    bill_id,
    allocator_kind,
    allocator_id,
    pay_allocation_id,
    allocated_txn_amount,
    allocated_books_amount,
    books_rate_at_alloc,
    fx_realized_books_delta
  ) values (
    v_bill.tenant_id,
    p_bill_id,
    'pay',
    p_payment_id,
    null,
    v_txn,
    v_books,
    v_rate,
    v_delta
  )
  returning id into v_settle_id;

  -- v2 cutover: settlements-only; pay_allocations retired (see docs/features/bills_pays/money-spine-v2/06-legacy-drop.md)
  v_row.id := v_settle_id;
  v_row.tenant_id := v_parent_id;
  v_row.payment_id := p_payment_id;
  v_row.global_invoice_id := p_bill_id;
  v_row.bill_id := p_bill_id;
  v_row.amount := v_books;
  v_row.created_at := now();

  if p_update_unallocated then
    update public.pays
    set unallocated_amount = unallocated_amount - v_books
    where id = p_payment_id;
  end if;

  perform public.recompute_global_invoice_payment_status(p_bill_id);

  return v_row;
end;
$$;
CREATE OR REPLACE FUNCTION public._kernel_apply_pay_leftover_to_bill(
  p_tenant_id bigint,
  p_payment_id bigint,
  p_bill_id bigint,
  p_amount numeric,
  p_allow_ap_payout boolean DEFAULT false
) RETURNS public.pay_allocations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_payment public.pays;
  v_invoice public.bills;
  v_row public.pay_allocations;
  v_due numeric(12, 2);
  v_parent_id bigint;
begin
  if p_tenant_id is null or p_payment_id is null or p_bill_id is null then
    raise exception 'Tenant, payment and bill are required.';
  end if;
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Allocation amount must be greater than zero.';
  end if;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);
  perform public._kernel_lock_bills(array[p_bill_id]);

  select * into v_payment from public.pays where id = p_payment_id for update;
  if not found then raise exception 'Payment not found.'; end if;
  if v_payment.tenant_id <> p_tenant_id then raise exception 'Payment tenant mismatch.'; end if;
  if v_payment.voided_at is not null then raise exception 'Payment is voided.'; end if;

  if p_allow_ap_payout then
    if v_payment.source not in ('customer_cash', 'bank', 'ap_payout') then
      raise exception 'Payment source % cannot apply leftover to bills.', v_payment.source;
    end if;
  elsif v_payment.source not in ('customer_cash', 'bank') then
    raise exception 'Only customer cash/bank leftover can be allocated later.';
  end if;

  select * into v_invoice from public.bills where id = p_bill_id;
  if not found then raise exception 'Bill not found.'; end if;
  if v_invoice.tenant_id <> v_parent_id then raise exception 'Bill tenant mismatch.'; end if;
  if v_invoice.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'Bill % is not issued', v_invoice.invoice_no;
  end if;
  if coalesce(v_invoice.document_kind, 'standard'::public.bill_document_kind)
    <> 'standard'::public.bill_document_kind then
    raise exception 'Leftover can only apply to standard bills.';
  end if;
  if v_invoice.parent_bill_id is not null then
    raise exception 'Leftover applies to the main bill, not adjustment notes.';
  end if;

  if coalesce(v_invoice.profile_id, 0) <> coalesce(v_payment.profile_id, 0) then
    raise exception 'Bill and payment billing profile mismatch.';
  end if;

  if p_amount > v_payment.unallocated_amount then
    raise exception 'Allocation amount % exceeds payment unallocated amount %.', p_amount, v_payment.unallocated_amount;
  end if;

  v_due := coalesce(
    (public.get_bill_net_balances(p_bill_id)->>'open_books')::numeric,
    (public.get_bill_net_balances(p_bill_id)->>'due_amount')::numeric,
    v_invoice.due_amount
  );
  if p_amount > v_due then
    raise exception 'Allocation amount % exceeds bill remaining due %.', p_amount, v_due;
  end if;

  v_row := public._kernel_record_pay_bill_settlement(
    p_tenant_id,
    p_payment_id,
    p_bill_id,
    p_amount,
    true
  );

  return v_row;
end;
$$;

CREATE OR REPLACE FUNCTION public.apply_settlement_to_bill(
  p_tenant_id bigint,
  p_bill_id bigint,
  p_allocator_kind text,
  p_allocator_id bigint,
  p_books_amount numeric
) RETURNS public.bill_settlements
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill public.bills;
  v_cn public.bills;
  v_row public.bill_settlements;
  v_alloc public.pay_allocations;
  v_txn numeric(12, 2);
  v_books numeric(12, 2);
  v_rate numeric(15, 6);
  v_delta numeric(12, 2);
  v_parent_id bigint;
  v_target_due numeric(12, 2);
  v_cn_open numeric(12, 2);
begin
  if not public.membership_has_module_action(p_tenant_id, 'payments', 'allocate_payment') then
    raise exception 'Permission denied.';
  end if;
  if coalesce(p_books_amount, 0) <= 0 then
    raise exception 'Settlement amount must be greater than zero.';
  end if;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);

  if p_allocator_kind = 'pay' then
    perform public._kernel_lock_bills(array[p_bill_id]);
    perform public._kernel_apply_pay_leftover_to_bill(
      p_tenant_id,
      p_allocator_id,
      p_bill_id,
      p_books_amount,
      true
    );
    select bs.* into v_row
    from public.bill_settlements bs
    where bs.tenant_id = v_parent_id
      and bs.bill_id = p_bill_id
      and bs.allocator_kind = 'pay'
      and bs.allocator_id = p_allocator_id
    order by bs.id desc
    limit 1;
    if v_row.id is null then
      raise exception 'Settlement row missing after pay allocation.';
    end if;
    return v_row;
  end if;

  if p_allocator_kind = 'custody_entry' then
    return public._kernel_apply_custody_to_bill(p_tenant_id, p_bill_id, p_books_amount);
  end if;

  if p_allocator_kind <> 'credit_note' then
    raise exception 'Unsupported allocator_kind %.', p_allocator_kind;
  end if;

  perform public._kernel_lock_bills(array[p_bill_id, p_allocator_id]);

  select * into v_bill from public.bills where id = p_bill_id;
  if v_bill.id is null then raise exception 'Target bill not found.'; end if;
  if v_bill.tenant_id <> v_parent_id then raise exception 'Target bill tenant mismatch.'; end if;
  if v_bill.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'Target bill is not issued.';
  end if;
  if coalesce(v_bill.document_kind, 'standard'::public.bill_document_kind)
    <> 'standard'::public.bill_document_kind then
    raise exception 'Credit can only apply to standard bills.';
  end if;
  if v_bill.parent_bill_id is not null then
    raise exception 'Credit applies to a main bill, not adjustment notes.';
  end if;

  select * into v_cn from public.bills where id = p_allocator_id;
  if v_cn.id is null then raise exception 'Credit note not found.'; end if;
  if v_cn.tenant_id <> v_parent_id then raise exception 'Credit note tenant mismatch.'; end if;
  if v_cn.document_kind <> 'credit_note'::public.bill_document_kind then
    raise exception 'Allocator is not a credit note.';
  end if;
  if v_cn.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'Credit note is not issued.';
  end if;
  if coalesce(v_cn.profile_id, 0) <> coalesce(v_bill.profile_id, 0) then
    raise exception 'Credit note and target bill profile mismatch.';
  end if;

  perform public.recompute_global_invoice_payment_status(v_cn.id);
  select * into v_cn from public.bills where id = p_allocator_id;
  v_cn_open := coalesce(v_cn.due_amount, 0.00);
  if p_books_amount > v_cn_open then
    raise exception 'Amount % exceeds open credit note balance %.', p_books_amount, v_cn_open;
  end if;

  v_target_due := coalesce(
    (public.get_bill_net_balances(p_bill_id)->>'open_books')::numeric,
    (public.get_bill_net_balances(p_bill_id)->>'due_amount')::numeric,
    v_bill.due_amount
  );
  if p_books_amount > v_target_due then
    raise exception 'Amount % exceeds target bill due %.', p_books_amount, v_target_due;
  end if;

  select sa.allocated_txn_amount, sa.allocated_books_amount, sa.books_rate_at_alloc, sa.fx_realized_books_delta
  into v_txn, v_books, v_rate, v_delta
  from public._kernel_settlement_amounts_from_pay_alloc(v_bill, null, p_books_amount) sa;

  insert into public.bill_settlements (
    tenant_id, bill_id, allocator_kind, allocator_id,
    allocated_txn_amount, allocated_books_amount, books_rate_at_alloc, fx_realized_books_delta
  ) values (
    v_bill.tenant_id, p_bill_id, p_allocator_kind, p_allocator_id,
    v_txn, v_books, v_rate, v_delta
  )
  returning * into v_row;

  perform public.recompute_global_invoice_payment_status(p_bill_id);
  if v_cn.parent_bill_id is not null then
    perform public.recompute_global_invoice_payment_status(v_cn.parent_bill_id);
  else
    perform public.recompute_global_invoice_payment_status(v_cn.id);
  end if;

  return v_row;
end;
$$;
