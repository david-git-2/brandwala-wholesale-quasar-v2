-- Deferred from 20261004195000_shipment_ap_bills_wa15.sql (stubbed: bills/pays not renamed yet).
-- WA15: shipment AP bills + ap_payout (enum value added in 20261004194800_add_ap_invoice_type.sql)

alter table public.bills
  add column if not exists ap_shipment_id bigint,
  add column if not exists ap_kind text;

alter table public.bills drop constraint if exists bills_ap_kind_check;
alter table public.bills
  add constraint bills_ap_kind_check
  check (ap_kind is null or ap_kind = any (array['vendor'::text, 'cargo'::text, 'local'::text]));

alter table public.pays drop constraint if exists pays_source_check;
alter table public.pays
  add constraint pays_source_check
  check (source = any (array[
    'customer_cash'::text, 'bank'::text, 'store_credit'::text, 'courier_remittance'::text, 'ap_payout'::text
  ]));

create unique index if not exists bills_ap_shipment_kind_uidx
  on public.bills (parent_tenant_id, ap_shipment_id, ap_kind)
  where invoice_type = 'ap'::public.global_invoice_type
    and ap_shipment_id is not null
    and ap_kind is not null;

create index if not exists bills_ap_shipment_id_idx
  on public.bills (ap_shipment_id)
  where invoice_type = 'ap'::public.global_invoice_type;

alter table public.bills drop constraint if exists bills_ap_shipment_id_fkey;
alter table public.bills
  add constraint bills_ap_shipment_id_fkey
  foreign key (ap_shipment_id) references public.global_shipments (id) on delete cascade;

-- Functions: copied from supabase/schemas/bills_pays/03_rpcs.sql (sync + payout + helper)
CREATE OR REPLACE FUNCTION "public"."_upsert_shipment_ap_bill"("p_parent_tenant_id" bigint, "p_issued_by_tenant_id" bigint, "p_shipment_id" bigint, "p_shipment_name" "text", "p_ap_kind" "text", "p_profile_id" bigint, "p_amount" numeric) RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_bill public.bills;
  v_target numeric(12, 2);
  v_due numeric(12, 2);
  v_status text;
  v_invoice_no text;
  v_kind_label text;
begin
  if p_ap_kind not in ('vendor', 'cargo', 'local') then
    raise exception 'Invalid ap_kind %', p_ap_kind;
  end if;

  select * into v_bill
  from public.bills b
  where b.parent_tenant_id = p_parent_tenant_id
    and b.ap_shipment_id = p_shipment_id
    and b.ap_kind = p_ap_kind
    and b.invoice_type = 'ap'::public.global_invoice_type
  for update;

  if p_profile_id is null or coalesce(p_amount, 0) <= 0 then
    if v_bill.id is not null and coalesce(v_bill.paid_amount, 0) = 0
       and v_bill.invoice_status = 'issued'::public.global_invoice_status then
      update public.bills
      set invoice_status = 'voided'::public.global_invoice_status, updated_at = now()
      where id = v_bill.id;
    end if;
    return null;
  end if;

  v_target := round(p_amount, 2);
  v_kind_label := initcap(p_ap_kind);

  if v_bill.id is null then
    v_invoice_no := public.generate_sales_invoice_number(p_issued_by_tenant_id, 'ap'::public.global_invoice_type, current_date);
    insert into public.bills (
      parent_tenant_id, issued_by_tenant_id, invoice_no, invoice_type, invoice_date,
      invoice_status, profile_id, collection_source, payment_status,
      subtotal_amount, total_amount, due_amount, paid_amount,
      ap_shipment_id, ap_kind, note, channel_meta
    ) values (
      p_parent_tenant_id, p_issued_by_tenant_id, v_invoice_no, 'ap'::public.global_invoice_type, current_date,
      'issued'::public.global_invoice_status, p_profile_id, 'billing_profile'::public.collection_source_type, 'due',
      v_target, v_target, v_target, 0,
      p_shipment_id, p_ap_kind,
      format('Shipment %s — %s AP', coalesce(p_shipment_name, p_shipment_id::text), v_kind_label),
      jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id)
    )
    returning id into v_bill.id;
    return v_bill.id;
  end if;

  if v_bill.invoice_status = 'voided'::public.global_invoice_status then
    return v_bill.id;
  end if;

  v_target := greatest(v_target, coalesce(v_bill.paid_amount, 0));
  v_due := greatest(v_target - coalesce(v_bill.paid_amount, 0), 0);
  v_status := case
    when v_due <= 0 then 'paid'
    when coalesce(v_bill.paid_amount, 0) > 0 then 'partially_paid'
    else 'due'
  end;

  update public.bills
  set
    profile_id = p_profile_id,
    subtotal_amount = v_target,
    total_amount = v_target,
    due_amount = v_due,
    payment_status = v_status,
    note = format('Shipment %s — %s AP', coalesce(p_shipment_name, p_shipment_id::text), v_kind_label),
    channel_meta = coalesce(channel_meta, '{}'::jsonb) || jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id),
    updated_at = now()
  where id = v_bill.id;

  return v_bill.id;
end;
$$;

ALTER FUNCTION "public"."_upsert_shipment_ap_bill"("p_parent_tenant_id" bigint, "p_issued_by_tenant_id" bigint, "p_shipment_id" bigint, "p_shipment_name" "text", "p_ap_kind" "text", "p_profile_id" bigint, "p_amount" numeric) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."sync_shipment_ap_bills"("p_shipment_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments;
  v_parent bigint;
  v_issued_by bigint;
  v_vendor_profile bigint;
  v_cargo_profile bigint;
  v_local_profile bigint;
  v_vendor_amt numeric(12, 2) := 0;
  v_cargo_amt numeric(12, 2) := 0;
  v_local_amt numeric(12, 2) := 0;
  v_extra_local numeric(12, 2) := 0;
  v_tenant_name text;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  select * into v_ship from public.global_shipments where id = p_shipment_id;
  if v_ship.id is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  v_parent := v_ship.parent_tenant_id;
  v_issued_by := coalesce(v_ship.assigned_child_tenant_id, v_parent);

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_parent)
  ) then
    raise exception 'Permission denied';
  end if;

  select coalesce(sum(round(e.amount * coalesce(e.exchange_rate, 1), 2)), 0)
  into v_vendor_amt
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id
    and e.cost_type = 'product'::public.global_shipment_cost_type;

  if v_vendor_amt = 0 then
    v_vendor_amt := coalesce(round(v_ship.purchase_invoice_total, 2), 0);
  end if;

  select coalesce(sum(round(e.amount * coalesce(e.exchange_rate, 1), 2)), 0)
  into v_cargo_amt
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id
    and e.cost_type in ('cargo'::public.global_shipment_cost_type, 'duty'::public.global_shipment_cost_type);

  if v_cargo_amt = 0 then
    v_cargo_amt := coalesce(round(v_ship.cargo_invoice_total, 2), 0);
  end if;

  select coalesce(sum(round(lc.amount, 2)), 0)
  into v_local_amt
  from public.global_shipment_local_costs lc
  where lc.shipment_id = p_shipment_id;

  select coalesce(sum(round(e.amount * coalesce(e.exchange_rate, 1), 2)), 0)
  into v_extra_local
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id
    and e.cost_type in (
      'insurance'::public.global_shipment_cost_type,
      'labor'::public.global_shipment_cost_type,
      'washing'::public.global_shipment_cost_type,
      'transport'::public.global_shipment_cost_type,
      'handling'::public.global_shipment_cost_type
    );

  v_local_amt := v_local_amt + v_extra_local;

  if v_ship.vendor_id is not null then
    select pr.id into v_vendor_profile
    from public.profiles pr
    where pr.parent_tenant_id = v_parent
      and pr.profile_type = 'vendor'::public.profile_party_type
      and pr.subject_id = v_ship.vendor_id;
  end if;

  if v_ship.cargo_company_id is not null then
    select pr.id into v_cargo_profile
    from public.profiles pr
    where pr.parent_tenant_id = v_parent
      and pr.profile_type = 'cargo'::public.profile_party_type
      and pr.subject_id = v_ship.cargo_company_id;
  end if;

  select t.name into v_tenant_name from public.tenants t where t.id = v_parent;

  v_local_profile := public.upsert_profile_for_party(
    v_parent,
    'company'::public.profile_party_type,
    v_parent,
    coalesce(v_tenant_name, 'Local opex'),
    null, null, '+880', null, false, null, true, null
  );

  if v_ship.status = 'cancelled' then
    update public.bills
    set invoice_status = 'voided'::public.global_invoice_status, updated_at = now()
    where parent_tenant_id = v_parent
      and ap_shipment_id = p_shipment_id
      and invoice_type = 'ap'::public.global_invoice_type
      and invoice_status = 'issued'::public.global_invoice_status
      and coalesce(paid_amount, 0) = 0;
    return jsonb_build_object('success', true, 'cancelled', true);
  end if;

  return jsonb_build_object(
    'success', true,
    'vendor_bill_id', public._upsert_shipment_ap_bill(v_parent, v_issued_by, p_shipment_id, v_ship.name, 'vendor', v_vendor_profile, v_vendor_amt),
    'cargo_bill_id', public._upsert_shipment_ap_bill(v_parent, v_issued_by, p_shipment_id, v_ship.name, 'cargo', v_cargo_profile, v_cargo_amt),
    'local_bill_id', public._upsert_shipment_ap_bill(v_parent, v_issued_by, p_shipment_id, v_ship.name, 'local', v_local_profile, v_local_amt)
  );
end;
$$;

ALTER FUNCTION "public"."sync_shipment_ap_bills"("p_shipment_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."post_ap_payout_with_allocations"("p_tenant_id" bigint, "p_profile_id" bigint, "p_paid_on" "date", "p_note" "text" DEFAULT NULL::"text", "p_reference" "text" DEFAULT NULL::"text", "p_instruments" "jsonb" DEFAULT '[]'::"jsonb", "p_allocations" "jsonb" DEFAULT '[]'::"jsonb") RETURNS "public"."pays"
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

  insert into public.pays (
    tenant_id, profile_id, source, amount, unallocated_amount,
    payment_date, method, reference, note
  ) values (
    v_parent_id, p_profile_id, 'ap_payout', v_amount, 0,
    v_received_on, v_header_method, v_reference, v_note
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

      insert into public.pay_allocations (tenant_id, payment_id, global_invoice_id, amount)
      values (v_parent_id, v_pay.id, v_bill_id, v_alloc_amount);

      perform public.recompute_global_invoice_payment_status(v_bill_id);
      v_total_alloc := v_total_alloc + v_alloc_amount;
    end loop;
  end if;

  if v_total_alloc <> v_amount then
    raise exception 'AP payout allocations (%) must equal payment amount (%)', v_total_alloc, v_amount;
  end if;

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
      'reference', v_reference
    )
  );

  return v_pay;
end;
$$;

ALTER FUNCTION "public"."post_ap_payout_with_allocations"("p_tenant_id" bigint, "p_profile_id" bigint, "p_paid_on" "date", "p_note" "text", "p_reference" "text", "p_instruments" "jsonb", "p_allocations" "jsonb") OWNER TO "postgres";

grant execute on function public.sync_shipment_ap_bills(bigint) to authenticated, service_role;
grant execute on function public.post_ap_payout_with_allocations(bigint, bigint, date, text, text, jsonb, jsonb) to authenticated, service_role;
