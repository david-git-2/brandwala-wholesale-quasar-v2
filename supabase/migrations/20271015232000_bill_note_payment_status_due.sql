-- Credit/debit notes stay due until pay allocations settle them (not auto-marked paid).

CREATE OR REPLACE FUNCTION "public"."recompute_global_invoice_payment_status"("p_global_invoice_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_bill public.bills;
  v_root_id bigint;
  v_total numeric(12,2);
  v_paid numeric(12,2);
  v_written_off numeric(12,2);
  v_credits numeric(12,2);
  v_debits numeric(12,2);
  v_due numeric(12,2);
  v_parent_remaining numeric(12,2);
  v_child record;
  v_child_paid numeric(12,2);
  v_child_due numeric(12,2);
  v_child_total numeric(12,2);
begin
  select * into v_bill from public.bills where id = p_global_invoice_id;
  if not found then return; end if;

  v_root_id := coalesce(v_bill.parent_bill_id, v_bill.id);

  select * into v_bill from public.bills where id = v_root_id for update;
  if not found then return; end if;

  select coalesce(sum(amount), 0.00) into v_paid
  from public.pay_allocations where global_invoice_id = v_root_id;

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
  v_parent_remaining := greatest(v_total - v_paid - v_written_off, 0.00);
  v_due := greatest(v_parent_remaining - v_credits + v_debits, 0.00);

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
    select coalesce(sum(amount), 0.00) into v_child_paid
    from public.pay_allocations where global_invoice_id = v_child.id;

    v_child_total := coalesce(v_child.total_amount, 0.00);

    if v_child.invoice_status <> 'issued'::public.global_invoice_status then
      v_child_due := 0.00;
    else
      v_child_due := greatest(v_child_total - v_child_paid, 0.00);
    end if;

    update public.bills
    set
      paid_amount = v_child_paid,
      due_amount = v_child_due,
      payment_status = case
        when v_child.invoice_status = 'voided'::public.global_invoice_status then 'due'
        when v_child_total <= 0.00 then 'paid'
        when v_child_due <= 0.00 and v_child_paid > 0.00 then 'paid'
        when v_child_paid > 0.00 then 'partially_paid'
        else 'due'
      end,
      updated_at = now()
    where id = v_child.id;
  end loop;
end;
$$;

do $$
declare
  v_parent_id bigint;
begin
  for v_parent_id in
    select distinct b.parent_bill_id
    from public.bills b
    where b.parent_bill_id is not null
      and b.document_kind in (
        'credit_note'::public.bill_document_kind,
        'debit_note'::public.bill_document_kind
      )
      and b.invoice_status = 'issued'::public.global_invoice_status
  loop
    perform public.recompute_global_invoice_payment_status(v_parent_id);
  end loop;
end;
$$;
