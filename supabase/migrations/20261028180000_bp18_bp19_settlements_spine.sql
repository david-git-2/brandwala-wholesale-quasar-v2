-- BP18/BP19: settlements spine cutover + frozen txn face
ALTER TABLE public.bill_settlements ADD COLUMN IF NOT EXISTS pay_allocation_id bigint REFERENCES public.pay_allocations (id);
CREATE UNIQUE INDEX IF NOT EXISTS bill_settlements_pay_allocation_uidx ON public.bill_settlements (pay_allocation_id) WHERE pay_allocation_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.get_bill_net_balances(p_bill_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill public.bills;
  v_root public.bills;
  v_credits numeric(12, 2);
  v_debits numeric(12, 2);
  v_credit_due numeric(12, 2);
  v_settled numeric(12, 2);
  v_due numeric(12, 2);
  v_open_books numeric(12, 2);
  v_open_txn numeric(12, 2);
begin
  select * into v_bill from public.bills where id = p_bill_id;
  if v_bill.id is null then
    raise exception 'bill not found';
  end if;

  select * into v_root
  from public.bills
  where id = coalesce(v_bill.parent_bill_id, v_bill.id);

  select coalesce(sum(total_amount), 0.00), coalesce(sum(due_amount), 0.00)
  into v_credits, v_credit_due
  from public.bills
  where parent_bill_id = v_root.id
    and document_kind = 'credit_note'::public.bill_document_kind
    and invoice_status = 'issued'::public.global_invoice_status;

  select coalesce(sum(total_amount), 0.00) into v_debits
  from public.bills
  where parent_bill_id = v_root.id
    and document_kind = 'debit_note'::public.bill_document_kind
    and invoice_status = 'issued'::public.global_invoice_status;

  select coalesce(sum(bs.allocated_books_amount), 0.00) into v_settled
  from public.bill_settlements bs
  where bs.bill_id = v_root.id;

  v_due := greatest(
    coalesce(v_root.total_amount, 0) - v_settled - v_credits + v_debits,
    0
  );
  v_open_books := v_due;
  v_open_txn := case
    when coalesce(v_root.txn_total_amount, v_root.total_amount) is not null
      and coalesce(v_root.books_exchange_rate, 1) > 0
    then greatest(
      coalesce(v_root.txn_total_amount, v_root.total_amount)
        - coalesce((
          select sum(bs.allocated_txn_amount)
          from public.bill_settlements bs where bs.bill_id = v_root.id
        ), 0),
      0
    )
    else v_open_books
  end;

  return jsonb_build_object(
    'bill_id', v_root.id,
    'invoice_no', v_root.invoice_no,
    'original_total', v_root.total_amount,
    'paid_amount', v_settled,
    'credits_issued', v_credits,
    'debits_issued', v_debits,
    'due_amount', v_due,
    'open_books', v_open_books,
    'open_txn', v_open_txn,
    'credit_open', v_credit_due,
    'document_kind', v_bill.document_kind
  );
end;
$$;

-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public._kernel_resolve_bill_id_from_alloc(
  p_invoice_id bigint,
  p_global_invoice_id bigint,
  p_bill_id bigint
) RETURNS bigint
LANGUAGE sql IMMUTABLE AS $$
  SELECT COALESCE(p_bill_id, p_global_invoice_id, p_invoice_id);
$$;

CREATE OR REPLACE FUNCTION public._kernel_settlement_amounts_from_pay_alloc(
  p_bill public.bills,
  p_pay public.pays,
  p_alloc_books numeric
) RETURNS TABLE (
  allocated_txn_amount numeric,
  allocated_books_amount numeric,
  books_rate_at_alloc numeric,
  fx_realized_books_delta numeric
)
LANGUAGE plpgsql
STABLE
AS $$
declare
  v_books numeric(12, 2);
  v_txn numeric(12, 2);
  v_bill_rate numeric(15, 6);
  v_pay_rate numeric(15, 6);
  v_txn_ccy text;
  v_books_ccy text;
begin
  v_books := round(coalesce(p_alloc_books, 0), 2);
  v_bill_rate := coalesce(nullif(p_bill.books_exchange_rate, 0), 1.000000);
  v_txn_ccy := upper(btrim(coalesce(p_bill.txn_currency_code, p_bill.currency_code, 'BDT')));
  v_books_ccy := upper(btrim(coalesce(p_bill.currency_code, 'BDT')));

  if v_txn_ccy = v_books_ccy or v_bill_rate <= 0 then
    v_txn := v_books;
    v_pay_rate := 1.000000;
  else
    if p_pay.id is not null
       and upper(btrim(coalesce(p_pay.settlement_currency_code, 'BDT'))) <> v_books_ccy
       and coalesce(p_pay.exchange_rate, 0) > 0
    then
      v_txn := round(v_books / p_pay.exchange_rate, 2);
      v_pay_rate := p_pay.exchange_rate;
    else
      v_txn := round(v_books / v_bill_rate, 2);
      v_pay_rate := v_bill_rate;
    end if;
  end if;

  if v_txn > 0 then
    v_pay_rate := round(v_books / v_txn, 6);
  end if;

  return query
  select
    v_txn,
    v_books,
    v_pay_rate,
    v_books - round(v_txn * v_bill_rate, 2);
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_freeze_bill_txn_face(p_bill_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill public.bills;
  v_foreign numeric(12, 2);
  v_paper_ccy text;
  v_rate numeric(15, 6);
begin
  select * into v_bill from public.bills where id = p_bill_id for update;
  if v_bill.id is null then
    return;
  end if;

  v_foreign := public.ap_bill_channel_foreign_face(coalesce(v_bill.channel_meta, '{}'::jsonb));
  v_paper_ccy := public.ap_bill_channel_currency(coalesce(v_bill.channel_meta, '{}'::jsonb));

  if v_foreign is not null and v_foreign > 0 and v_paper_ccy is not null and btrim(v_paper_ccy) <> '' then
    v_rate := case
      when v_foreign > 0 then round(coalesce(v_bill.total_amount, 0) / v_foreign, 6)
      else 1.000000
    end;
    update public.bills
    set
      txn_currency_code = coalesce(txn_currency_code, upper(btrim(v_paper_ccy))),
      txn_total_amount = coalesce(txn_total_amount, v_foreign),
      books_exchange_rate = coalesce(books_exchange_rate, coalesce(nullif(v_rate, 0), 1.000000)),
      due_amount = case
        when invoice_status = 'issued'::public.global_invoice_status
          then greatest(coalesce(total_amount, 0) - coalesce(paid_amount, 0), 0)
        else due_amount
      end,
      updated_at = now()
    where id = p_bill_id;
  else
    update public.bills
    set
      txn_currency_code = coalesce(txn_currency_code, coalesce(currency_code, 'BDT')),
      txn_total_amount = coalesce(txn_total_amount, total_amount),
      books_exchange_rate = coalesce(books_exchange_rate, 1.000000),
      due_amount = case
        when invoice_status = 'issued'::public.global_invoice_status
         and coalesce(due_amount, 0) = 0
         and coalesce(total_amount, 0) > 0
          then total_amount
        else due_amount
      end,
      updated_at = now()
    where id = p_bill_id;
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_insert_settlement_from_pay_alloc()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill_id bigint;
  v_bill public.bills;
  v_pay public.pays;
  v_txn numeric(12, 2);
  v_books numeric(12, 2);
  v_rate numeric(15, 6);
  v_delta numeric(12, 2);
begin
  v_bill_id := public._kernel_resolve_bill_id_from_alloc(NEW.invoice_id, NEW.global_invoice_id, NEW.bill_id);
  if v_bill_id is null then
    return NEW;
  end if;

  select * into v_bill from public.bills where id = v_bill_id;
  if v_bill.id is null then
    return NEW;
  end if;

  select * into v_pay from public.pays where id = NEW.payment_id;

  select sa.allocated_txn_amount, sa.allocated_books_amount, sa.books_rate_at_alloc, sa.fx_realized_books_delta
  into v_txn, v_books, v_rate, v_delta
  from public._kernel_settlement_amounts_from_pay_alloc(v_bill, v_pay, NEW.amount) sa;

  if exists (select 1 from public.bill_settlements where pay_allocation_id = NEW.id) then
    return NEW;
  end if;

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
    v_bill_id,
    'pay',
    NEW.payment_id,
    NEW.id,
    v_txn,
    v_books,
    v_rate,
    v_delta
  );

  return NEW;
end;
$$;

DROP TRIGGER IF EXISTS trg_pay_allocations_bill_settlements ON public.pay_allocations;
CREATE TRIGGER trg_pay_allocations_bill_settlements
  AFTER INSERT ON public.pay_allocations
  FOR EACH ROW
  EXECUTE FUNCTION public._kernel_insert_settlement_from_pay_alloc();

CREATE OR REPLACE FUNCTION public.get_bill_net_balances(p_bill_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill public.bills;
  v_root public.bills;
  v_credits numeric(12, 2);
  v_debits numeric(12, 2);
  v_credit_due numeric(12, 2);
  v_settled numeric(12, 2);
  v_due numeric(12, 2);
  v_open_books numeric(12, 2);
  v_open_txn numeric(12, 2);
begin
  select * into v_bill from public.bills where id = p_bill_id;
  if v_bill.id is null then
    raise exception 'bill not found';
  end if;

  select * into v_root
  from public.bills
  where id = coalesce(v_bill.parent_bill_id, v_bill.id);

  select coalesce(sum(total_amount), 0.00), coalesce(sum(due_amount), 0.00)
  into v_credits, v_credit_due
  from public.bills
  where parent_bill_id = v_root.id
    and document_kind = 'credit_note'::public.bill_document_kind
    and invoice_status = 'issued'::public.global_invoice_status;

  select coalesce(sum(total_amount), 0.00) into v_debits
  from public.bills
  where parent_bill_id = v_root.id
    and document_kind = 'debit_note'::public.bill_document_kind
    and invoice_status = 'issued'::public.global_invoice_status;

  select coalesce(sum(bs.allocated_books_amount), 0.00) into v_settled
  from public.bill_settlements bs
  where bs.bill_id = v_root.id;

  v_due := greatest(
    coalesce(v_root.total_amount, 0) - v_settled - v_credits + v_debits,
    0
  );
  v_open_books := v_due;
  v_open_txn := case
    when coalesce(v_root.txn_total_amount, v_root.total_amount) is not null
      and coalesce(v_root.books_exchange_rate, 1) > 0
    then greatest(
      coalesce(v_root.txn_total_amount, v_root.total_amount)
        - coalesce((
          select sum(bs.allocated_txn_amount)
          from public.bill_settlements bs where bs.bill_id = v_root.id
        ), 0),
      0
    )
    else v_open_books
  end;

  return jsonb_build_object(
    'bill_id', v_root.id,
    'invoice_no', v_root.invoice_no,
    'original_total', v_root.total_amount,
    'paid_amount', v_settled,
    'credits_issued', v_credits,
    'debits_issued', v_debits,
    'due_amount', v_due,
    'open_books', v_open_books,
    'open_txn', v_open_txn,
    'credit_open', v_credit_due,
    'document_kind', v_bill.document_kind
  );
end;
$$;

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
declare
  v_payment public.pays;
  v_invoice public.bills;
  v_row public.pay_allocations;
  v_due numeric(12, 2);
begin
  if p_tenant_id is null or p_payment_id is null or p_global_invoice_id is null then
    raise exception 'Tenant, payment and invoice are required.';
  end if;
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Allocation amount must be greater than zero.';
  end if;

  perform public._kernel_lock_bills(array[p_global_invoice_id]);

  select * into v_payment from public.pays where id = p_payment_id for update;
  if not found then raise exception 'Payment not found.'; end if;
  if v_payment.tenant_id <> p_tenant_id then raise exception 'Payment tenant mismatch.'; end if;
  if v_payment.voided_at is not null then raise exception 'Payment is voided.'; end if;
  if v_payment.source not in ('customer_cash', 'bank') then
    raise exception 'Only customer cash/bank leftover can be allocated later.';
  end if;

  select * into v_invoice from public.bills where id = p_global_invoice_id;
  if not found then raise exception 'Invoice not found.'; end if;
  if v_invoice.parent_tenant_id <> p_tenant_id then raise exception 'Invoice tenant mismatch.'; end if;
  if v_invoice.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'Bill % is not issued', v_invoice.invoice_no;
  end if;

  if coalesce(v_invoice.profile_id, 0) <> coalesce(v_payment.profile_id, 0) then
    raise exception 'Invoice and payment billing profile mismatch.';
  end if;

  if p_amount > v_payment.unallocated_amount then
    raise exception 'Allocation amount % exceeds payment unallocated amount %.', p_amount, v_payment.unallocated_amount;
  end if;

  v_due := coalesce((public.get_bill_net_balances(p_global_invoice_id)->>'due_amount')::numeric, v_invoice.due_amount);
  if p_amount > v_due then
    raise exception 'Allocation amount % exceeds invoice remaining due balance %.', p_amount, v_due;
  end if;

  insert into public.pay_allocations (tenant_id, payment_id, global_invoice_id, bill_id, amount)
  values (p_tenant_id, p_payment_id, p_global_invoice_id, p_global_invoice_id, p_amount)
  returning * into v_row;

  update public.pays
  set unallocated_amount = unallocated_amount - p_amount
  where id = p_payment_id;

  perform public.recompute_global_invoice_payment_status(p_global_invoice_id);

  if v_payment.profile_id is not null then
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
        'bill_id', p_global_invoice_id
      )
    );
  end if;

  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.issue_bill(p_bill_id bigint)
RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill public.bills;
begin
  select * into v_bill from public.bills where id = p_bill_id for update;
  if v_bill.id is null then
    raise exception 'bill not found';
  end if;
  if v_bill.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'only draft bills can be issued';
  end if;

  update public.bills
  set
    invoice_status = 'issued'::public.global_invoice_status,
    due_amount = total_amount,
    paid_amount = 0,
    payment_status = 'due',
    updated_at = now()
  where id = p_bill_id
  returning * into v_bill;

  perform public._kernel_freeze_bill_txn_face(p_bill_id);
  select * into v_bill from public.bills where id = p_bill_id;

  return v_bill;
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
  v_row public.bill_settlements;
  v_txn numeric(12, 2);
  v_books numeric(12, 2);
  v_rate numeric(15, 6);
  v_delta numeric(12, 2);
begin
  perform public._kernel_lock_bills(array[p_bill_id]);
  select * into v_bill from public.bills where id = p_bill_id;
  if v_bill.parent_tenant_id <> public.resolve_parent_tenant_id(p_tenant_id) then
    raise exception 'tenant mismatch';
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
  return v_row;
end;
$$;

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
  v_child record;
  v_child_paid numeric(12,2);
  v_child_written_off numeric(12,2);
  v_child_due numeric(12,2);
  v_child_total numeric(12,2);
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

    if v_child.invoice_status <> 'issued'::public.global_invoice_status then
      v_child_due := 0.00;
    elsif v_due = 0.00 and (v_written_off > 0.00 or v_paid > 0.00) then
      v_child_due := 0.00;
    else
      v_child_due := greatest(v_child_total - v_child_paid - v_child_written_off, 0.00);
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

CREATE OR REPLACE FUNCTION "public"."post_ap_payout_with_allocations"("p_tenant_id" bigint, "p_profile_id" bigint, "p_paid_on" "date", "p_cashbook_point_id" bigint, "p_note" "text" DEFAULT NULL::"text", "p_reference" "text" DEFAULT NULL::"text", "p_instruments" "jsonb" DEFAULT '[]'::"jsonb", "p_allocations" "jsonb" DEFAULT '[]'::"jsonb", "p_settlement_currency_code" "text" DEFAULT 'BDT'::"text", "p_foreign_amount" numeric DEFAULT NULL::numeric, "p_exchange_rate" numeric DEFAULT NULL::numeric, "p_source_currency_code" "text" DEFAULT NULL::"text", "p_transaction_rate" numeric DEFAULT NULL::numeric, "p_cashbook_point_pot_id" bigint DEFAULT NULL::bigint) RETURNS "public"."pays"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
  v_received_on date := coalesce(p_paid_on, current_date);
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_reference text := nullif(trim(coalesce(p_reference, '')), '');
  v_pay public.pays;
  v_line record;
  v_method_code text;
  v_line_amount numeric(12, 2);
  v_line_count int := 0;
  v_amount numeric(12, 2) := 0.00;
  v_header_method text;
  v_alloc jsonb;
  v_bill public.bills;
  v_bill_id bigint;
  v_alloc_amount numeric(12, 2);
  v_total_alloc numeric(12, 2) := 0.00;
  v_settle_currency text := 'BDT';
  v_foreign_amt numeric(12, 2);
  v_fx_rate numeric(15, 6) := 1.000000;
  v_shipment_ids bigint[] := '{}';
  v_sid bigint;
  v_leftover numeric(12, 2);
  v_channel_meta jsonb;
  v_foreign_face numeric(12, 2);
  v_paper_currency text;
  v_effective_due numeric(12, 2);
  v_paper jsonb;
  v_books_total numeric(12, 2);
  v_source_currency text;
  v_transaction_rate numeric(15, 6) := 1.000000;
  v_source_amount numeric(12, 2);
  v_pot_id bigint := p_cashbook_point_pot_id;
  v_payment_face numeric(12, 2);
  v_base_currency text := 'BDT';
begin
  if p_tenant_id is null then
    raise exception 'Tenant is required';
  end if;
  if p_profile_id is null then
    raise exception 'Profile is required';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_base_currency := public.resolve_tenant_base_currency_code(p_tenant_id);

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_parent_id)
    or public.membership_has_module_action(p_tenant_id, 'payments', 'collect_payment')
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: cannot record AP payouts for this tenant';
  end if;

  if not exists (
    select 1 from public.profiles pr
    where pr.id = p_profile_id and pr.parent_tenant_id = v_parent_id
  ) then
    raise exception 'Profile % does not belong to these books', p_profile_id;
  end if;

  if p_cashbook_point_id is null then
    raise exception 'Choose a cash point for this pay out';
  end if;

  if not exists (
    select 1
    from public.cashbook_points cp
    join public.cashbook_accounts ca on ca.id = cp.cashbook_account_id
    where cp.id = p_cashbook_point_id
      and cp.is_active = true
      and ca.parent_tenant_id = v_parent_id
      and ca.entity_type = 'tenant'
      and ca.entity_id = v_parent_id
  ) then
    raise exception 'Invalid cash point for this tenant';
  end if;

  if coalesce(jsonb_typeof(p_instruments), 'null') = 'array' then
    for v_line in select value from jsonb_array_elements(p_instruments)
    loop
      v_line_amount := round(coalesce((v_line.value ->> 'amount')::numeric, 0.00), 2);
      if v_line_amount <= 0 then
        continue;
      end if;
      v_method_code := upper(trim(coalesce(v_line.value ->> 'payment_method_code', '')));
      v_amount := v_amount + v_line_amount;
      v_line_count := v_line_count + 1;
      if v_line_count = 1 then
        v_header_method := lower(v_method_code);
      else
        v_header_method := 'split';
      end if;
    end loop;
  end if;

  if v_line_count = 0 then
    raise exception 'Enter at least one payment line';
  end if;

  if v_header_method is not null and v_header_method not in (
    'cash', 'bank', 'bank_transfer', 'mobile_banking', 'bkash', 'nagad', 'other', 'cheque', 'rocket',
    'upay', 'tap', 'card_pos', 'wire_transfer', 'paypal', 'stripe', 'letter_of_credit', 'cod', 'split'
  ) then
    v_header_method := 'other';
  end if;

  select n.settlement_currency_code, n.foreign_amount, n.exchange_rate, n.amount_bdt
  into v_settle_currency, v_foreign_amt, v_fx_rate, v_amount
  from public.normalize_pay_settlement_fx(
    v_amount,
    p_settlement_currency_code,
    p_foreign_amount,
    p_exchange_rate,
    v_base_currency
  ) n;

  v_source_currency := upper(trim(coalesce(p_source_currency_code, '')));
  if v_source_currency = '' then
    select upper(cpp.currency_code)
    into v_source_currency
    from public.cashbook_point_pots cpp
    where cpp.cashbook_point_id = p_cashbook_point_id
      and cpp.parent_tenant_id = v_parent_id
    order by case when upper(cpp.currency_code) = 'BDT' then 0 else 1 end, cpp.id
    limit 1;
  end if;

  if v_pot_id is null and coalesce(v_source_currency, '') <> '' then
    select cpp.id
    into v_pot_id
    from public.cashbook_point_pots cpp
    where cpp.cashbook_point_id = p_cashbook_point_id
      and cpp.parent_tenant_id = v_parent_id
      and upper(cpp.currency_code) = v_source_currency
    limit 1;
  end if;

  if upper(v_settle_currency) = v_source_currency then
    v_transaction_rate := 1.000000;
  else
    v_transaction_rate := coalesce(p_transaction_rate, 0);
    if v_transaction_rate <= 0 then
      raise exception 'transaction_rate required when source currency (%) differs from payment currency (%)',
        v_source_currency, v_settle_currency;
    end if;
  end if;

  if upper(v_settle_currency) = v_base_currency then
    v_payment_face := v_amount;
  else
    v_payment_face := coalesce(v_foreign_amt, 0);
  end if;

  v_source_amount := round(v_payment_face * v_transaction_rate, 2);

  insert into public.pays (
    tenant_id, profile_id, source, amount, unallocated_amount,
    payment_date, method, reference, note,
    settlement_currency_code, foreign_amount, exchange_rate, quote_currency_code, cashbook_point_id,
    source_currency_code, transaction_rate, source_amount, cashbook_point_pot_id
  ) values (
    v_parent_id, p_profile_id, 'ap_payout', v_amount, 0,
    v_received_on, v_header_method, v_reference, v_note,
    v_settle_currency, v_foreign_amt, v_fx_rate, v_base_currency, p_cashbook_point_id,
    v_source_currency, v_transaction_rate, v_source_amount, v_pot_id
  ) returning * into v_pay;

  perform public.insert_global_payment_instruments(v_pay.id, p_instruments);

  update public.pay_instruments pi
  set cashbook_point_id = coalesce(pi.cashbook_point_id, p_cashbook_point_id)
  where pi.payment_id = v_pay.id;

  if coalesce(jsonb_typeof(p_allocations), 'null') = 'array' then
    for v_alloc in select value from jsonb_array_elements(p_allocations)
    loop
      v_bill_id := coalesce(nullif(v_alloc ->> 'bill_id', '')::bigint, nullif(v_alloc ->> 'invoice_id', '')::bigint);
      v_alloc_amount := round(coalesce((v_alloc ->> 'amount')::numeric, 0.00), 2);
      if v_bill_id is null or v_alloc_amount <= 0 then
        continue;
      end if;

      select * into v_bill from public.bills where id = v_bill_id for update;
      if v_bill.id is null then
        raise exception 'Bill % not found', v_bill_id;
      end if;
      if v_bill.parent_tenant_id <> v_parent_id then
        raise exception 'Bill % belongs to other books', v_bill_id;
      end if;
      if v_bill.invoice_type <> 'ap'::public.global_invoice_type then
        raise exception 'Bill % is not AP', v_bill.invoice_no;
      end if;
      if v_bill.invoice_status <> 'issued'::public.global_invoice_status then
        raise exception 'Bill % is not issued', v_bill.invoice_no;
      end if;
      if v_bill.profile_id is distinct from p_profile_id then
        raise exception 'Bill % is billed to a different profile', v_bill.invoice_no;
      end if;

      v_channel_meta := coalesce(v_bill.channel_meta, '{}'::jsonb);
      v_foreign_face := public.ap_bill_channel_foreign_face(v_channel_meta);
      v_paper_currency := public.ap_bill_channel_currency(v_channel_meta);

      if upper(v_settle_currency) <> v_base_currency
         and v_fx_rate > 0
         and v_foreign_face is not null
         and v_foreign_face > 0
         and upper(coalesce(v_paper_currency, v_base_currency)) <> v_base_currency
      then
        if v_alloc_amount <= v_foreign_face + 0.01
           and v_alloc_amount < v_amount * 0.99
        then
          v_alloc_amount := round(v_alloc_amount * v_fx_rate, 2);
        end if;

        if abs(coalesce(v_bill.due_amount, 0) - v_foreign_face) < 0.02 then
          v_effective_due := round(v_foreign_face * v_fx_rate, 2);
        else
          v_effective_due := coalesce(v_bill.due_amount, 0);
        end if;
      else
        v_effective_due := coalesce(v_bill.due_amount, 0);
      end if;

      if v_alloc_amount > v_effective_due then
        raise exception 'Allocation % exceeds bill % due %', v_alloc_amount, v_bill.invoice_no, v_effective_due;
      end if;

      insert into public.pay_allocations (tenant_id, payment_id, global_invoice_id, bill_id, amount)
      values (v_parent_id, v_pay.id, v_bill_id, v_bill_id, v_alloc_amount);

      perform public.recompute_global_invoice_payment_status(v_bill_id);
      v_total_alloc := v_total_alloc + v_alloc_amount;

      if v_bill.ap_shipment_id is not null
         and not (v_bill.ap_shipment_id = any(v_shipment_ids)) then
        v_shipment_ids := array_append(v_shipment_ids, v_bill.ap_shipment_id);
      end if;
    end loop;
  end if;

  if v_total_alloc > v_amount then
    raise exception 'AP payout allocations (%) exceed payment amount (%)', v_total_alloc, v_amount;
  end if;

  v_leftover := v_amount - v_total_alloc;

  update public.pays
  set unallocated_amount = v_leftover
  where id = v_pay.id
  returning * into v_pay;

  perform public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_parent_id,
    p_type => 'debit',
    p_amount => v_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_pay.id::text,
    p_metadata => jsonb_build_object(
      'section', 'payments',
      'purpose', 'ap_payout',
      'transaction_type', 'ap_paid_out',
      'label', 'AP paid out',
      'payment_id', v_pay.id,
      'method', v_header_method,
      'reference', v_reference,
      'settlement_currency_code', v_settle_currency,
      'foreign_amount', v_foreign_amt,
      'exchange_rate', v_fx_rate,
      'source_currency_code', v_source_currency,
      'transaction_rate', v_transaction_rate,
      'source_amount', v_source_amount,
      'cashbook_point_pot_id', v_pot_id
    ),
    p_allow_overdraft => true,
    p_cashbook_point_id => p_cashbook_point_id
  );

  if coalesce(array_length(v_shipment_ids, 1), 0) > 0 then
    foreach v_sid in array v_shipment_ids
    loop
      perform public.refresh_global_shipment_fx_from_ap_payments(v_sid);
      perform public.stamp_global_shipment_landed_costs(v_sid);
    end loop;
  end if;

  return v_pay;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."post_sales_invoice"("p_invoice_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.bills;
  v_item public.global_invoice_items%rowtype;
  v_unit_cost numeric;
  v_mov_id bigint;
  v_mov_no text;
  v_parent_id bigint;
  v_eff_tenant_id bigint;
  v_stock record;
  v_qty integer;
  v_delivery_kind text;
  v_held_stock_id bigint;
begin
  select * into v_invoice from public.bills where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status not in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status) then
    raise exception 'only draft or proforma invoices can be posted/issued';
  end if;

  if not exists (select 1 from public.global_invoice_items where invoice_id = p_invoice_id) then
    raise exception 'cannot post an empty invoice';
  end if;

  v_eff_tenant_id := coalesce(v_invoice.issued_by_tenant_id, v_invoice.parent_tenant_id);
  v_parent_id := coalesce(v_invoice.parent_tenant_id, v_invoice.issued_by_tenant_id);

  if v_invoice.invoice_type = 'wholesale'::public.global_invoice_type then
    if v_invoice.profile_id is null then
      raise exception 'billing profile is required for wholesale invoices';
    end if;
  elsif v_invoice.invoice_type = 'retail'::public.global_invoice_type then
    if v_invoice.retail_billing_mode = 'account'::public.retail_billing_mode then
      if v_invoice.profile_id is null then
        raise exception 'billing profile is required for retail account invoices';
      end if;
    elsif v_invoice.retail_billing_mode = 'direct'::public.retail_billing_mode then
      if v_invoice.profile_id is not null then
        raise exception 'billing profile must be null for retail direct invoices';
      end if;
    end if;
    if nullif(trim(v_invoice.recipient_name), '') is null or
       nullif(trim(v_invoice.recipient_phone), '') is null or
       nullif(trim(v_invoice.recipient_address), '') is null then
      raise exception 'recipient name, phone, and address are required for retail invoices';
    end if;
  elsif v_invoice.invoice_type = 'dropship'::public.global_invoice_type then
    if v_invoice.profile_id is null then
      raise exception 'billing profile is required for dropship invoices';
    end if;
    if nullif(trim(v_invoice.recipient_name), '') is null or
       nullif(trim(v_invoice.recipient_phone), '') is null or
       nullif(trim(v_invoice.recipient_address), '') is null then
      raise exception 'recipient name, phone, and address are required for dropship invoices';
    end if;
  end if;

  v_delivery_kind := lower(trim(coalesce(v_invoice.channel_meta->>'delivery_kind', 'take')));
  if v_delivery_kind not in ('take', 'condition') then
    v_delivery_kind := 'take';
  end if;

  if v_invoice.invoice_type = 'wholesale'::public.global_invoice_type
     and v_delivery_kind = 'condition' then
    for v_item in select * from public.global_invoice_items where invoice_id = p_invoice_id loop
      v_qty := ceil(v_item.quantity)::integer;

      select * into v_stock from public.global_stocks where id = v_item.global_stock_id for update;
      if v_stock.id is null then
        continue;
      end if;

      if v_stock.quantity < v_qty then
        raise exception 'insufficient stock quantity on stock % (requested %, available %)',
          v_item.global_stock_id, v_qty, v_stock.quantity;
      end if;

      if v_stock.availability = 'sellable'::public.stock_availability then
        perform public.create_and_post_stock_movement(
          p_tenant_id => v_parent_id,
          p_stock_id => v_item.global_stock_id,
          p_quantity => v_qty,
          p_to_availability => 'held'::public.stock_availability,
          p_movement_type => 'availability_transfer'::public.stock_movement_type,
          p_notes => 'Condition bill #' || coalesce(v_invoice.invoice_no, p_invoice_id::text),
          p_reference_type => 'sales_invoice',
          p_reference_id => p_invoice_id::text
        );

        select gs.id
        into v_held_stock_id
        from public.global_stocks gs
        where gs.shipment_item_id = v_stock.shipment_item_id
          and gs.availability = 'held'::public.stock_availability
          and gs.location_id = v_stock.location_id
          and gs.grade_tag_id = coalesce(v_stock.grade_tag_id, public.default_stock_grade_tag_id())
        order by gs.id desc
        limit 1;

        if v_held_stock_id is null then
          raise exception 'held stock not found after condition transfer for line %', v_item.id;
        end if;

        update public.bill_lines
        set global_stock_id = v_held_stock_id
        where id = v_item.id;
      elsif v_stock.availability <> 'held'::public.stock_availability then
        raise exception 'condition bill stock % must be sellable or held (current: %)',
          v_item.global_stock_id, v_stock.availability;
      end if;
    end loop;
  else
    v_mov_no := 'MOV-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('public.stock_movements_id_seq')::text, 6, '0');

    insert into public.stock_movements (
      tenant_id,
      movement_no,
      movement_type,
      reference_type,
      reference_id,
      notes,
      created_by_email,
      is_posted,
      posted_at
    ) values (
      v_parent_id,
      v_mov_no,
      'adjustment'::public.stock_movement_type,
      'sales_invoice',
      p_invoice_id::text,
      'Issued ' || upper(v_invoice.invoice_type::text) || ' Invoice #' || coalesce(v_invoice.invoice_no, p_invoice_id::text),
      public.current_user_email(),
      true,
      now()
    ) returning id into v_mov_id;

    for v_item in select * from public.global_invoice_items where invoice_id = p_invoice_id loop
      v_qty := ceil(v_item.quantity)::integer;

      select * into v_stock from public.global_stocks where id = v_item.global_stock_id for update;
      if v_stock.id is not null then
        if v_invoice.invoice_type = 'dropship'::public.global_invoice_type
           and v_stock.availability <> 'held'::public.stock_availability then
          raise exception 'dropship invoice stock % must be held before issue', v_item.global_stock_id;
        end if;

        if v_stock.quantity < v_qty then
          raise exception 'insufficient stock quantity on stock % (requested %, available %)',
            v_item.global_stock_id, v_qty, v_stock.quantity;
        end if;

        update public.global_stocks
        set quantity = quantity - v_qty
        where id = v_item.global_stock_id;

        insert into public.stock_movement_lines (
          movement_id,
          stock_id,
          quantity,
          from_location_id,
          to_location_id,
          from_availability,
          to_availability
        ) values (
          v_mov_id,
          v_item.global_stock_id,
          v_qty,
          v_stock.location_id,
          v_stock.location_id,
          v_stock.availability,
          v_stock.availability
        );
      end if;
    end loop;
  end if;

  update public.bills
  set invoice_status = 'issued'::public.global_invoice_status
  where id = p_invoice_id;

  perform public._kernel_freeze_bill_txn_face(p_invoice_id);
  perform public.recompute_global_invoice_payment_status(p_invoice_id);

  if v_invoice.invoice_type = 'retail'::public.global_invoice_type
     and v_invoice.profile_id is not null
     and coalesce(v_invoice.total_amount, 0) > 0
  then
    if not exists (
      select 1 from public.cashbook_entries
      where source_type = 'sales_invoice'
        and source_id = p_invoice_id::text
        and entity_type = 'customer'
        and entity_id = v_invoice.profile_id
        and metadata->>'transaction_type' = 'invoice_billed'
    ) then
      perform public.record_ledger_transaction(
        p_tenant_id => v_eff_tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_invoice.profile_id,
        p_type => 'debit',
        p_amount => v_invoice.total_amount,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'sales_invoice',
        p_source_id => p_invoice_id::text,
        p_metadata => jsonb_build_object(
          'section', 'invoices',
          'purpose', 'invoice_billed',
          'transaction_type', 'invoice_billed',
          'label', 'Invoice Billed',
          'invoice_no', v_invoice.invoice_no,
          'invoice_id', v_invoice.id,
          'invoice_type', v_invoice.invoice_type
        )
      );
    end if;
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."issue_shipment_ap_bill_for_kind"("p_shipment_id" bigint, "p_ap_kind" "text") RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent bigint;
  v_bill_id bigint;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  if p_ap_kind is null or trim(p_ap_kind) = '' then
    raise exception 'ap_kind is required';
  end if;

  if p_ap_kind not in (
    'vendor', 'cargo', 'local',
    'material', 'freight', 'customs', 'handling', 'finance', 'other'
  ) then
    raise exception 'Invalid ap_kind %', p_ap_kind;
  end if;

  select gs.parent_tenant_id into v_parent
  from public.global_shipments gs
  where gs.id = p_shipment_id;

  if v_parent is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_parent)
  ) then
    raise exception 'Permission denied';
  end if;

  update public.bills b
  set
    invoice_status = 'issued'::public.global_invoice_status,
    payment_status = coalesce(nullif(b.payment_status, ''), 'due'),
    source_type = coalesce(b.source_type, 'shipment_cost'),
    source_id = coalesce(b.source_id, p_shipment_id::text),
    source_key = coalesce(b.source_key, p_ap_kind),
    updated_at = now()
  where b.parent_tenant_id = v_parent
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and b.invoice_status = 'draft'::public.global_invoice_status
    and coalesce(b.total_amount, 0) > 0
    and (
      (
        b.source_type = 'shipment_cost'
        and b.source_id = p_shipment_id::text
        and b.source_key = p_ap_kind
      )
      or (b.ap_shipment_id = p_shipment_id and b.ap_kind = p_ap_kind)
    )
  returning b.id into v_bill_id;

  if v_bill_id is null then
    raise exception 'No draft AP bill to issue for bucket %', p_ap_kind;
  end if;

  perform public._kernel_freeze_bill_txn_face(v_bill_id);
  perform public.recompute_global_invoice_payment_status(v_bill_id);

  return v_bill_id;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."finalize_dropship_order_bills_at_delivered"("p_order_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_invoice public.bills;
  v_sync jsonb;
  v_ap jsonb;
  v_notes jsonb;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.global_invoice_id is null then
    return jsonb_build_object('success', false, 'error', 'customer invoice is required before deliver');
  end if;

  select * into v_invoice from public.bills where id = v_order.global_invoice_id for update;
  if v_invoice.id is null then
    return jsonb_build_object('success', false, 'error', 'linked customer invoice not found');
  end if;

  if v_invoice.invoice_status not in (
    'draft'::public.global_invoice_status,
    'issued'::public.global_invoice_status
  ) then
    return jsonb_build_object(
      'success', false,
      'error', format('customer invoice must be draft or issued (current: %s)', v_invoice.invoice_status)
    );
  end if;

  if v_invoice.invoice_status = 'draft'::public.global_invoice_status then
    v_sync := public.sync_dropship_tenant_b2b_invoice_from_order(p_order_id);
    if coalesce(v_sync->>'success', 'false') <> 'true' then
      return v_sync;
    end if;
  end if;

  v_ap := public.upsert_dropship_courier_ap_bill(p_order_id, false);
  if coalesce(v_ap->>'success', 'false') <> 'true' then
    return v_ap;
  end if;

  select * into v_invoice from public.bills where id = v_order.global_invoice_id;
  if v_invoice.invoice_status = 'draft'::public.global_invoice_status then
    perform public.post_sales_invoice(v_invoice.id);
    perform public.sync_sales_invoice_charges_from_header(v_invoice.id);
  end if;

  update public.bills b
  set invoice_status = 'issued'::public.global_invoice_status, updated_at = now()
  where b.parent_tenant_id = v_invoice.parent_tenant_id
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and (
      (b.source_type = 'dropship_courier' and b.source_id = p_order_id::text)
      or (
        b.source_type = 'shop_order'
        and b.source_id = p_order_id::text
        and coalesce(b.source_key, '') = 'courier'
      )
    )
    and b.invoice_status = 'draft'::public.global_invoice_status;

  perform public._kernel_freeze_bill_txn_face(b.id)
  from public.bills b
  where b.parent_tenant_id = v_invoice.parent_tenant_id
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and (
      (b.source_type = 'dropship_courier' and b.source_id = p_order_id::text)
      or (
        b.source_type = 'shop_order'
        and b.source_id = p_order_id::text
        and coalesce(b.source_key, '') = 'courier'
      )
    )
    and b.invoice_status = 'issued'::public.global_invoice_status;

  v_notes := public.apply_dropship_issued_bill_notes_at_deliver(p_order_id);
  if coalesce(v_notes->>'success', 'false') <> 'true' then
    return v_notes;
  end if;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_order.global_invoice_id,
    'courier_ap_bill_id', (v_ap->>'bill_id')::bigint,
    'bill_notes', v_notes
  );
end;
$$;


-- Link legacy settlement rows to pay_allocation where unambiguous
UPDATE public.bill_settlements bs
SET pay_allocation_id = pa.id
FROM public.pay_allocations pa
WHERE bs.pay_allocation_id IS NULL
  AND bs.allocator_kind = 'pay'
  AND bs.allocator_id = pa.payment_id
  AND bs.bill_id = public._kernel_resolve_bill_id_from_alloc(pa.invoice_id, pa.global_invoice_id, pa.bill_id)
  AND bs.allocated_books_amount = pa.amount
  AND NOT EXISTS (
    SELECT 1 FROM public.bill_settlements bs2 WHERE bs2.pay_allocation_id = pa.id
  );
