CREATE FUNCTION public._kernel_record_pay_bill_settlement (
  p_tenant_id          bigint,
  p_payment_id         bigint,
  p_bill_id            bigint,
  p_books_amount       numeric,
  p_update_unallocated boolean DEFAULT true
)
  RETURNS public.pay_allocations
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_books := round(p_books_amount, 2);

  select * into v_bill from public.bills where id = p_bill_id;
  if v_bill.id is null then
    raise exception 'Bill not found.';
  end if;
  if v_bill.parent_tenant_id <> v_parent_id then
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
    parent_tenant_id,
    bill_id,
    allocator_kind,
    allocator_id,
    pay_allocation_id,
    allocated_txn_amount,
    allocated_books_amount,
    books_rate_at_alloc,
    fx_realized_books_delta
  ) values (
    v_bill.parent_tenant_id,
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

  insert into public.pay_allocations (tenant_id, payment_id, global_invoice_id, bill_id, amount)
  values (v_parent_id, p_payment_id, p_bill_id, p_bill_id, v_books)
  returning * into v_row;

  update public.bill_settlements
  set pay_allocation_id = v_row.id
  where id = v_settle_id;

  if p_update_unallocated then
    update public.pays
    set unallocated_amount = unallocated_amount - v_books
    where id = p_payment_id;
  end if;

  perform public.recompute_global_invoice_payment_status(p_bill_id);

  return v_row;
end;
$function$;

GRANT ALL ON FUNCTION public._kernel_record_pay_bill_settlement(bigint, bigint, bigint, numeric, boolean) TO anon;

GRANT ALL ON FUNCTION public._kernel_record_pay_bill_settlement(bigint, bigint, bigint, numeric, boolean) TO authenticated;

GRANT ALL ON FUNCTION public._kernel_record_pay_bill_settlement(bigint, bigint, bigint, numeric, boolean) TO service_role;