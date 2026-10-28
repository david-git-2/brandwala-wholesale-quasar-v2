-- BP18-c: settlements-first pay→bill writers

DROP TRIGGER IF EXISTS trg_pay_allocations_bill_settlements ON public.pay_allocations;
DROP FUNCTION IF EXISTS public._kernel_insert_settlement_from_pay_alloc();

-- from supabase/schemas/bills_pays/05_money_spine.sql
-- Bills & pays money kernel spine (BP18–BP25, BP9, BP22 partial).
-- Applied via migration 20261027220000_bills_pays_money_spine.sql

-- ---------------------------------------------------------------------------
-- BP20: source plug unique (exclude voided)
-- ---------------------------------------------------------------------------
DROP INDEX IF EXISTS public.bills_source_plug_uidx;

CREATE UNIQUE INDEX IF NOT EXISTS uq_active_standard_bill
  ON public.bills (parent_tenant_id, source_type, source_id, COALESCE(source_key, ''::text))
  WHERE document_kind = 'standard'::public.bill_document_kind
    AND source_type IS NOT NULL
    AND source_id IS NOT NULL
    AND invoice_status <> 'voided'::public.global_invoice_status;

-- ---------------------------------------------------------------------------
-- BP18: bill_settlements
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.bill_settlements (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  parent_tenant_id bigint NOT NULL REFERENCES public.tenants (id),
  bill_id bigint NOT NULL REFERENCES public.bills (id) ON DELETE RESTRICT,
  allocator_kind text NOT NULL CHECK (allocator_kind IN ('pay', 'credit_note', 'custody_entry')),
  allocator_id bigint NOT NULL,
  pay_allocation_id bigint REFERENCES public.pay_allocations (id),
  allocated_txn_amount numeric(12, 2) NOT NULL DEFAULT 0,
  allocated_books_amount numeric(12, 2) NOT NULL,
  books_rate_at_alloc numeric(15, 6),
  fx_realized_books_delta numeric(12, 2),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.bill_settlements
  ADD COLUMN IF NOT EXISTS pay_allocation_id bigint REFERENCES public.pay_allocations (id);

CREATE UNIQUE INDEX IF NOT EXISTS bill_settlements_pay_allocation_uidx
  ON public.bill_settlements (pay_allocation_id)
  WHERE pay_allocation_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS bill_settlements_bill_id_idx ON public.bill_settlements (bill_id);
CREATE INDEX IF NOT EXISTS bill_settlements_allocator_idx
  ON public.bill_settlements (allocator_kind, allocator_id);

ALTER TABLE public.bill_settlements ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- BP19: txn face on bills (nullable until issue)
-- ---------------------------------------------------------------------------
ALTER TABLE public.bills
  ADD COLUMN IF NOT EXISTS txn_currency_code text,
  ADD COLUMN IF NOT EXISTS txn_total_amount numeric(12, 2),
  ADD COLUMN IF NOT EXISTS books_exchange_rate numeric(15, 6);

-- ---------------------------------------------------------------------------
-- BP25: pay idempotency
-- ---------------------------------------------------------------------------
ALTER TABLE public.pays ADD COLUMN IF NOT EXISTS idempotency_key text;

CREATE UNIQUE INDEX IF NOT EXISTS pays_tenant_idempotency_uidx
  ON public.pays (tenant_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE OR REPLACE FUNCTION public._kernel_claim_pay_idempotency(
  p_parent_tenant_id bigint,
  p_key text
) RETURNS public.pays
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_pay public.pays;
  v_key text := nullif(btrim(p_key), '');
begin
  if v_key is null then
    return v_pay;
  end if;

  perform pg_advisory_xact_lock(
    hashtext('pay_idem:' || p_parent_tenant_id::text || ':' || v_key)
  );

  select * into v_pay
  from public.pays p
  where p.tenant_id = p_parent_tenant_id
    and p.idempotency_key = v_key
  limit 1;

  return v_pay;
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_finalize_pay_idempotency(
  p_pay_id bigint,
  p_parent_tenant_id bigint,
  p_key text
) RETURNS public.pays
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_pay public.pays;
  v_key text := nullif(btrim(p_key), '');
begin
  if v_key is null then
    select * into v_pay from public.pays where id = p_pay_id;
    return v_pay;
  end if;

  begin
    update public.pays
    set idempotency_key = v_key
    where id = p_pay_id;
  exception
    when unique_violation then
      select * into v_pay
      from public.pays p
      where p.tenant_id = p_parent_tenant_id
        and p.idempotency_key = v_key
      limit 1;
      return v_pay;
  end;

  select * into v_pay from public.pays where id = p_pay_id;
  return v_pay;
end;
$$;

-- ---------------------------------------------------------------------------
-- Helpers
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
$$;

-- Legacy trigger path retired at BP18-c cutover (settlements-first writer above).

CREATE OR REPLACE FUNCTION public._kernel_advisory_shipment_money_lock(p_shipment_id bigint)
RETURNS void
LANGUAGE plpgsql
AS $$
begin
  if p_shipment_id is not null then
    perform pg_advisory_xact_lock(hashtext('shipment_money:' || p_shipment_id::text));
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_lock_bills(p_bill_ids bigint[])
RETURNS void
LANGUAGE plpgsql
AS $$
declare
  v_id bigint;
begin
  if p_bill_ids is null then
    return;
  end if;
  for v_id in
    select distinct u.x
    from unnest(p_bill_ids) as u(x)
    where u.x is not null
    order by u.x
  loop
    perform 1 from public.bills where id = v_id for update;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- BP22: pot sync on ledger insert
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._kernel_sync_pot_on_cashbook_entry()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_delta numeric(12, 2);
begin
  if NEW.cashbook_point_pot_id is null then
    return NEW;
  end if;

  v_delta := case when NEW.type = 'credit' then NEW.amount else -NEW.amount end;

  update public.cashbook_point_pots
  set amount = amount + v_delta
  where id = NEW.cashbook_point_pot_id;

  return NEW;
end;
$$;

DROP TRIGGER IF EXISTS trg_cashbook_entry_sync_pot ON public.cashbook_entries;
CREATE TRIGGER trg_cashbook_entry_sync_pot
  AFTER INSERT ON public.cashbook_entries
  FOR EACH ROW
  EXECUTE FUNCTION public._kernel_sync_pot_on_cashbook_entry();

-- ---------------------------------------------------------------------------
-- get_bill_net_balances (settlements-aware)
-- ---------------------------------------------------------------------------
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
  v_oc record;
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

  select * into v_oc
  from public._kernel_bill_open_components(v_root.id) oc;

  v_due := coalesce(v_oc.open_books, 0);
  v_open_books := v_due;
  v_open_txn := coalesce(v_oc.open_txn, v_due);

  return jsonb_build_object(
    'bill_id', v_root.id,
    'invoice_no', v_root.invoice_no,
    'original_total', v_root.total_amount,
    'paid_amount', coalesce(v_oc.settled_books, 0),
    'credits_issued', coalesce(v_oc.credits_issued, 0),
    'debits_issued', coalesce(v_oc.debits_issued, 0),
    'due_amount', v_due,
    'open_books', v_open_books,
    'open_txn', v_open_txn,
    'credit_open', coalesce(v_oc.credit_open, 0),
    'document_kind', v_bill.document_kind
  );
end;
$$;

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

  v_row := public._kernel_record_pay_bill_settlement(
    p_tenant_id,
    p_payment_id,
    p_bill_id,
    p_amount,
    true
  );

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

-- ---------------------------------------------------------------------------
-- BP9: issue_bill / void_bill / upsert_draft_bill (minimal kernel)
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

CREATE OR REPLACE FUNCTION public.void_bill(p_bill_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  perform public.void_sales_invoice(p_bill_id);
end;
$$;

CREATE OR REPLACE FUNCTION public.upsert_draft_bill(p_payload jsonb)
RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_tenant_id bigint;
  v_result jsonb;
  v_bill public.bills;
  v_bill_id bigint;
begin
  v_tenant_id := nullif(p_payload->>'tenant_id', '')::bigint;
  if v_tenant_id is null then
    raise exception 'tenant_id required';
  end if;

  if coalesce(p_payload->>'adapter', '') = 'shipment_cost' then
    v_bill_id := public._upsert_shipment_ap_bill(
      nullif(p_payload->>'parent_tenant_id', '')::bigint,
      nullif(p_payload->>'issued_by_tenant_id', '')::bigint,
      nullif(p_payload->>'shipment_id', '')::bigint,
      p_payload->>'shipment_name',
      p_payload->>'ap_kind',
      nullif(p_payload->>'profile_id', '')::bigint,
      nullif(p_payload->>'amount', '')::numeric,
      coalesce(p_payload->'ap_paper', '{}'::jsonb),
      coalesce((p_payload->>'keep_as_draft')::boolean, true),
      nullif(p_payload->>'source_key', '')
    );
    if v_bill_id is null then
      raise exception 'shipment AP upsert returned no bill';
    end if;
    select * into v_bill from public.bills where id = v_bill_id;
    return v_bill;
  end if;

  if coalesce(p_payload->>'adapter', '') = 'dropship_courier' then
    v_result := public._kernel_upsert_dropship_courier_ap(
      nullif(p_payload->>'order_id', '')::bigint,
      coalesce((p_payload->>'keep_as_draft')::boolean, false)
    );
    if coalesce(v_result->>'success', 'false') <> 'true' then
      raise exception '%', coalesce(v_result->>'error', 'dropship courier AP upsert failed');
    end if;
    select * into v_bill from public.bills where id = (v_result->>'bill_id')::bigint;
    if v_bill.id is null then
      raise exception 'dropship courier AP bill missing after upsert';
    end if;
    return v_bill;
  end if;

  if coalesce(p_payload->>'adapter', '') = 'shop_order'
    or nullif(p_payload->>'shop_order_id', '') is not null then
    return public._kernel_upsert_shop_order_draft(p_payload);
  end if;

  return public._kernel_upsert_compose_draft(p_payload);
end;
$$;

-- ---------------------------------------------------------------------------
-- Pay kernel wrappers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.post_money_in(
  p_tenant_id bigint,
  p_profile_id bigint,
  p_received_on date,
  p_note text DEFAULT NULL,
  p_reference text DEFAULT NULL,
  p_source text DEFAULT 'customer_cash',
  p_instruments jsonb DEFAULT '[]'::jsonb,
  p_allocations jsonb DEFAULT '[]'::jsonb,
  p_shop_order_id bigint DEFAULT NULL,
  p_settlement_currency_code text DEFAULT 'BDT',
  p_foreign_amount numeric DEFAULT NULL,
  p_exchange_rate numeric DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL,
  p_cashbook_point_id bigint DEFAULT NULL,
  p_cashbook_point_pot_id bigint DEFAULT NULL,
  p_source_currency_code text DEFAULT NULL,
  p_transaction_rate numeric DEFAULT NULL
) RETURNS public.pays
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_pay public.pays;
begin
  v_pay := public.post_customer_receipt_with_allocations(
    p_tenant_id,
    p_profile_id,
    p_received_on,
    p_note,
    p_reference,
    p_source,
    p_instruments,
    p_allocations,
    p_shop_order_id,
    p_settlement_currency_code,
    p_foreign_amount,
    p_exchange_rate,
    true,
    p_idempotency_key,
    p_cashbook_point_id,
    p_cashbook_point_pot_id,
    p_source_currency_code,
    p_transaction_rate
  );

  return v_pay;
end;
$$;

CREATE OR REPLACE FUNCTION public.post_money_out(
  p_tenant_id bigint,
  p_profile_id bigint,
  p_paid_on date,
  p_amount numeric,
  p_source text DEFAULT 'ap_payout',
  p_note text DEFAULT NULL,
  p_reference text DEFAULT NULL,
  p_cashbook_point_id bigint DEFAULT NULL,
  p_instruments jsonb DEFAULT '[]'::jsonb,
  p_allocations jsonb DEFAULT '[]'::jsonb,
  p_settlement_currency_code text DEFAULT 'BDT',
  p_foreign_amount numeric DEFAULT NULL,
  p_exchange_rate numeric DEFAULT NULL,
  p_source_type text DEFAULT NULL,
  p_source_id text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL,
  p_cashbook_point_pot_id bigint DEFAULT NULL,
  p_payout_method text DEFAULT 'bank_transfer'
) RETURNS public.pays
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_pay public.pays;
begin
  if coalesce(p_source_type, '') = 'commission' or p_source = 'commission' then
    return public._kernel_post_commission_payout(
      p_tenant_id,
      p_profile_id,
      p_paid_on,
      p_amount,
      p_note,
      p_reference,
      p_payout_method,
      p_cashbook_point_id,
      p_cashbook_point_pot_id,
      p_source_id,
      p_idempotency_key
    );
  end if;

  if p_cashbook_point_id is null then
    raise exception 'cashbook_point_id required for pay out';
  end if;

  v_pay := public.post_ap_payout_with_allocations(
    p_tenant_id,
    p_profile_id,
    p_paid_on,
    p_cashbook_point_id,
    p_note,
    p_reference,
    p_instruments,
    p_allocations,
    p_settlement_currency_code,
    p_foreign_amount,
    p_exchange_rate,
    null,
    null,
    null,
    p_idempotency_key
  );

  return v_pay;
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

  if p_allocator_kind = 'custody_entry' then
    return public._kernel_apply_custody_to_bill(p_tenant_id, p_bill_id, p_books_amount);
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

CREATE OR REPLACE FUNCTION public.reverse_pay(p_payment_id bigint, p_reason text DEFAULT NULL)
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

-- Block silent issued total edits
CREATE OR REPLACE FUNCTION public.apply_global_invoice_target_total(
  p_invoice_id bigint,
  p_target_total numeric,
  p_dry_run boolean DEFAULT false
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  raise exception 'apply_global_invoice_target_total is retired; use credit_note or debit_note on the bill';
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_ensure_cashbook_point_pot(
  p_parent_tenant_id bigint,
  p_cashbook_point_id bigint,
  p_currency_code text
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_id bigint;
  v_ccy text := upper(trim(coalesce(p_currency_code, 'BDT')));
begin
  if p_cashbook_point_id is null then
    return null;
  end if;
  if v_ccy = '' then
    v_ccy := 'BDT';
  end if;

  insert into public.cashbook_point_pots (
    parent_tenant_id, cashbook_point_id, currency_code, amount
  ) values (
    p_parent_tenant_id, p_cashbook_point_id, v_ccy, 0
  )
  on conflict (cashbook_point_id, currency_code)
  do update set updated_at = now()
  returning id into v_id;

  return v_id;
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_lock_cashbook_point_pots(p_cashbook_point_id bigint)
RETURNS void
LANGUAGE plpgsql
AS $$
declare
  v_id bigint;
begin
  if p_cashbook_point_id is null then
    return;
  end if;
  for v_id in
    select cpp.id
    from public.cashbook_point_pots cpp
    where cpp.cashbook_point_id = p_cashbook_point_id
    order by cpp.currency_code asc, cpp.id asc
  loop
    perform 1 from public.cashbook_point_pots where id = v_id for update;
  end loop;
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_deny_cashbook_entry_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
begin
  if coalesce(current_setting('role', true), '') = 'service_role'
     or current_user in ('postgres', 'supabase_admin') then
    if TG_OP = 'DELETE' then
      return OLD;
    end if;
    return NEW;
  end if;
  raise exception 'cashbook_entries are append-only; post a reversing entry instead';
end;
$$;

DROP TRIGGER IF EXISTS trg_cashbook_entries_immutable ON public.cashbook_entries;
CREATE TRIGGER trg_cashbook_entries_immutable
  BEFORE UPDATE OR DELETE ON public.cashbook_entries
  FOR EACH ROW
  EXECUTE FUNCTION public._kernel_deny_cashbook_entry_mutation();

REVOKE UPDATE, DELETE ON TABLE public.cashbook_entries FROM authenticated;

GRANT SELECT, INSERT ON public.bill_settlements TO authenticated;
GRANT ALL ON public.bill_settlements TO service_role;

-- from supabase/schemas/bills_pays/03_adjustments.sql
-- Credit/debit notes on standard bills (BP8). Source for migrations; live copy also in baseline until full split.

CREATE OR REPLACE FUNCTION public.create_bill_adjustment(
  p_parent_bill_id bigint,
  p_kind text,
  p_amount numeric,
  p_reason text,
  p_issue boolean DEFAULT true,
  p_refund_amount numeric DEFAULT NULL,
  p_cashbook_point_id bigint DEFAULT NULL,
  p_lines jsonb DEFAULT '[]'::jsonb
) RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_parent public.bills;
  v_kind public.bill_document_kind;
  v_row public.bills;
  v_no text;
  v_reason text;
  v_amount numeric(12, 2);
  v_status public.global_invoice_status;
  v_refund numeric(12, 2);
  v_child_due numeric(12, 2);
  v_pay public.pays;
  v_pay_source text;
  v_line_elem jsonb;
  v_line_total numeric(12, 2);
  v_books numeric(12, 2);
  v_line_kind text;
  v_stock_id bigint;
  v_pot_id bigint;
  v_lines_sum numeric(12, 2) := 0.00;
begin
  if p_parent_bill_id is null then
    raise exception 'parent_bill_id is required';
  end if;

  v_kind := case lower(trim(coalesce(p_kind, '')))
    when 'credit_note' then 'credit_note'::public.bill_document_kind
    when 'credit' then 'credit_note'::public.bill_document_kind
    when 'debit_note' then 'debit_note'::public.bill_document_kind
    when 'debit' then 'debit_note'::public.bill_document_kind
    else null
  end;
  if v_kind is null then
    raise exception 'kind must be credit_note or debit_note';
  end if;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  if v_reason is null then
    raise exception 'reason is required';
  end if;

  select * into v_parent from public.bills where id = p_parent_bill_id for update;
  if v_parent.id is null then
    raise exception 'bill not found';
  end if;
  if v_parent.document_kind <> 'standard'::public.bill_document_kind then
    raise exception 'adjustments must attach to a standard bill';
  end if;
  if v_parent.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'parent bill must be issued';
  end if;

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_parent.parent_tenant_id)
    or public.membership_has_module_action(v_parent.issued_by_tenant_id, 'global_invoice', 'edit')
  ) then
    raise exception 'Permission denied';
  end if;

  if coalesce(jsonb_typeof(p_lines), 'null') = 'array' and jsonb_array_length(p_lines) > 0 then
    for v_line_elem in select value from jsonb_array_elements(p_lines)
    loop
      v_line_total := round(coalesce((v_line_elem ->> 'line_total_amount')::numeric, 0.00), 2);
      if v_line_total <= 0 then
        continue;
      end if;
      v_books := round(coalesce((v_line_elem ->> 'books_amount')::numeric, v_line_total), 2);
      v_lines_sum := v_lines_sum + v_books;
    end loop;
    v_amount := round(v_lines_sum, 2);
  else
    v_amount := round(coalesce(p_amount, 0), 2);
  end if;

  if v_amount <= 0 then
    raise exception 'amount must be greater than zero';
  end if;

  v_no := public.generate_sales_invoice_number(
    v_parent.issued_by_tenant_id,
    v_parent.invoice_type,
    current_date
  );
  if v_kind = 'credit_note'::public.bill_document_kind then
    v_no := regexp_replace(v_no, '^INV-', 'INV-CN-');
  else
    v_no := regexp_replace(v_no, '^INV-', 'INV-DN-');
  end if;

  v_status := case
    when coalesce(p_issue, true) then 'issued'::public.global_invoice_status
    else 'draft'::public.global_invoice_status
  end;

  insert into public.bills (
    parent_tenant_id,
    issued_by_tenant_id,
    invoice_no,
    invoice_type,
    invoice_date,
    invoice_status,
    profile_id,
    collection_source,
    payment_status,
    subtotal_amount,
    total_amount,
    due_amount,
    paid_amount,
    note,
    document_kind,
    parent_bill_id,
    ap_shipment_id,
    ap_kind,
    channel_meta
  ) values (
    v_parent.parent_tenant_id,
    v_parent.issued_by_tenant_id,
    v_no,
    v_parent.invoice_type,
    current_date,
    v_status,
    v_parent.profile_id,
    v_parent.collection_source,
    'due',
    v_amount,
    v_amount,
    v_amount,
    0,
    v_reason,
    v_kind,
    v_parent.id,
    v_parent.ap_shipment_id,
    v_parent.ap_kind,
    jsonb_build_object(
      'adjustment', jsonb_build_object(
        'kind', v_kind::text,
        'reason', v_reason,
        'parent_invoice_no', v_parent.invoice_no
      )
    )
  )
  returning * into v_row;

  if coalesce(jsonb_typeof(p_lines), 'null') = 'array' then
    for v_line_elem in select value from jsonb_array_elements(p_lines)
    loop
      v_line_total := round(coalesce((v_line_elem ->> 'line_total_amount')::numeric, 0.00), 2);
      if v_line_total <= 0 then
        continue;
      end if;
      v_books := round(coalesce((v_line_elem ->> 'books_amount')::numeric, v_line_total), 2);
      v_line_kind := lower(trim(coalesce(v_line_elem ->> 'line_kind', 'description')));
      if v_line_kind not in ('stock', 'description', 'charge') then
        v_line_kind := 'description';
      end if;
      v_stock_id := nullif(trim(coalesce(v_line_elem ->> 'global_stock_id', '')), '')::bigint;

      insert into public.bill_lines (
        parent_tenant_id,
        invoice_id,
        line_kind,
        name_snapshot,
        quantity,
        sell_price_amount,
        line_discount_amount,
        line_total_amount,
        currency_code,
        books_amount,
        line_meta
      ) values (
        v_parent.parent_tenant_id,
        v_row.id,
        v_line_kind,
        coalesce(nullif(trim(coalesce(v_line_elem ->> 'name_snapshot', '')), ''), 'Adjustment line'),
        greatest(coalesce((v_line_elem ->> 'quantity')::numeric, 1.000), 0.001),
        v_line_total,
        0.00,
        v_line_total,
        upper(trim(coalesce(v_line_elem ->> 'currency_code', 'BDT'))),
        v_books,
        coalesce(v_line_elem -> 'line_meta', '{}'::jsonb)
          || case
            when v_stock_id is not null
            then jsonb_build_object(
              'stock_ref',
              jsonb_build_object('global_stock_id', v_stock_id)
            )
            else '{}'::jsonb
          end
          || case
            when nullif(trim(coalesce(v_line_elem ->> 'parent_line_id', '')), '') is not null
            then jsonb_build_object('parent_line_id', v_line_elem ->> 'parent_line_id')
            else '{}'::jsonb
          end
      );
    end loop;
  end if;

  perform public.stamp_bill_kernel_fields(v_row.id);

  if v_status = 'issued'::public.global_invoice_status then
    perform public.recompute_global_invoice_payment_status(v_parent.id);
    select * into v_row from public.bills where id = v_row.id;
  end if;

  v_refund := round(coalesce(p_refund_amount, 0), 2);
  if v_refund > 0 then
    if v_kind <> 'credit_note'::public.bill_document_kind then
      raise exception 'Cash refund applies only to credit notes';
    end if;
    if v_parent.profile_id is null then
      raise exception 'Bill has no profile for refund';
    end if;
    if p_cashbook_point_id is null then
      raise exception 'Choose a cash point for the refund';
    end if;
    if not exists (
      select 1
      from public.cashbook_points cp
      join public.cashbook_accounts ca on ca.id = cp.cashbook_account_id
      where cp.id = p_cashbook_point_id
        and cp.is_active = true
        and ca.parent_tenant_id = v_parent.parent_tenant_id
        and ca.entity_type = 'tenant'
        and ca.entity_id = v_parent.parent_tenant_id
    ) then
      raise exception 'Invalid cash point for this tenant';
    end if;

    v_child_due := coalesce(v_row.due_amount, 0.00);
    if v_refund > v_child_due then
      raise exception 'Refund % exceeds open credit % on the note', v_refund, v_child_due;
    end if;

    v_pay_source := case
      when v_parent.invoice_type = 'ap'::public.global_invoice_type then 'ap_payout'
      else 'customer_cash'
    end;

    v_pot_id := public._kernel_ensure_cashbook_point_pot(
      v_parent.parent_tenant_id,
      p_cashbook_point_id,
      'BDT'
    );

    insert into public.pays (
      tenant_id,
      profile_id,
      source,
      amount,
      unallocated_amount,
      payment_date,
      method,
      note,
      cashbook_point_id,
      cashbook_point_pot_id,
      source_currency_code,
      transaction_rate
    ) values (
      v_parent.parent_tenant_id,
      v_parent.profile_id,
      v_pay_source,
      v_refund,
      0,
      current_date,
      'cash',
      v_reason,
      p_cashbook_point_id,
      v_pot_id,
      'BDT',
      1.000000
    )
    returning * into v_pay;

    insert into public.pay_instruments (
      payment_id,
      payment_method_code,
      amount,
      sort_order,
      cashbook_point_id
    ) values (
      v_pay.id,
      'CASH',
      v_refund,
      1,
      p_cashbook_point_id
    );

    perform public._kernel_record_pay_bill_settlement(
      v_parent.parent_tenant_id,
      v_pay.id,
      v_row.id,
      v_refund,
      false
    );

    perform public.recompute_global_invoice_payment_status(v_parent.id);

    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent.parent_tenant_id,
      p_operating_tenant_id => v_parent.issued_by_tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_parent.parent_tenant_id,
      p_type => 'debit',
      p_amount => v_refund,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'payout',
      p_source_id => v_pay.id::text,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'credit_note_refund',
        'transaction_type', 'credit_note_cash_refund',
        'label', case
          when v_parent.invoice_type = 'ap'::public.global_invoice_type
          then 'Vendor credit note cash refund'
          else 'Customer credit note cash refund'
        end,
        'payment_id', v_pay.id,
        'credit_note_id', v_row.id,
        'credit_note_no', v_row.invoice_no,
        'parent_bill_id', v_parent.id,
        'parent_invoice_no', v_parent.invoice_no,
        'cashbook_point_pot_id', v_pot_id,
        'source_currency_code', coalesce(v_pay.source_currency_code, 'BDT'),
        'transaction_rate', coalesce(v_pay.transaction_rate, 1.000000)
      ),
      p_allow_overdraft => true,
      p_cashbook_point_id => p_cashbook_point_id
    );

    select * into v_row from public.bills where id = v_row.id;
  elsif p_cashbook_point_id is not null and coalesce(p_refund_amount, 0) <= 0 then
    raise exception 'Refund amount is required when a cash point is selected';
  end if;

  return v_row;
end;
$$;

-- from supabase/schemas/bills_pays/12_cashbook_wiring.sql
-- BP15 + BP16 + BP21 cashbook wiring (source for migrations).

DO $$ BEGIN
  CREATE TYPE public.cashbook_account_class AS ENUM ('tenant_asset', 'profile_custody');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE public.cashbook_accounts
  ADD COLUMN IF NOT EXISTS account_class public.cashbook_account_class;

UPDATE public.cashbook_accounts
SET account_class = 'tenant_asset'::public.cashbook_account_class
WHERE account_class IS NULL AND entity_type = 'tenant';

UPDATE public.cashbook_accounts
SET account_class = 'profile_custody'::public.cashbook_account_class
WHERE account_class IS NULL AND entity_type <> 'tenant';

ALTER TABLE public.cashbook_accounts
  ALTER COLUMN account_class SET DEFAULT 'profile_custody'::public.cashbook_account_class;

ALTER TABLE public.cashbook_accounts
  ALTER COLUMN account_class SET NOT NULL;

ALTER TABLE public.cashbook_accounts DROP CONSTRAINT IF EXISTS cashbook_accounts_class_entity_check;
ALTER TABLE public.cashbook_accounts ADD CONSTRAINT cashbook_accounts_class_entity_check CHECK (
  (account_class = 'tenant_asset'::public.cashbook_account_class AND entity_type = 'tenant')
  OR (account_class = 'profile_custody'::public.cashbook_account_class AND entity_type <> 'tenant')
);


CREATE OR REPLACE FUNCTION public."get_wallet_account_balances"("p_tenant_id" bigint, "p_entity_type" text, "p_entity_id" bigint, "p_currency_code" text DEFAULT 'BDT'::text) RETURNS jsonb
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_result jsonb;
  v_books_id bigint;
  v_entity_id bigint;
BEGIN
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' THEN
    v_entity_id := v_books_id;
  END IF;

  SELECT jsonb_build_object(
    'parent_tenant_id', v_books_id,
    'tenant_id', v_books_id,
    'entity_type', p_entity_type,
    'entity_id', v_entity_id,
    'currency_code', coalesce(w.currency_code, p_currency_code),
    'available_balance', coalesce(w.available_balance, 0.0000),
    'pending_balance', coalesce(w.pending_balance, 0.0000),
    'locked_balance', coalesce(w.locked_balance, 0.0000),
    'total_balance', (
      coalesce(w.available_balance, 0.0000)
      + coalesce(w.pending_balance, 0.0000)
      + coalesce(w.locked_balance, 0.0000)
    ),
    'account_class', coalesce(w.account_class::text, case when p_entity_type = 'tenant' then 'tenant_asset' else 'profile_custody' end)
  )
  INTO v_result
  FROM (SELECT 1) dummy
  LEFT JOIN public.cashbook_accounts w
    ON w.parent_tenant_id = v_books_id
   AND w.entity_type = p_entity_type
   AND w.entity_id = v_entity_id
   AND w.currency_code = coalesce(p_currency_code, 'BDT');

  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public."get_wallet_detail_for_staff"("p_tenant_id" bigint, "p_entity_type" text, "p_entity_id" bigint, "p_currency_code" text DEFAULT 'BDT'::text) RETURNS jsonb
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_operating_id bigint;
  v_name text;
  v_code text;
  v_caption text;
  v_source_uuid uuid;
  v_entity_id bigint;
  v_account jsonb;
BEGIN
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_operating_id := p_tenant_id;
  v_entity_id := p_entity_id;

  IF NOT public.wallet_staff_can_view(p_tenant_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  IF p_entity_type = 'tenant' THEN
    v_entity_id := v_books_id;
    SELECT t.name INTO v_name FROM public.tenants t WHERE t.id = v_books_id;
    IF v_name IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'entity not found');
    END IF;
    v_caption := 'Company cash pool';

  ELSIF p_entity_type = 'customer' THEN
    SELECT
      CASE WHEN cg.name IS NOT NULL THEN cg.name || ' · ' || pr.name ELSE pr.name END,
      nullif(trim(concat_ws(' • ', pr.phone, pr.email)), '')
    INTO v_name, v_caption
    FROM public.profiles pr
    LEFT JOIN public.customer_groups cg ON cg.id = pr.customer_group_id
    WHERE pr.id = p_entity_id
      AND (pr.operating_tenant_id = v_books_id OR pr.operating_tenant_id IN (SELECT t.id FROM public.tenants t WHERE t.parent_id = v_books_id));
    IF v_name IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'entity not found');
    END IF;

  ELSIF p_entity_type = 'vendor' THEN
    SELECT v.name, v.code, nullif(trim(concat_ws(' • ', v.phone, v.email)), '')
    INTO v_name, v_code, v_caption
    FROM public.vendors v WHERE v.id = p_entity_id AND v.parent_tenant_id = v_books_id;
    IF v_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'entity not found'); END IF;

  ELSIF p_entity_type = 'cargo_company' THEN
    SELECT c.name, c.code, nullif(trim(concat_ws(' • ', c.phone, c.email)), '')
    INTO v_name, v_code, v_caption
    FROM public.cargo_companies c WHERE c.id = p_entity_id AND c.parent_tenant_id = v_books_id;
    IF v_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'entity not found'); END IF;

  ELSIF p_entity_type = 'courier' THEN
    SELECT cs.name, upper(cs.code), coalesce(nullif(trim(cs.notes), ''), 'Courier service'), cs.id
    INTO v_name, v_code, v_caption, v_source_uuid
    FROM public.courier_services cs
    WHERE cs.wallet_entity_id = p_entity_id AND cs.is_active = true
      AND (cs.tenant_id IS NULL OR cs.tenant_id = v_books_id
           OR cs.tenant_id IN (SELECT t.id FROM public.tenants t WHERE t.parent_id = v_books_id));
    IF v_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'entity not found'); END IF;

  ELSIF p_entity_type = 'investor' THEN
    SELECT i.name, nullif(trim(concat_ws(' • ', i.phone, i.email)), '')
    INTO v_name, v_caption
    FROM public.investors i WHERE i.id = p_entity_id AND i.tenant_id = v_books_id;
    IF v_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'entity not found'); END IF;

  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'invalid entity_type');
  END IF;

  v_account := public.get_wallet_account_balances(v_books_id, p_entity_type, v_entity_id, p_currency_code);

  RETURN jsonb_build_object(
    'success', true,
    'books_tenant_id', v_books_id,
    'operating_tenant_id', v_operating_id,
    'entity', jsonb_build_object(
      'entity_type', p_entity_type,
      'entity_id', v_entity_id,
      'name', v_name,
      'code', v_code,
      'caption', v_caption,
      'source_uuid', v_source_uuid
    ),
    'account', jsonb_build_object(
      'currency_code', coalesce(v_account->>'currency_code', p_currency_code),
      'available_balance', coalesce((v_account->>'available_balance')::numeric, 0),
      'pending_balance', coalesce((v_account->>'pending_balance')::numeric, 0),
      'locked_balance', coalesce((v_account->>'locked_balance')::numeric, 0),
      'total_balance', coalesce((v_account->>'total_balance')::numeric, 0),
      'account_class', coalesce(v_account->>'account_class', case when p_entity_type = 'tenant' then 'tenant_asset' else 'profile_custody' end)
    ),
    'permissions', jsonb_build_object(
      'can_record_manual', public.wallet_staff_can_edit(p_tenant_id),
      'can_reverse', public.wallet_staff_can_edit(p_tenant_id)
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public."record_ledger_transaction"("p_parent_tenant_id" bigint, "p_operating_tenant_id" bigint, "p_entity_type" text, "p_entity_id" bigint, "p_type" text, "p_amount" numeric, "p_currency_code" text DEFAULT 'BDT'::text, "p_exchange_rate" numeric DEFAULT 1.000000, "p_source_type" text DEFAULT 'adjustment'::text, "p_source_id" text DEFAULT NULL::text, "p_metadata" jsonb DEFAULT '{}'::jsonb, "p_target_bucket" text DEFAULT 'available'::text, "p_allow_overdraft" boolean DEFAULT false, "p_cashbook_point_id" bigint DEFAULT NULL::bigint) RETURNS jsonb
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_account_id bigint;
  v_avail numeric(18,4);
  v_pend numeric(18,4);
  v_lock numeric(18,4);
  v_base_amount numeric(18,4);
  v_new_balance numeric(18,4);
  v_ledger_entry jsonb;
  v_ledger_id uuid;
  v_entity_id bigint;
  v_point_ok boolean;
  v_pot_id bigint;
BEGIN
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Transaction amount must be greater than zero.';
  END IF;

  IF p_type NOT IN ('credit', 'debit') THEN
    RAISE EXCEPTION 'Transaction type must be credit or debit.';
  END IF;

  IF p_target_bucket NOT IN ('available', 'pending', 'locked') THEN
    RAISE EXCEPTION 'Target bucket must be available, pending, or locked.';
  END IF;

  v_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' AND v_entity_id IS DISTINCT FROM p_parent_tenant_id THEN
    v_entity_id := p_parent_tenant_id;
  END IF;

  INSERT INTO public.cashbook_accounts (
    tenant_id, parent_tenant_id, entity_type, entity_id, currency_code,
    available_balance, pending_balance, locked_balance, account_class
  )
  VALUES (
    p_parent_tenant_id, p_parent_tenant_id, p_entity_type, v_entity_id,
    coalesce(p_currency_code, 'BDT'), 0.0000, 0.0000, 0.0000,
    CASE WHEN p_entity_type = 'tenant' THEN 'tenant_asset'::public.cashbook_account_class
         ELSE 'profile_custody'::public.cashbook_account_class END
  )
  ON CONFLICT (parent_tenant_id, entity_type, entity_id, currency_code)
  DO UPDATE SET updated_at = now()
  RETURNING id, available_balance, pending_balance, locked_balance
  INTO v_account_id, v_avail, v_pend, v_lock;

  IF p_cashbook_point_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.cashbook_points cp
      WHERE cp.id = p_cashbook_point_id
        AND cp.parent_tenant_id = p_parent_tenant_id
        AND cp.cashbook_account_id = v_account_id
        AND cp.is_active = true
    ) INTO v_point_ok;
    IF NOT coalesce(v_point_ok, false) THEN
      RAISE EXCEPTION 'Invalid cashbook point for this account.';
    END IF;

    v_pot_id := public._kernel_ensure_cashbook_point_pot(
      p_parent_tenant_id,
      p_cashbook_point_id,
      coalesce(p_currency_code, 'BDT')
    );
    PERFORM 1
    FROM public.cashbook_point_pots cpp
    WHERE cpp.id = v_pot_id
    FOR UPDATE;
  END IF;

  SELECT available_balance, pending_balance, locked_balance
  INTO v_avail, v_pend, v_lock
  FROM public.cashbook_accounts
  WHERE id = v_account_id
  FOR UPDATE;

  IF p_target_bucket = 'available' THEN
    IF p_type = 'credit' THEN
      v_avail := v_avail + p_amount;
    ELSE
      v_avail := v_avail - p_amount;
    END IF;
    v_new_balance := v_avail;
  ELSIF p_target_bucket = 'pending' THEN
    IF p_type = 'credit' THEN
      v_pend := v_pend + p_amount;
    ELSE
      v_pend := v_pend - p_amount;
    END IF;
    v_new_balance := v_pend;
  ELSIF p_target_bucket = 'locked' THEN
    IF p_type = 'credit' THEN
      v_lock := v_lock + p_amount;
    ELSE
      v_lock := v_lock - p_amount;
    END IF;
    v_new_balance := v_lock;
  END IF;

  UPDATE public.cashbook_accounts
  SET
    available_balance = v_avail,
    pending_balance = v_pend,
    locked_balance = v_lock,
    tenant_id = p_parent_tenant_id,
    updated_at = now()
  WHERE id = v_account_id;

  v_base_amount := p_amount * coalesce(p_exchange_rate, 1.000000);

  INSERT INTO public.cashbook_entries (
    tenant_id,
    parent_tenant_id,
    operating_tenant_id,
    entity_type,
    entity_id,
    type,
    amount,
    currency_code,
    exchange_rate,
    base_amount,
    balance_after,
    source_type,
    source_id,
    metadata,
    cashbook_point_id,
    cashbook_point_pot_id
  )
  VALUES (
    p_parent_tenant_id,
    p_parent_tenant_id,
    p_operating_tenant_id,
    p_entity_type,
    v_entity_id,
    p_type,
    p_amount,
    coalesce(p_currency_code, 'BDT'),
    coalesce(p_exchange_rate, 1.000000),
    v_base_amount,
    v_new_balance,
    coalesce(p_source_type, 'adjustment'),
    p_source_id,
    coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object('target_bucket', p_target_bucket),
    p_cashbook_point_id,
    v_pot_id
  )
  RETURNING id INTO v_ledger_id;

  SELECT jsonb_build_object(
    'id', id,
    'parent_tenant_id', parent_tenant_id,
    'operating_tenant_id', operating_tenant_id,
    'tenant_id', parent_tenant_id,
    'entity_type', entity_type,
    'entity_id', entity_id,
    'type', type,
    'amount', amount,
    'currency_code', currency_code,
    'exchange_rate', exchange_rate,
    'base_amount', base_amount,
    'balance_after', balance_after,
    'source_type', source_type,
    'source_id', source_id,
    'metadata', metadata,
    'cashbook_point_id', cashbook_point_id,
    'created_at', created_at
  ) INTO v_ledger_entry
  FROM public.cashbook_entries
  WHERE id = v_ledger_id;

  RETURN v_ledger_entry;
END;
$$;


CREATE OR REPLACE FUNCTION public.list_books_exchange_rates(
  p_parent_tenant_id bigint,
  p_quote_currency_code text DEFAULT NULL,
  p_limit integer DEFAULT 50
)
RETURNS TABLE (
  id bigint,
  base_currency_code text,
  quote_currency_code text,
  rate numeric,
  rate_date timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO public
AS $$
BEGIN
  IF p_parent_tenant_id IS NULL THEN RAISE EXCEPTION 'parent_tenant_id is required'; END IF;
  IF NOT public.wallet_staff_can_view(p_parent_tenant_id) THEN RAISE EXCEPTION 'not allowed'; END IF;
  RETURN QUERY
  SELECT DISTINCT ON (upper(r.quote_currency_code))
    r.id, r.base_currency_code, r.quote_currency_code, r.rate, r.rate_date
  FROM public.books_exchange_rates r
  WHERE r.parent_tenant_id = public.resolve_parent_tenant_id(p_parent_tenant_id)
    AND (p_quote_currency_code IS NULL OR upper(r.quote_currency_code) = upper(p_quote_currency_code))
  ORDER BY upper(r.quote_currency_code), r.rate_date DESC, r.id DESC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 200));
END;
$$;
GRANT EXECUTE ON FUNCTION public.list_books_exchange_rates(bigint, text, integer) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public."post_customer_receipt_with_allocations"("p_tenant_id" bigint, "p_profile_id" bigint, "p_received_on" date, "p_note" text DEFAULT NULL::text, "p_reference" text DEFAULT NULL::text, "p_source" text DEFAULT 'customer_cash'::text, "p_instruments" jsonb DEFAULT '[]'::jsonb, "p_allocations" jsonb DEFAULT '[]'::jsonb, "p_shop_order_id" bigint DEFAULT NULL::bigint, "p_settlement_currency_code" text DEFAULT 'BDT'::text, "p_foreign_amount" numeric DEFAULT NULL::numeric, "p_exchange_rate" numeric DEFAULT NULL::numeric, "p_credit_dropship_profit" boolean DEFAULT true, "p_idempotency_key" text DEFAULT NULL::text) RETURNS public.pays
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
  v_source text := lower(trim(coalesce(p_source, 'customer_cash')));
  v_received_on date := coalesce(p_received_on, current_date);
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
  v_leftover numeric(12, 2);
  v_settle_currency text := 'BDT';
  v_foreign_amt numeric(12, 2);
  v_fx_rate numeric(15, 6) := 1.000000;
  v_cashbook_point_id bigint;
  v_pot_id bigint;
  v_source_currency text;
  v_transaction_rate numeric(15, 6) := 1.000000;
  v_base_currency text := 'BDT';
  v_source_amount numeric(12, 2);
  v_payment_face numeric(12, 2);
  v_ledger_amount numeric(12, 2);
  v_ledger_currency text;
  v_ledger_rate numeric(15, 6);
  v_bill_ids bigint[] := '{}';
  v_sid bigint;
begin
  if p_tenant_id is null then
    raise exception 'Tenant is required';
  end if;
  if p_profile_id is null then
    raise exception 'Profile is required';
  end if;
  if v_source not in ('customer_cash', 'bank', 'store_credit', 'courier_remittance') then
    raise exception 'Invalid receipt source: %', p_source;
  end if;
  if v_source = 'courier_remittance' and p_shop_order_id is null then
    raise exception 'Courier remittance requires a shop order';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  v_pay := public._kernel_claim_pay_idempotency(v_parent_id, p_idempotency_key);
  if v_pay.id is not null then
    return v_pay;
  end if;

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
    raise exception 'Permission denied: cannot record receipts for this tenant';
  end if;

  if not exists (
    select 1 from public.profiles pr
    where pr.id = p_profile_id and pr.parent_tenant_id = v_parent_id
  ) then
    raise exception 'Profile % does not belong to these books', p_profile_id;
  end if;

  -- Instruments: validate and total (header amount = instrument sum).
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

  if v_source = 'store_credit' then
    if v_line_count > 0 then
      raise exception 'Store credit receipts take no instrument lines';
    end if;
    v_header_method := 'store_credit';
  elsif v_line_count = 0 then
    raise exception 'Enter at least one payment line';
  end if;

  if v_header_method is not null and v_header_method not in (
    'cash', 'bank', 'bank_transfer', 'mobile_banking', 'bkash', 'nagad', 'other', 'cheque', 'rocket',
    'upay', 'tap', 'card_pos', 'wire_transfer', 'paypal', 'stripe', 'letter_of_credit', 'cod', 'split',
    'store_credit'
  ) then
    v_header_method := 'other';
  end if;

  if v_source <> 'store_credit' then
    select n.settlement_currency_code, n.foreign_amount, n.exchange_rate, n.amount_bdt
    into v_settle_currency, v_foreign_amt, v_fx_rate, v_amount
    from public.normalize_pay_settlement_fx(
      v_amount,
      p_settlement_currency_code,
      p_foreign_amount,
      p_exchange_rate,
      public.resolve_tenant_base_currency_code(p_tenant_id)
    ) n;
  end if;


  v_base_currency := public.resolve_tenant_base_currency_code(p_tenant_id);

  v_cashbook_point_id := p_cashbook_point_id;
  if v_cashbook_point_id is null and coalesce(jsonb_typeof(p_instruments), 'null') = 'array' then
    for v_line in select value from jsonb_array_elements(p_instruments)
    loop
      if nullif(v_line.value ->> 'cashbook_point_id', '') is not null then
        v_cashbook_point_id := (v_line.value ->> 'cashbook_point_id')::bigint;
        exit;
      end if;
    end loop;
  end if;

  if v_source in ('customer_cash', 'bank', 'courier_remittance') then
    if v_cashbook_point_id is null then
      raise exception 'Choose a cash point for this receipt';
    end if;
    if not exists (
      select 1
      from public.cashbook_points cp
      join public.cashbook_accounts ca on ca.id = cp.cashbook_account_id
      where cp.id = v_cashbook_point_id
        and cp.is_active = true
        and ca.parent_tenant_id = v_parent_id
        and ca.entity_type = 'tenant'
        and ca.entity_id = v_parent_id
    ) then
      raise exception 'Invalid cash point for this tenant';
    end if;
  end if;

  v_pot_id := p_cashbook_point_pot_id;
  v_source_currency := upper(trim(coalesce(p_source_currency_code, '')));
  if v_source_currency = '' and v_cashbook_point_id is not null then
    select upper(cpp.currency_code)
    into v_source_currency
    from public.cashbook_point_pots cpp
    where cpp.cashbook_point_id = v_cashbook_point_id
      and cpp.parent_tenant_id = v_parent_id
    order by case when upper(cpp.currency_code) = v_base_currency then 0 else 1 end, cpp.id
    limit 1;
  end if;
  if v_pot_id is null and v_cashbook_point_id is not null and coalesce(v_source_currency, '') <> '' then
    v_pot_id := public._kernel_ensure_cashbook_point_pot(v_parent_id, v_cashbook_point_id, v_source_currency);
  end if;

  if upper(v_settle_currency) = coalesce(v_source_currency, v_base_currency) then
    v_transaction_rate := 1.000000;
  elsif v_source in ('customer_cash', 'bank', 'courier_remittance') then
    v_transaction_rate := coalesce(p_transaction_rate, 0);
    if v_transaction_rate <= 0 and coalesce(v_source_currency, v_base_currency) <> v_base_currency then
      raise exception 'transaction_rate required when pot currency differs from books currency';
    end if;
  end if;

  if upper(v_settle_currency) = v_base_currency then
    v_payment_face := v_amount;
  else
    v_payment_face := coalesce(v_foreign_amt, 0);
  end if;
  v_source_amount := round(v_payment_face * v_transaction_rate, 2);

  if coalesce(jsonb_typeof(p_allocations), 'null') = 'array' then
    select coalesce(array_agg(distinct x.bid order by x.bid), '{}'::bigint[])
    into v_bill_ids
    from (
      select coalesce(
        nullif(v_alloc_elem.value ->> 'bill_id', '')::bigint,
        nullif(v_alloc_elem.value ->> 'invoice_id', '')::bigint
      ) as bid
      from jsonb_array_elements(p_allocations) as v_alloc_elem(value)
    ) x
    where x.bid is not null;
  end if;

  perform public._kernel_lock_bills(v_bill_ids);

  for v_sid in
    select distinct b.ap_shipment_id
    from public.bills b
    where b.id = any(v_bill_ids)
      and b.ap_shipment_id is not null
    order by b.ap_shipment_id asc
  loop
    perform public._kernel_advisory_shipment_money_lock(v_sid);
  end loop;

  if v_cashbook_point_id is not null then
    perform public._kernel_lock_cashbook_point_pots(v_cashbook_point_id);
  end if;

  insert into public.pays (
    tenant_id, profile_id, source, amount, unallocated_amount,
    payment_date, method, reference, note, shop_order_id,
    settlement_currency_code, foreign_amount, exchange_rate, quote_currency_code,
    cashbook_point_id, source_currency_code, transaction_rate, source_amount, cashbook_point_pot_id
  ) values (
    v_parent_id, p_profile_id, v_source, v_amount, v_amount,
    v_received_on, v_header_method, v_reference, v_note, p_shop_order_id,
    v_settle_currency, v_foreign_amt, v_fx_rate, v_base_currency,
    v_cashbook_point_id, v_source_currency, v_transaction_rate, v_source_amount, v_pot_id
  ) returning * into v_pay;

  if v_line_count > 0 then
    perform public.insert_global_payment_instruments(v_pay.id, p_instruments);
  end if;

  update public.pay_instruments pi
  set cashbook_point_id = coalesce(pi.cashbook_point_id, v_cashbook_point_id)
  where pi.payment_id = v_pay.id;

  -- Allocations: open issued bills of this profile only.
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
      if v_bill.invoice_status <> 'issued'::public.global_invoice_status then
        raise exception 'Bill % is not issued', v_bill.invoice_no;
      end if;
      if v_bill.profile_id is distinct from p_profile_id then
        raise exception 'Bill % is billed to a different profile', v_bill.invoice_no;
      end if;
      if v_alloc_amount > coalesce(
        (public.get_bill_net_balances(v_bill_id)->>'open_books')::numeric,
        v_bill.due_amount,
        0.00
      ) then
        raise exception 'Allocation % exceeds bill % open balance', v_alloc_amount, v_bill.invoice_no;
      end if;

      perform public._kernel_record_pay_bill_settlement(
        v_parent_id,
        v_pay.id,
        v_bill_id,
        v_alloc_amount,
        false
      );

      v_total_alloc := v_total_alloc + v_alloc_amount;
    end loop;
  end if;

  if v_source = 'store_credit' then
    if v_total_alloc <= 0 then
      raise exception 'Store credit receipt needs at least one allocation';
    end if;
    v_amount := v_total_alloc;
  elsif v_total_alloc > v_amount then
    raise exception 'Allocations (%) exceed receipt amount (%)', v_total_alloc, v_amount;
  end if;

  v_leftover := v_amount - v_total_alloc;

  update public.pays
  set amount = v_amount, unallocated_amount = v_leftover
  where id = v_pay.id
  returning * into v_pay;

  if v_source in ('customer_cash', 'bank', 'courier_remittance') then
    if coalesce(v_source_currency, v_base_currency) = v_base_currency then
      v_ledger_amount := v_amount;
      v_ledger_currency := v_base_currency;
      v_ledger_rate := 1.000000;
    else
      v_ledger_amount := v_payment_face;
      v_ledger_currency := v_source_currency;
      v_ledger_rate := v_transaction_rate;
    end if;

    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_id,
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_parent_id,
      p_type => 'credit',
      p_amount => v_ledger_amount,
      p_currency_code => v_ledger_currency,
      p_exchange_rate => v_ledger_rate,
      p_source_type => case when v_source = 'courier_remittance' then 'shop_order' else 'sales_invoice' end,
      p_source_id => case when v_source = 'courier_remittance' then p_shop_order_id::text else v_pay.id::text end,
      p_metadata => jsonb_build_object(
        'section', case when v_source = 'courier_remittance' then 'payment_received' else 'payments' end,
        'purpose', case
          when v_source = 'courier_remittance' then 'courier_remittance_received'
          else 'tenant_payment_received'
        end,
        'transaction_type', case
          when v_source = 'courier_remittance' then 'courier_remittance_received'
          else 'payment_received'
        end,
        'label', case when v_source = 'courier_remittance' then 'Courier remittance received' else 'Payment received' end,
        'payment_id', v_pay.id,
        'method', v_header_method,
        'instrument_count', v_line_count,
        'reference', v_reference,
        'shop_order_id', case when v_source = 'courier_remittance' then p_shop_order_id else null end,
        'settlement_currency_code', v_settle_currency,
        'foreign_amount', v_foreign_amt,
        'exchange_rate', v_fx_rate,
        'source_currency_code', v_source_currency,
        'transaction_rate', v_transaction_rate,
        'source_amount', v_source_amount,
        'cashbook_point_pot_id', v_pot_id
      ),
      p_cashbook_point_id => v_cashbook_point_id
    );
  elsif v_source = 'store_credit' then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_id,
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'customer',
      p_entity_id => p_profile_id,
      p_type => 'debit',
      p_amount => v_amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'sales_invoice',
      p_source_id => v_pay.id::text,
      p_allow_overdraft => false,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'apply_store_credit',
        'transaction_type', 'wallet_credit',
        'label', 'Applied store credit',
        'payment_id', v_pay.id
      )
    );
  end if;

  if v_leftover > 0 then
    if v_source = 'courier_remittance' then
      if coalesce(p_credit_dropship_profit, true) then
        perform public.credit_dropship_profit_from_courier_remittance(
          p_tenant_id,
          p_profile_id,
          p_shop_order_id,
          v_pay.id,
          v_leftover,
          v_reference,
          v_amount,
          v_total_alloc
        );
      end if;
    else
      perform public.record_ledger_transaction(
        p_parent_tenant_id => v_parent_id,
        p_operating_tenant_id => p_tenant_id,
        p_entity_type => 'customer',
        p_entity_id => p_profile_id,
        p_type => 'credit',
        p_amount => v_leftover,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'sales_invoice',
        p_source_id => v_pay.id::text,
        p_metadata => jsonb_build_object(
          'section', 'payments',
          'purpose', 'store_credit',
          'payment_id', v_pay.id,
          'reference', v_reference
        )
      );
    end if;
  end if;

  return public._kernel_finalize_pay_idempotency(v_pay.id, v_parent_id, p_idempotency_key);
end;
$$;

-- from supabase/schemas/bills_pays/15_pay_payout_alloc.sql
-- BP18-c: AP payout (settlements-first alloc)

CREATE OR REPLACE FUNCTION "public"."post_ap_payout_with_allocations"("p_tenant_id" bigint, "p_profile_id" bigint, "p_paid_on" "date", "p_cashbook_point_id" bigint, "p_note" "text" DEFAULT NULL::"text", "p_reference" "text" DEFAULT NULL::"text", "p_instruments" "jsonb" DEFAULT '[]'::"jsonb", "p_allocations" "jsonb" DEFAULT '[]'::"jsonb", "p_settlement_currency_code" "text" DEFAULT 'BDT'::"text", "p_foreign_amount" numeric DEFAULT NULL::numeric, "p_exchange_rate" numeric DEFAULT NULL::numeric, "p_source_currency_code" "text" DEFAULT NULL::"text", "p_transaction_rate" numeric DEFAULT NULL::numeric, "p_cashbook_point_pot_id" bigint DEFAULT NULL::bigint, "p_idempotency_key" "text" DEFAULT NULL::"text") RETURNS "public"."pays"
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
  v_bill_ids bigint[] := '{}';
begin
  if p_tenant_id is null then
    raise exception 'Tenant is required';
  end if;
  if p_profile_id is null then
    raise exception 'Profile is required';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_base_currency := public.resolve_tenant_base_currency_code(p_tenant_id);

  v_pay := public._kernel_claim_pay_idempotency(v_parent_id, p_idempotency_key);
  if v_pay.id is not null then
    return v_pay;
  end if;

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

  if coalesce(jsonb_typeof(p_allocations), 'null') = 'array' then
    select coalesce(array_agg(distinct x.bid order by x.bid), '{}'::bigint[])
    into v_bill_ids
    from (
      select coalesce(
        nullif(v_alloc_elem.value ->> 'bill_id', '')::bigint,
        nullif(v_alloc_elem.value ->> 'invoice_id', '')::bigint
      ) as bid
      from jsonb_array_elements(p_allocations) as v_alloc_elem(value)
    ) x
    where x.bid is not null;
  end if;

  perform public._kernel_lock_bills(v_bill_ids);

  for v_sid in
    select distinct b.ap_shipment_id
    from public.bills b
    where b.id = any(v_bill_ids)
      and b.ap_shipment_id is not null
    order by b.ap_shipment_id asc
  loop
    perform public._kernel_advisory_shipment_money_lock(v_sid);
  end loop;

  perform public._kernel_lock_cashbook_point_pots(p_cashbook_point_id);

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

      perform public._kernel_record_pay_bill_settlement(
        v_parent_id,
        v_pay.id,
        v_bill_id,
        v_alloc_amount,
        false
      );
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

  return public._kernel_finalize_pay_idempotency(v_pay.id, v_parent_id, p_idempotency_key);
end;
$$;

-- from supabase/schemas/bills_pays/09_kernel_reads.sql
-- BP10 + BP23: kernel read projections and list RPCs (source for migrations).

-- ---------------------------------------------------------------------------
-- _kernel_bill_open_components (shared open math for view + get_bill_net_balances)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._kernel_bill_open_components(p_root_bill_id bigint)
RETURNS TABLE (
  credits_issued numeric(12, 2),
  debits_issued numeric(12, 2),
  settled_books numeric(12, 2),
  open_books numeric(12, 2),
  open_txn numeric(12, 2),
  credit_open numeric(12, 2)
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_root public.bills;
  v_credits numeric(12, 2);
  v_debits numeric(12, 2);
  v_credit_due numeric(12, 2);
  v_settled numeric(12, 2);
  v_due numeric(12, 2);
  v_open_txn numeric(12, 2);
begin
  select * into v_root from public.bills where id = p_root_bill_id;
  if v_root.id is null then
    credits_issued := 0;
    debits_issued := 0;
    settled_books := 0;
    open_books := 0;
    open_txn := 0;
    credit_open := 0;
    return next;
    return;
  end if;

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

  v_due := greatest(coalesce(v_root.total_amount, 0) - v_settled - v_credits + v_debits, 0);

  v_open_txn := case
    when coalesce(v_root.txn_total_amount, v_root.total_amount) is not null
      and coalesce(v_root.books_exchange_rate, 1) > 0
    then greatest(
      coalesce(v_root.txn_total_amount, v_root.total_amount)
        - coalesce((
          select sum(bs.allocated_txn_amount)
          from public.bill_settlements bs
          where bs.bill_id = v_root.id
        ), 0),
      0
    )
    else v_due
  end;

  credits_issued := v_credits;
  debits_issued := v_debits;
  settled_books := v_settled;
  open_books := v_due;
  open_txn := v_open_txn;
  credit_open := v_credit_due;
  return next;
end;
$$;

-- ---------------------------------------------------------------------------
-- v_kernel_bill_summaries (BP23)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_kernel_bill_summaries
WITH (security_invoker = true)
AS
SELECT
  b.id AS bill_id,
  b.parent_tenant_id,
  b.issued_by_tenant_id,
  b.source_type,
  b.source_id,
  b.source_key,
  b.document_kind,
  b.invoice_type,
  b.invoice_no,
  b.invoice_date,
  CASE
    WHEN b.invoice_status = 'voided'::public.global_invoice_status THEN 'voided'
    WHEN b.invoice_status IN (
      'draft'::public.global_invoice_status,
      'proforma_generated'::public.global_invoice_status
    ) THEN 'draft'
    WHEN b.invoice_status = 'issued'::public.global_invoice_status THEN 'issued'
    ELSE 'draft'
  END AS lifecycle_status,
  b.payment_status::text AS settlement_status,
  coalesce(b.txn_currency_code, b.currency_code, 'BDT') AS txn_currency_code,
  coalesce(b.txn_total_amount, b.total_amount) AS txn_total_amount,
  coalesce(b.currency_code, 'BDT') AS currency_code,
  b.total_amount,
  CASE
    WHEN b.document_kind = 'standard'::public.bill_document_kind
      AND b.invoice_status = 'issued'::public.global_invoice_status
    THEN coalesce(oc.open_books, b.due_amount, 0)
    ELSE coalesce(b.due_amount, 0)
  END AS open_books,
  CASE
    WHEN b.document_kind = 'standard'::public.bill_document_kind
      AND b.invoice_status = 'issued'::public.global_invoice_status
    THEN coalesce(oc.open_txn, oc.open_books, b.due_amount, 0)
    ELSE coalesce(b.due_amount, 0)
  END AS open_txn,
  b.due_date,
  b.from_profile_id,
  b.to_profile_id,
  b.profile_id,
  b.parent_bill_id
FROM public.bills b
LEFT JOIN LATERAL public._kernel_bill_open_components(coalesce(b.parent_bill_id, b.id)) oc ON true;

-- ---------------------------------------------------------------------------
-- list_bills_for_source (BP10)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.list_bills_for_source(
  p_parent_tenant_id bigint,
  p_source_type text,
  p_source_id text,
  p_source_key text DEFAULT NULL,
  p_include_voided boolean DEFAULT false,
  p_ap_shipment_buckets_only boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_parent_id bigint;
  v_sid bigint;
  v_rows jsonb;
begin
  if p_parent_tenant_id is null then
    raise exception 'parent_tenant_id is required';
  end if;
  if nullif(trim(coalesce(p_source_type, '')), '') is null then
    raise exception 'source_type is required';
  end if;
  if nullif(trim(coalesce(p_source_id, '')), '') is null then
    raise exception 'source_id is required';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_parent_tenant_id);

  if not (
    public.user_can_manage_parent_tenant(v_parent_id)
    or public.membership_has_module_action(v_parent_id, 'global_invoice', 'view')
  ) then
    raise exception 'not allowed';
  end if;

  v_sid := nullif(trim(p_source_id), '')::bigint;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', b.id,
        'invoice_no', b.invoice_no,
        'invoice_type', b.invoice_type,
        'document_kind', b.document_kind,
        'ap_kind', b.ap_kind,
        'source_type', b.source_type,
        'source_id', b.source_id,
        'source_key', b.source_key,
        'invoice_status', b.invoice_status,
        'payment_status', b.payment_status,
        'total_amount', b.total_amount,
        'due_amount', b.due_amount,
        'parent_bill_id', b.parent_bill_id,
        'net_balances', public.get_bill_net_balances(b.id)
      )
      ORDER BY b.id
    ),
    '[]'::jsonb
  )
  into v_rows
  from public.bills b
  where b.parent_tenant_id = v_parent_id
    and (p_include_voided or b.invoice_status <> 'voided'::public.global_invoice_status)
    and (
      (b.source_type = p_source_type and b.source_id = p_source_id)
      or (
        p_source_type = 'shipment_cost'
        and b.invoice_type = 'ap'::public.global_invoice_type
        and b.document_kind = 'standard'::public.bill_document_kind
        and (
          (b.source_type = 'shipment_cost' and b.source_id = p_source_id)
          or (v_sid is not null and b.ap_shipment_id = v_sid)
        )
      )
      or (
        p_source_type = 'shop_order'
        and b.source_type = 'shop_order'
        and b.source_id = p_source_id
      )
    )
    and (p_source_key is null or b.source_key = p_source_key)
    and (
      not p_ap_shipment_buckets_only
      or coalesce(b.source_key, b.ap_kind) in (
        'material', 'freight', 'customs', 'handling', 'finance', 'other',
        'vendor', 'cargo', 'local'
      )
      or coalesce(b.source_key, '') ~ '^(material|freight|customs|handling|finance|other|vendor|cargo|local):'
    );

  return v_rows;
end;
$$;

-- ---------------------------------------------------------------------------
-- list_pays_for_source (BP10)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.list_pays_for_source(
  p_parent_tenant_id bigint,
  p_source_type text,
  p_source_id text
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_parent_id bigint;
  v_order_id bigint;
  v_rows jsonb;
begin
  if p_parent_tenant_id is null then
    raise exception 'parent_tenant_id is required';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_parent_tenant_id);
  v_order_id := nullif(trim(p_source_id), '')::bigint;

  if not (
    public.user_can_manage_parent_tenant(v_parent_id)
    or public.membership_has_module_action(v_parent_id, 'global_invoice', 'view')
  ) then
    raise exception 'not allowed';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', p.id,
        'amount', p.amount,
        'unallocated_amount', p.unallocated_amount,
        'payment_date', p.payment_date,
        'method', p.method,
        'source', p.source,
        'profile_id', p.profile_id,
        'shop_order_id', p.shop_order_id,
        'voided_at', p.voided_at,
        'settlement_currency_code', p.settlement_currency_code,
        'foreign_amount', p.foreign_amount,
        'exchange_rate', p.exchange_rate,
        'quote_currency_code', p.quote_currency_code,
        'source_currency_code', p.source_currency_code,
        'transaction_rate', p.transaction_rate,
        'source_amount', p.source_amount
      )
      ORDER BY p.id DESC
    ),
    '[]'::jsonb
  )
  into v_rows
  from public.pays p
  where p.tenant_id = v_parent_id
    and p.voided_at is null
    and (
      (
        p_source_type = 'shop_order'
        and v_order_id is not null
        and p.shop_order_id = v_order_id
      )
      or exists (
        select 1
        from public.bill_settlements bs
        join public.bills b on b.id = bs.bill_id
        where bs.allocator_kind = 'pay'
          and bs.allocator_id = p.id
          and b.parent_tenant_id = v_parent_id
          and (
            (b.source_type = p_source_type and b.source_id = p_source_id)
            or (
              p_source_type = 'shipment_cost'
              and b.invoice_type = 'ap'::public.global_invoice_type
              and (
                (b.source_type = 'shipment_cost' and b.source_id = p_source_id)
                or (v_order_id is not null and b.ap_shipment_id = v_order_id)
              )
            )
          )
      )
    );

  return v_rows;
end;
$$;

-- ---------------------------------------------------------------------------
-- list_open_on_profile (BP10)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.list_open_on_profile(
  p_parent_tenant_id bigint,
  p_profile_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_parent_id bigint;
  v_due_bills jsonb;
  v_open_credits jsonb;
  v_leftover jsonb;
begin
  if p_parent_tenant_id is null or p_profile_id is null then
    raise exception 'parent_tenant_id and profile_id are required';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_parent_tenant_id);

  if not (
    public.user_can_manage_parent_tenant(v_parent_id)
    or public.membership_has_module_action(v_parent_id, 'global_invoice', 'view')
  ) then
    raise exception 'not allowed';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'bill_id', s.bill_id,
        'invoice_no', s.invoice_no,
        'total_amount', s.total_amount,
        'open_books', s.open_books,
        'due_date', s.due_date,
        'invoice_type', s.invoice_type
      )
      ORDER BY s.bill_id DESC
    ),
    '[]'::jsonb
  )
  into v_due_bills
  from public.v_kernel_bill_summaries s
  where s.parent_tenant_id = v_parent_id
    and s.document_kind = 'standard'::public.bill_document_kind
    and s.lifecycle_status = 'issued'
    and s.open_books > 0
    and (
      s.profile_id = p_profile_id
      or s.from_profile_id = p_profile_id
      or s.to_profile_id = p_profile_id
    );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'bill_id', s.bill_id,
        'invoice_no', s.invoice_no,
        'due_amount', s.open_books,
        'parent_bill_id', s.parent_bill_id
      )
      ORDER BY s.bill_id DESC
    ),
    '[]'::jsonb
  )
  into v_open_credits
  from public.v_kernel_bill_summaries s
  where s.parent_tenant_id = v_parent_id
    and s.document_kind = 'credit_note'::public.bill_document_kind
    and s.lifecycle_status = 'issued'
    and s.open_books > 0
    and (
      s.profile_id = p_profile_id
      or s.from_profile_id = p_profile_id
      or s.to_profile_id = p_profile_id
    );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'pay_id', p.id,
        'amount', p.amount,
        'unallocated_amount', p.unallocated_amount,
        'payment_date', p.payment_date,
        'source', p.source
      )
      ORDER BY p.id DESC
    ),
    '[]'::jsonb
  )
  into v_leftover
  from public.pays p
  where p.tenant_id = v_parent_id
    and p.profile_id = p_profile_id
    and p.voided_at is null
    and p.unallocated_amount > 0;

  return jsonb_build_object(
    'due_bills', v_due_bills,
    'open_credit_notes', v_open_credits,
    'pay_leftover', v_leftover
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- list_invoice_payment_history (settlements-first reads)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.list_invoice_payment_history(
  p_tenant_id bigint,
  p_invoice_id bigint
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_parent_id bigint;
  v_result jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_invoice_id IS NULL THEN
    RAISE EXCEPTION 'Tenant and invoice are required.';
  END IF;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  IF NOT EXISTS (
    SELECT 1
    FROM public.bills si
    WHERE si.id = p_invoice_id
      AND (si.parent_tenant_id = v_parent_id OR si.issued_by_tenant_id = p_tenant_id)
  ) THEN
    RAISE EXCEPTION 'Invoice not found for this tenant.';
  END IF;

  SELECT coalesce(jsonb_agg(row_to_json(r) ORDER BY r.sort_at DESC, r.entry_id DESC), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT
      'allocation'::text AS entry_type,
      coalesce(bs.pay_allocation_id, bs.id) AS entry_id,
      gp.id AS payment_id,
      gp.payment_date,
      gp.payment_date::timestamptz AS sort_at,
      bs.allocated_books_amount AS amount,
      gp.amount AS receipt_amount,
      gp.voided_at,
      gp.method,
      gp.note,
      NULL::text AS write_off_reason,
      coalesce(gp.settlement_currency_code, 'BDT') AS settlement_currency_code,
      gp.foreign_amount,
      coalesce(gp.exchange_rate, 1.000000) AS exchange_rate,
      coalesce(
        (
          SELECT jsonb_agg(
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
            ORDER BY gpi.sort_order, gpi.id
          )
          FROM public.pay_instruments gpi
          LEFT JOIN public.bd_banks b ON b.id = gpi.bd_bank_id
          WHERE gpi.payment_id = gp.id
        ),
        '[]'::jsonb
      ) AS instruments
    FROM public.bill_settlements bs
    JOIN public.pays gp ON gp.id = bs.allocator_id AND bs.allocator_kind = 'pay'
    WHERE bs.bill_id = p_invoice_id

    UNION ALL

    SELECT
      'write_off'::text AS entry_type,
      iwo.id AS entry_id,
      iwo.payment_id,
      coalesce(gp.payment_date, iwo.created_at::date) AS payment_date,
      coalesce(gp.payment_date::timestamptz, iwo.created_at) AS sort_at,
      iwo.amount AS amount,
      coalesce(gp.amount, 0.00) AS receipt_amount,
      gp.voided_at,
      coalesce(gp.method, 'write_off') AS method,
      iwo.note,
      iwo.reason AS write_off_reason,
      coalesce(gp.settlement_currency_code, 'BDT') AS settlement_currency_code,
      gp.foreign_amount,
      coalesce(gp.exchange_rate, 1.000000) AS exchange_rate,
      CASE
        WHEN gp.id IS NULL THEN '[]'::jsonb
        ELSE coalesce(
          (
            SELECT jsonb_agg(
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
              ORDER BY gpi.sort_order, gpi.id
            )
            FROM public.pay_instruments gpi
            LEFT JOIN public.bd_banks b ON b.id = gpi.bd_bank_id
            WHERE gpi.payment_id = gp.id
          ),
          '[]'::jsonb
        )
      END AS instruments
    FROM public.invoice_write_offs iwo
    LEFT JOIN public.pays gp ON gp.id = iwo.payment_id
    WHERE iwo.invoice_id = p_invoice_id
  ) r;

  RETURN v_result;
END;
$$;

GRANT SELECT ON public.v_kernel_bill_summaries TO authenticated;
GRANT SELECT ON public.v_kernel_bill_summaries TO service_role;

GRANT EXECUTE ON FUNCTION public._kernel_bill_open_components(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public._kernel_bill_open_components(bigint) TO service_role;

GRANT EXECUTE ON FUNCTION public.list_bills_for_source(
  bigint, text, text, text, boolean, boolean
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_bills_for_source(
  bigint, text, text, text, boolean, boolean
) TO service_role;

GRANT EXECUTE ON FUNCTION public.list_pays_for_source(bigint, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_pays_for_source(bigint, text, text) TO service_role;

GRANT EXECUTE ON FUNCTION public.list_open_on_profile(bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_open_on_profile(bigint, bigint) TO service_role;

GRANT EXECUTE ON FUNCTION public.list_invoice_payment_history(bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_invoice_payment_history(bigint, bigint) TO service_role;
