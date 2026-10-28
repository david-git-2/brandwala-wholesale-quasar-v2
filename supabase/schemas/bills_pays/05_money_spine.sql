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
