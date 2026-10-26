-- AP payout: allocation amounts are BDT (match AR receipts). Repair legacy inflated pays.amount.

CREATE OR REPLACE FUNCTION "public"."post_ap_payout_with_allocations"("p_tenant_id" bigint, "p_profile_id" bigint, "p_paid_on" "date", "p_note" "text" DEFAULT NULL::"text", "p_reference" "text" DEFAULT NULL::"text", "p_instruments" "jsonb" DEFAULT '[]'::"jsonb", "p_allocations" "jsonb" DEFAULT '[]'::"jsonb", "p_settlement_currency_code" "text" DEFAULT 'BDT'::"text", "p_foreign_amount" numeric DEFAULT NULL::numeric, "p_exchange_rate" numeric DEFAULT NULL::numeric) RETURNS "public"."pays"
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
begin
  if p_tenant_id is null then
    raise exception 'Tenant is required';
  end if;
  if p_profile_id is null then
    raise exception 'Profile is required';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

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
    v_amount, p_settlement_currency_code, p_foreign_amount, p_exchange_rate
  ) n;

  insert into public.pays (
    tenant_id, profile_id, source, amount, unallocated_amount,
    payment_date, method, reference, note,
    settlement_currency_code, foreign_amount, exchange_rate
  ) values (
    v_parent_id, p_profile_id, 'ap_payout', v_amount, 0,
    v_received_on, v_header_method, v_reference, v_note,
    v_settle_currency, v_foreign_amt, v_fx_rate
  ) returning * into v_pay;

  perform public.insert_global_payment_instruments(v_pay.id, p_instruments);

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
      if v_alloc_amount > coalesce(v_bill.due_amount, 0.00) then
        raise exception 'Allocation % exceeds bill % due %', v_alloc_amount, v_bill.invoice_no, v_bill.due_amount;
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
      'exchange_rate', v_fx_rate
    ),
    p_allow_overdraft => true
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


with repaired as (
  update public.pays p
  set
    amount = a.sum_alloc,
    foreign_amount = round(a.sum_alloc / p.exchange_rate, 2),
    unallocated_amount = 0
  from (
    select payment_id, sum(amount)::numeric(12, 2) as sum_alloc
    from public.pay_allocations
    group by payment_id
  ) a
  where p.id = a.payment_id
    and p.source = 'ap_payout'
    and coalesce(p.settlement_currency_code, 'BDT') <> 'BDT'
    and coalesce(p.exchange_rate, 0) > 0
    and a.sum_alloc > 0
    and abs(p.amount - a.sum_alloc * p.exchange_rate) < 0.05
  returning p.id, p.amount
)
update public.pay_instruments gpi
set amount = r.amount
from repaired r
where gpi.payment_id = r.id
  and gpi.sort_order = 0;
