-- BP11: apply_settlement hardening + recompute CN cross-apply
-- ---------------------------------------------------------------------------
-- recompute_global_invoice_payment_status (settlements-aware; BP11 CN cross-apply)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.recompute_global_invoice_payment_status(p_global_invoice_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill public.bills;
  v_root_id bigint;
  v_total numeric(12, 2);
  v_paid numeric(12, 2);
  v_written_off numeric(12, 2);
  v_credits numeric(12, 2);
  v_debits numeric(12, 2);
  v_due numeric(12, 2);
  v_child record;
  v_child_paid numeric(12, 2);
  v_child_written_off numeric(12, 2);
  v_child_cross numeric(12, 2);
  v_child_due numeric(12, 2);
  v_child_total numeric(12, 2);
begin
  select * into v_bill from public.bills where id = p_global_invoice_id;
  if not found then return; end if;

  v_root_id := coalesce(v_bill.parent_bill_id, v_bill.id);

  select * into v_bill from public.bills where id = v_root_id for update;
  if not found then return; end if;

  select coalesce(sum(bs.allocated_books_amount), 0.00) into v_paid
  from public.bill_settlements bs
  where bs.bill_id = v_root_id;

  select coalesce(sum(amount), 0.00) into v_written_off
  from public.invoice_write_offs where invoice_id = v_root_id;

  select coalesce(sum(total_amount), 0.00) into v_credits
  from public.bills
  where parent_bill_id = v_root_id
    and document_kind = 'credit_note'::public.bill_document_kind
    and invoice_status = 'issued'::public.global_invoice_status;

  select coalesce(sum(total_amount), 0.00) into v_debits
  from public.bills
  where parent_bill_id = v_root_id
    and document_kind = 'debit_note'::public.bill_document_kind
    and invoice_status = 'issued'::public.global_invoice_status;

  v_total := coalesce(v_bill.total_amount, 0.00);
  v_due := greatest(v_total - v_paid - v_written_off - v_credits + v_debits, 0.00);

  update public.bills
  set
    paid_amount = v_paid,
    written_off_amount = v_written_off,
    due_amount = v_due,
    payment_status = case
      when v_due = 0.00 and v_written_off > 0.00 then 'settled_with_write_off'
      when v_due = 0.00 and v_paid > 0.00 then 'paid'
      when v_paid > 0.00 or v_written_off > 0.00 then 'partially_paid'
      else 'due'
    end,
    updated_at = now()
  where id = v_root_id;

  for v_child in
    select id, document_kind, total_amount, invoice_status
    from public.bills
    where parent_bill_id = v_root_id
    order by id
  loop
    select coalesce(sum(bs.allocated_books_amount), 0.00) into v_child_paid
    from public.bill_settlements bs where bs.bill_id = v_child.id;

    select coalesce(sum(amount), 0.00) into v_child_written_off
    from public.invoice_write_offs where invoice_id = v_child.id;

    v_child_total := coalesce(v_child.total_amount, 0.00);
    v_child_cross := 0.00;
    if v_child.document_kind = 'credit_note'::public.bill_document_kind then
      select coalesce(sum(bs.allocated_books_amount), 0.00) into v_child_cross
      from public.bill_settlements bs
      where bs.allocator_kind = 'credit_note'
        and bs.allocator_id = v_child.id;
    end if;

    if v_child.invoice_status <> 'issued'::public.global_invoice_status then
      v_child_due := 0.00;
    elsif v_due = 0.00 and (v_written_off > 0.00 or v_paid > 0.00) then
      v_child_due := 0.00;
    else
      v_child_due := greatest(
        v_child_total - v_child_paid - v_child_written_off - v_child_cross,
        0.00
      );
    end if;

    update public.bills
    set
      paid_amount = v_child_paid,
      written_off_amount = v_child_written_off,
      due_amount = v_child_due,
      payment_status = case
        when v_child.invoice_status = 'voided'::public.global_invoice_status then 'due'
        when v_child_total <= 0.00 then 'paid'
        when v_child_due <= 0.00 and v_child_written_off > 0.00 then 'settled_with_write_off'
        when v_child_due <= 0.00 and v_due = 0.00 and v_written_off > 0.00 then 'settled_with_write_off'
        when v_child_due <= 0.00 and v_child_paid > 0.00 then 'paid'
        when v_child_paid > 0.00 then 'partially_paid'
        else 'due'
      end,
      updated_at = now()
    where id = v_child.id;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Shared pay leftover → bill (pay_allocations + settlements trigger)
-- ---------------------------------------------------------------------------
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

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);
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
  if v_invoice.parent_tenant_id <> v_parent_id then raise exception 'Bill tenant mismatch.'; end if;
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

  insert into public.pay_allocations (tenant_id, payment_id, global_invoice_id, bill_id, amount)
  values (p_tenant_id, p_payment_id, p_bill_id, p_bill_id, p_amount)
  returning * into v_row;

  update public.pays
  set unallocated_amount = unallocated_amount - p_amount
  where id = p_payment_id;

  perform public.recompute_global_invoice_payment_status(p_bill_id);

  if v_payment.profile_id is not null
    and v_payment.source in ('customer_cash', 'bank') then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => p_tenant_id,
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_payment.profile_id,
      p_type => 'debit',
      p_amount => p_amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'sales_invoice',
      p_source_id => p_payment_id::text,
      p_allow_overdraft => false,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'apply_store_credit',
        'transaction_type', 'wallet_credit',
        'label', 'Applied leftover to bill',
        'payment_id', p_payment_id,
        'bill_id', p_bill_id
      )
    );
  end if;

  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- allocate_payment: legacy wrapper (customer cash/bank only)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.allocate_payment_to_global_invoice(
  p_tenant_id bigint,
  p_payment_id bigint,
  p_global_invoice_id bigint,
  p_amount numeric
) RETURNS public.pay_allocations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  return public._kernel_apply_pay_leftover_to_bill(
    p_tenant_id,
    p_payment_id,
    p_global_invoice_id,
    p_amount,
    false
  );
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

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  if p_allocator_kind = 'pay' then
    perform public._kernel_lock_bills(array[p_bill_id]);
    v_alloc := public._kernel_apply_pay_leftover_to_bill(
      p_tenant_id,
      p_allocator_id,
      p_bill_id,
      p_books_amount,
      true
    );
    select bs.* into v_row
    from public.bill_settlements bs
    where bs.pay_allocation_id = v_alloc.id;
    if v_row.id is null then
      raise exception 'Settlement row missing after pay allocation.';
    end if;
    return v_row;
  end if;

  if p_allocator_kind <> 'credit_note' then
    raise exception 'Unsupported allocator_kind %.', p_allocator_kind;
  end if;

  perform public._kernel_lock_bills(array[p_bill_id, p_allocator_id]);

  select * into v_bill from public.bills where id = p_bill_id;
  if v_bill.id is null then raise exception 'Target bill not found.'; end if;
  if v_bill.parent_tenant_id <> v_parent_id then raise exception 'Target bill tenant mismatch.'; end if;
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
  if v_cn.parent_tenant_id <> v_parent_id then raise exception 'Credit note tenant mismatch.'; end if;
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
    parent_tenant_id, bill_id, allocator_kind, allocator_id,
    allocated_txn_amount, allocated_books_amount, books_rate_at_alloc, fx_realized_books_delta
  ) values (
    v_bill.parent_tenant_id, p_bill_id, p_allocator_kind, p_allocator_id,
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
