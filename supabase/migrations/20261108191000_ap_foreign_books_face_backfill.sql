-- Foreign shipment AP: books leg starts at 0; txn face in GBP. Fix payout due check + backfill bad rows.

-- Shipment 46 material: remove header backfill row; face = 4695 GBP.
DELETE FROM public.global_shipment_cost_entries
WHERE id = 98
  AND shipment_id = 46
  AND coalesce(amount, 0) = 0;

UPDATE public.global_shipment_cost_entries
SET amount = 4695.00, updated_at = now()
WHERE id = 99
  AND shipment_id = 46;

-- Unpaid issued foreign AP bills that stored foreign face in books columns.
UPDATE public.bills b
SET
  subtotal_amount = 0,
  total_amount = 0,
  due_amount = 0,
  books_exchange_rate = null,
  updated_at = now()
WHERE b.invoice_type = 'ap'::public.global_invoice_type
  AND b.invoice_status = 'issued'::public.global_invoice_status
  AND coalesce(b.paid_amount, 0) = 0
  AND b.ap_shipment_id is not null
  AND upper(coalesce(public.ap_bill_channel_currency(b.channel_meta), 'BDT')) <> 'BDT'
  AND coalesce(b.total_amount, 0) > 0
  AND coalesce(b.total_amount, 0) = public.ap_bill_channel_foreign_face(b.channel_meta);

-- AP-2611-0001: align paper to 4695 GBP (was 4699 from double subtotal line).
UPDATE public.bills
SET
  channel_meta = jsonb_set(
    jsonb_set(
      jsonb_set(
        jsonb_set(
          channel_meta,
          '{ap_paper,foreign_total}',
          '"4695.00"'::jsonb
        ),
        '{ap_paper,currency_groups,0,foreign_total}',
        '4695'::jsonb
      ),
      '{ap_paper,currency_groups,0,lines,0,amount}',
        '4695.00'::jsonb
    ),
    '{ap_paper,lines,0,amount}',
    '4695.00'::jsonb
  )
WHERE invoice_no = 'AP-2611-0001';

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
      when v_foreign > 0 and coalesce(v_bill.total_amount, 0) > 0
        then round(v_bill.total_amount / v_foreign, 6)
      else null
    end;
    update public.bills
    set
      txn_currency_code = coalesce(txn_currency_code, upper(btrim(v_paper_ccy))),
      txn_total_amount = coalesce(txn_total_amount, v_foreign),
      books_exchange_rate = coalesce(
        books_exchange_rate,
        v_rate,
        case
          when upper(btrim(v_paper_ccy)) = upper(public.resolve_tenant_base_currency_code(v_bill.tenant_id))
            then 1.000000
          else null
        end
      ),
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

CREATE OR REPLACE FUNCTION public._upsert_shipment_ap_bill(
  p_tenant_id bigint,
  p_issued_by_tenant_id bigint,
  p_shipment_id bigint,
  p_shipment_name text,
  p_ap_kind text,
  p_profile_id bigint,
  p_amount numeric,
  p_ap_paper jsonb DEFAULT NULL,
  p_keep_as_draft boolean DEFAULT false,
  p_source_key text DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill public.bills;
  v_target numeric(12, 2);
  v_old_total numeric(12, 2);
  v_due numeric(12, 2);
  v_status text;
  v_invoice_no text;
  v_kind_label text;
  v_meta_base jsonb;
  v_paper_status public.global_invoice_status;
  v_plug_key text;
  v_face_currency text;
  v_base_note text;
  v_note text;
  v_books_target numeric(12, 2);
begin
  if p_ap_kind not in (
    'vendor', 'cargo', 'local',
    'material', 'freight', 'customs', 'handling', 'finance', 'other'
  ) then
    raise exception 'Invalid ap_kind %', p_ap_kind;
  end if;

  v_plug_key := coalesce(nullif(btrim(p_source_key), ''), p_ap_kind);
  v_face_currency := upper(trim(coalesce(p_ap_paper->>'currency_code', 'BDT')));

  select * into v_bill
  from public.bills b
  where b.tenant_id = p_tenant_id
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and b.source_type = 'shipment_cost'
    and b.source_id = p_shipment_id::text
    and b.source_key = v_plug_key
  for update;

  if p_profile_id is null or coalesce(p_amount, 0) <= 0 then
    if v_bill.id is not null and coalesce(v_bill.paid_amount, 0) = 0
       and v_bill.invoice_status in (
         'issued'::public.global_invoice_status,
         'draft'::public.global_invoice_status
       ) then
      update public.bills
      set invoice_status = 'voided'::public.global_invoice_status, updated_at = now()
      where id = v_bill.id;
    end if;
    return null;
  end if;

  v_target := round(p_amount, 2);
  v_books_target := v_target;
  if upper(v_face_currency) not in ('', 'BDT')
     and upper(v_face_currency) <> upper(public.resolve_tenant_base_currency_code(p_tenant_id)) then
    v_books_target := coalesce(nullif((p_ap_paper->>'bdt_amount')::numeric, 0), 0);
  end if;
  v_kind_label := initcap(replace(p_ap_kind, '_', ' '));
  v_meta_base := jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id);
  if p_ap_paper is not null then
    v_meta_base := v_meta_base || jsonb_build_object('ap_paper', p_ap_paper);
  end if;

  v_base_note := format(
    'Shipment %s — %s AP%s',
    coalesce(p_shipment_name, p_shipment_id::text),
    v_kind_label,
    case when v_plug_key <> p_ap_kind then ' (' || v_plug_key || ')' else '' end
  );

  v_paper_status := case
    when p_keep_as_draft then 'draft'::public.global_invoice_status
    else 'issued'::public.global_invoice_status
  end;

  if v_bill.id is null then
    v_invoice_no := public.generate_sales_invoice_number(
      p_issued_by_tenant_id,
      'ap'::public.global_invoice_type,
      current_date
    );
    insert into public.bills (
      tenant_id, issued_by_tenant_id, invoice_no, invoice_type, invoice_date,
      invoice_status, profile_id, collection_source, payment_status,
      subtotal_amount, total_amount, due_amount, paid_amount,
      ap_shipment_id, ap_kind, source_type, source_id, source_key, currency_code,
      note, channel_meta, document_kind
    ) values (
      p_tenant_id, p_issued_by_tenant_id, v_invoice_no, 'ap'::public.global_invoice_type, current_date,
      v_paper_status, p_profile_id, 'profile'::public.collection_source_type, 'due',
      v_books_target, v_books_target, v_books_target, 0,
      p_shipment_id, p_ap_kind, 'shipment_cost', p_shipment_id::text, v_plug_key, v_face_currency,
      v_base_note,
      v_meta_base,
      'standard'::public.bill_document_kind
    )
    returning id into v_bill.id;
    perform public.stamp_bill_kernel_fields(v_bill.id);
    return v_bill.id;
  end if;

  if v_bill.invoice_status = 'issued'::public.global_invoice_status then
    if coalesce(v_bill.paid_amount, 0) = 0
       and not exists (
         select 1 from public.bill_settlements bs where bs.bill_id = v_bill.id
       )
       and p_ap_paper is not null then
      update public.bills
      set
        channel_meta = coalesce(channel_meta, '{}'::jsonb)
          || jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id)
          || jsonb_build_object('ap_paper', p_ap_paper),
        updated_at = now()
      where id = v_bill.id;
    end if;
    return v_bill.id;
  end if;

  if v_bill.invoice_status = 'voided'::public.global_invoice_status then
    if coalesce(v_bill.paid_amount, 0) > 0 then
      return v_bill.id;
    end if;

    update public.bills
    set
      invoice_status = v_paper_status,
      profile_id = p_profile_id,
      subtotal_amount = v_books_target,
      total_amount = v_books_target,
      due_amount = v_books_target,
      payment_status = 'due',
      source_type = coalesce(source_type, 'shipment_cost'),
      source_id = coalesce(source_id, p_shipment_id::text),
      source_key = coalesce(source_key, v_plug_key),
      currency_code = coalesce(nullif(trim(v_face_currency), ''), nullif(trim(currency_code), ''), 'BDT'),
      note = v_base_note,
      channel_meta = coalesce(channel_meta, '{}'::jsonb)
        || jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id)
        || case
          when p_ap_paper is not null then jsonb_build_object('ap_paper', p_ap_paper)
          else '{}'::jsonb
        end,
      updated_at = now()
    where id = v_bill.id;

    perform public.stamp_bill_kernel_fields(v_bill.id);
    return v_bill.id;
  end if;

  v_old_total := round(coalesce(v_bill.total_amount, 0), 2);
  v_note := coalesce(nullif(trim(v_bill.note), ''), v_base_note);
  if v_old_total is distinct from v_books_target then
    v_note := v_note || format(
      E'\nCost sync %s: %s → %s books (face %s %s)',
      to_char(current_date, 'YYYY-MM-DD'),
      v_old_total,
      v_books_target,
      v_target,
      v_face_currency
    );
  end if;

  v_due := greatest(v_books_target - coalesce(v_bill.paid_amount, 0), 0);
  v_status := case
    when v_due <= 0 then 'paid'
    when coalesce(v_bill.paid_amount, 0) > 0 then 'partially_paid'
    else 'due'
  end;

  update public.bills
  set
    profile_id = p_profile_id,
    subtotal_amount = v_books_target,
    total_amount = v_books_target,
    due_amount = v_due,
    payment_status = v_status,
    source_type = coalesce(source_type, 'shipment_cost'),
    source_id = coalesce(source_id, p_shipment_id::text),
    source_key = coalesce(source_key, v_plug_key),
    currency_code = coalesce(nullif(trim(v_face_currency), ''), nullif(trim(currency_code), ''), 'BDT'),
    note = v_note,
    channel_meta = coalesce(channel_meta, '{}'::jsonb)
      || jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id)
      || case
        when p_ap_paper is not null and coalesce(v_bill.paid_amount, 0) = 0
        then jsonb_build_object('ap_paper', p_ap_paper)
        else '{}'::jsonb
      end,
    updated_at = now()
  where id = v_bill.id;

  perform public.stamp_bill_kernel_fields(v_bill.id);
  return v_bill.id;
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

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);
  v_base_currency := public.resolve_tenant_base_currency_code(p_tenant_id);

  v_pay := public._kernel_claim_pay_idempotency(v_parent_id, p_idempotency_key);
  if v_pay.id is not null then
    return v_pay;
  end if;

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_books_tenant(v_parent_id)
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
    where pr.id = p_profile_id and pr.tenant_id = v_parent_id
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
      and ca.tenant_id = v_parent_id
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
      and cpp.tenant_id = v_parent_id
    order by case when upper(cpp.currency_code) = 'BDT' then 0 else 1 end, cpp.id
    limit 1;
  end if;

  if v_pot_id is null and coalesce(v_source_currency, '') <> '' then
    select cpp.id
    into v_pot_id
    from public.cashbook_point_pots cpp
    where cpp.cashbook_point_id = p_cashbook_point_id
      and cpp.tenant_id = v_parent_id
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
      if v_bill.tenant_id <> v_parent_id then
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

        v_effective_due := coalesce(v_bill.due_amount, 0);
        if v_effective_due <= v_foreign_face + 0.01 then
          v_effective_due := round(v_foreign_face * v_fx_rate, 2);
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
    p_tenant_id => v_parent_id,
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

SELECT public._kernel_freeze_bill_txn_face(id)
FROM public.bills
WHERE invoice_type = 'ap'::public.global_invoice_type
  AND invoice_status = 'issued'::public.global_invoice_status
  AND coalesce(paid_amount, 0) = 0
  AND ap_shipment_id is not null
  AND upper(coalesce(public.ap_bill_channel_currency(channel_meta), 'BDT')) <> 'BDT';
