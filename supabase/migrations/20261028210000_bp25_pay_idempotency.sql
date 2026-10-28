-- BP25 pay idempotency


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
    p_idempotency_key
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
  p_idempotency_key text DEFAULT NULL
) RETURNS public.pays
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_pay public.pays;
  v_disp jsonb;
begin
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

  return public._kernel_finalize_pay_idempotency(v_pay.id, v_parent_id, p_idempotency_key);
end;
$$;


CREATE OR REPLACE FUNCTION "public"."post_ap_payout_with_allocations_snapshot"("p_tenant_id" bigint, "p_profile_id" bigint, "p_paid_on" "date", "p_cashbook_point_id" bigint, "p_note" "text" DEFAULT NULL::"text", "p_reference" "text" DEFAULT NULL::"text", "p_instruments" "jsonb" DEFAULT '[]'::"jsonb", "p_allocations" "jsonb" DEFAULT '[]'::"jsonb", "p_settlement_currency_code" "text" DEFAULT 'BDT'::"text", "p_foreign_amount" numeric DEFAULT NULL::numeric, "p_exchange_rate" numeric DEFAULT NULL::numeric, "p_source_currency_code" "text" DEFAULT NULL::"text", "p_transaction_rate" numeric DEFAULT NULL::numeric, "p_cashbook_point_pot_id" bigint DEFAULT NULL::bigint, "p_idempotency_key" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_pay public.pays;
  v_bill_id bigint;
BEGIN
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
    p_source_currency_code,
    p_transaction_rate,
    p_cashbook_point_pot_id,
    p_idempotency_key
  );

  v_bill_id := NULL;
  IF p_allocations IS NOT NULL AND jsonb_typeof(p_allocations) = 'array' THEN
    SELECT (elem->>'bill_id')::bigint
    INTO v_bill_id
    FROM jsonb_array_elements(p_allocations) AS elem
    WHERE nullif(trim(elem->>'bill_id'), '') IS NOT NULL
    LIMIT 1;
  END IF;

  IF v_bill_id IS NULL THEN
    RETURN jsonb_build_object('pay', to_jsonb(v_pay));
  END IF;

  RETURN jsonb_build_object(
    'pay', to_jsonb(v_pay),
    'bill', (SELECT to_jsonb(b) FROM public.bills b WHERE b.id = v_bill_id),
    'net_balances', public.get_bill_net_balances(v_bill_id),
    'payment_history', public.list_invoice_payment_history(p_tenant_id, v_bill_id)
  );
END;
$$;


CREATE OR REPLACE FUNCTION "public"."post_customer_receipt_with_allocations"("p_tenant_id" bigint, "p_profile_id" bigint, "p_received_on" "date", "p_note" "text" DEFAULT NULL::"text", "p_reference" "text" DEFAULT NULL::"text", "p_source" "text" DEFAULT 'customer_cash'::"text", "p_instruments" "jsonb" DEFAULT '[]'::"jsonb", "p_allocations" "jsonb" DEFAULT '[]'::"jsonb", "p_shop_order_id" bigint DEFAULT NULL::bigint, "p_settlement_currency_code" "text" DEFAULT 'BDT'::"text", "p_foreign_amount" numeric DEFAULT NULL::numeric, "p_exchange_rate" numeric DEFAULT NULL::numeric, "p_credit_dropship_profit" boolean DEFAULT true, "p_idempotency_key" "text" DEFAULT NULL::"text") RETURNS "public"."pays"
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

  insert into public.pays (
    tenant_id, profile_id, source, amount, unallocated_amount,
    payment_date, method, reference, note, shop_order_id,
    settlement_currency_code, foreign_amount, exchange_rate
  ) values (
    v_parent_id, p_profile_id, v_source, v_amount, v_amount,
    v_received_on, v_header_method, v_reference, v_note, p_shop_order_id,
    v_settle_currency, v_foreign_amt, v_fx_rate
  ) returning * into v_pay;

  if v_line_count > 0 then
    perform public.insert_global_payment_instruments(v_pay.id, p_instruments);
  end if;

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
      if v_alloc_amount > coalesce(v_bill.due_amount, 0.00) then
        raise exception 'Allocation % exceeds bill % due %', v_alloc_amount, v_bill.invoice_no, v_bill.due_amount;
      end if;

      insert into public.pay_allocations (tenant_id, payment_id, global_invoice_id, bill_id, amount)
      values (v_parent_id, v_pay.id, v_bill_id, v_bill_id, v_alloc_amount);

      perform public.recompute_global_invoice_payment_status(v_bill_id);
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

  v_cashbook_point_id := null;
  if coalesce(jsonb_typeof(p_instruments), 'null') = 'array' then
    for v_line in select value from jsonb_array_elements(p_instruments)
    loop
      if nullif(v_line.value ->> 'cashbook_point_id', '') is not null then
        v_cashbook_point_id := (v_line.value ->> 'cashbook_point_id')::bigint;
        exit;
      end if;
    end loop;
  end if;

  if v_source in ('customer_cash', 'bank', 'courier_remittance') then
    if v_source = 'courier_remittance' and v_cashbook_point_id is null then
      raise exception 'Courier remittance requires a cashbook location';
    end if;

    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_id,
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_parent_id,
      p_type => 'credit',
      p_amount => v_amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
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
        'shop_order_id', case when v_source = 'courier_remittance' then p_shop_order_id else null end
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

