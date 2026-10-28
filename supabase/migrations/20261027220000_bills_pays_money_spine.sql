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
  allocated_txn_amount numeric(12, 2) NOT NULL DEFAULT 0,
  allocated_books_amount numeric(12, 2) NOT NULL,
  books_rate_at_alloc numeric(15, 6),
  fx_realized_books_delta numeric(12, 2),
  created_at timestamptz NOT NULL DEFAULT now()
);

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

CREATE OR REPLACE FUNCTION public._kernel_insert_settlement_from_pay_alloc()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill_id bigint;
  v_bill public.bills;
  v_txn_amt numeric(12, 2);
  v_rate numeric(15, 6);
begin
  v_bill_id := public._kernel_resolve_bill_id_from_alloc(NEW.invoice_id, NEW.global_invoice_id, NEW.bill_id);
  if v_bill_id is null then
    return NEW;
  end if;

  select * into v_bill from public.bills where id = v_bill_id;
  if v_bill.id is null then
    return NEW;
  end if;

  v_rate := coalesce(v_bill.books_exchange_rate, 1.000000);
  v_txn_amt := case
    when coalesce(v_bill.txn_currency_code, v_bill.currency_code, 'BDT') = coalesce(v_bill.currency_code, 'BDT')
      then NEW.amount
    when v_rate > 0 then round(NEW.amount / v_rate, 2)
    else NEW.amount
  end;

  insert into public.bill_settlements (
    parent_tenant_id,
    bill_id,
    allocator_kind,
    allocator_id,
    allocated_txn_amount,
    allocated_books_amount,
    books_rate_at_alloc,
    fx_realized_books_delta
  ) values (
    v_bill.parent_tenant_id,
    v_bill_id,
    'pay',
    NEW.payment_id,
    v_txn_amt,
    NEW.amount,
    v_rate,
    NEW.amount - round(v_txn_amt * v_rate, 2)
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

  if v_settled = 0 then
    select coalesce(sum(pa.amount), 0.00) into v_settled
    from public.pay_allocations pa
    where public._kernel_resolve_bill_id_from_alloc(pa.invoice_id, pa.global_invoice_id, pa.bill_id) = v_root.id;
  end if;

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
        ), v_settled / coalesce(v_root.books_exchange_rate, 1)),
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
-- allocate_payment: lock bill before balance check; set bill_id on alloc
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
    txn_currency_code = coalesce(txn_currency_code, currency_code, 'BDT'),
    txn_total_amount = coalesce(txn_total_amount, total_amount),
    books_exchange_rate = coalesce(books_exchange_rate, 1.000000),
    updated_at = now()
  where id = p_bill_id
  returning * into v_bill;

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
begin
  v_tenant_id := nullif(p_payload->>'tenant_id', '')::bigint;
  if v_tenant_id is null then
    raise exception 'tenant_id required';
  end if;

  v_result := public.create_sales_invoice_from_payload(v_tenant_id, p_payload);
  if coalesce(v_result->>'success', 'false') <> 'true' then
    raise exception '%', coalesce(v_result->>'error', 'upsert_draft_bill failed');
  end if;
  select * into v_bill from public.bills where id = (v_result->>'invoice_id')::bigint;
  return v_bill;
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
  p_idempotency_key text DEFAULT NULL
) RETURNS public.pays
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_existing public.pays;
  v_pay public.pays;
begin
  if p_idempotency_key is not null and btrim(p_idempotency_key) <> '' then
    select * into v_existing
    from public.pays
    where tenant_id = public.resolve_parent_tenant_id(p_tenant_id)
      and idempotency_key = btrim(p_idempotency_key)
    limit 1;
    if v_existing.id is not null then
      return v_existing;
    end if;
  end if;

  v_pay := public.post_customer_receipt_with_allocations(
    p_tenant_id, p_profile_id, p_received_on, p_note, p_reference, p_source,
    p_instruments, p_allocations, p_shop_order_id,
    p_settlement_currency_code, p_foreign_amount, p_exchange_rate
  );

  if p_idempotency_key is not null and btrim(p_idempotency_key) <> '' then
    update public.pays set idempotency_key = btrim(p_idempotency_key) where id = v_pay.id;
    select * into v_pay from public.pays where id = v_pay.id;
  end if;

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
  p_idempotency_key text DEFAULT NULL
) RETURNS public.pays
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_existing public.pays;
  v_pay public.pays;
  v_disp jsonb;
begin
  if p_idempotency_key is not null and btrim(p_idempotency_key) <> '' then
    select * into v_existing
    from public.pays
    where tenant_id = public.resolve_parent_tenant_id(p_tenant_id)
      and idempotency_key = btrim(p_idempotency_key)
    limit 1;
    if v_existing.id is not null then
      return v_existing;
    end if;
  end if;

  if coalesce(p_source_type, '') = 'commission' or p_source = 'commission' then
    v_disp := public.dispense_middleman_payout_from_tenant(
      p_tenant_id, p_profile_id, p_amount, 'bank_transfer', p_note, p_cashbook_point_id, null
    );
    if coalesce(v_disp->>'success', 'false') <> 'true' then
      raise exception '%', coalesce(v_disp->>'error', 'commission payout failed');
    end if;
    return null;
  end if;

  if p_cashbook_point_id is null then
    raise exception 'cashbook_point_id required for pay out';
  end if;

  v_pay := public.post_ap_payout_with_allocations(
    p_tenant_id, p_profile_id, p_paid_on, p_cashbook_point_id, p_note, p_reference,
    p_instruments, p_allocations, p_settlement_currency_code, p_foreign_amount, p_exchange_rate,
    null, null, null
  );

  if p_idempotency_key is not null and btrim(p_idempotency_key) <> '' then
    update public.pays set idempotency_key = btrim(p_idempotency_key) where id = v_pay.id;
    select * into v_pay from public.pays where id = v_pay.id;
  end if;

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
  v_row public.bill_settlements;
begin
  perform public._kernel_lock_bills(array[p_bill_id]);
  select * into v_bill from public.bills where id = p_bill_id;
  if v_bill.parent_tenant_id <> public.resolve_parent_tenant_id(p_tenant_id) then
    raise exception 'tenant mismatch';
  end if;

  insert into public.bill_settlements (
    parent_tenant_id, bill_id, allocator_kind, allocator_id,
    allocated_txn_amount, allocated_books_amount
  ) values (
    v_bill.parent_tenant_id, p_bill_id, p_allocator_kind, p_allocator_id,
    p_books_amount, p_books_amount
  )
  returning * into v_row;

  perform public.recompute_global_invoice_payment_status(p_bill_id);
  return v_row;
end;
$$;

CREATE OR REPLACE FUNCTION public.reverse_pay(p_payment_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  perform public.void_customer_receipt(p_payment_id);
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

GRANT SELECT, INSERT ON public.bill_settlements TO authenticated;
GRANT ALL ON public.bill_settlements TO service_role;

-- Backfill settlements from historical pay_allocations (BP18)
INSERT INTO public.bill_settlements (
  parent_tenant_id,
  bill_id,
  allocator_kind,
  allocator_id,
  allocated_txn_amount,
  allocated_books_amount,
  books_rate_at_alloc,
  fx_realized_books_delta
)
SELECT
  b.parent_tenant_id,
  public._kernel_resolve_bill_id_from_alloc(pa.invoice_id, pa.global_invoice_id, pa.bill_id),
  'pay',
  pa.payment_id,
  pa.amount,
  pa.amount,
  coalesce(b.books_exchange_rate, 1.000000),
  0
FROM public.pay_allocations pa
JOIN public.bills b
  ON b.id = public._kernel_resolve_bill_id_from_alloc(pa.invoice_id, pa.global_invoice_id, pa.bill_id)
WHERE NOT EXISTS (
  SELECT 1
  FROM public.bill_settlements bs
  WHERE bs.allocator_kind = 'pay'
    AND bs.allocator_id = pa.payment_id
    AND bs.bill_id = public._kernel_resolve_bill_id_from_alloc(pa.invoice_id, pa.global_invoice_id, pa.bill_id)
    AND bs.allocated_books_amount = pa.amount
);

-- BP8 backfill source plug from legacy FKs
UPDATE public.bills
SET
  source_type = coalesce(source_type, 'shop_order'),
  source_id = coalesce(source_id, shop_order_id::text)
WHERE shop_order_id IS NOT NULL
  AND (source_type IS NULL OR source_id IS NULL);

UPDATE public.bills
SET
  source_type = coalesce(source_type, 'shipment_cost'),
  source_id = coalesce(source_id, ap_shipment_id::text),
  source_key = coalesce(source_key, ap_kind)
WHERE ap_shipment_id IS NOT NULL
  AND invoice_type = 'ap'::public.global_invoice_type
  AND (source_type IS NULL OR source_id IS NULL);

DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT id FROM public.bills WHERE from_profile_id IS NULL OR to_profile_id IS NULL
  LOOP
    PERFORM public.stamp_bill_kernel_fields(r.id);
  END LOOP;
END;
$$;

DROP INDEX IF EXISTS public.sales_invoices_shop_order_id_uidx;

GRANT EXECUTE ON FUNCTION public.issue_bill(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.void_bill(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.upsert_draft_bill(jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.post_money_in(bigint, bigint, date, text, text, text, jsonb, jsonb, bigint, text, numeric, numeric, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.post_money_out(bigint, bigint, date, numeric, text, text, text, bigint, jsonb, jsonb, text, numeric, numeric, text, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.apply_settlement_to_bill(bigint, bigint, text, bigint, numeric) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.reverse_pay(bigint) TO authenticated, service_role;
