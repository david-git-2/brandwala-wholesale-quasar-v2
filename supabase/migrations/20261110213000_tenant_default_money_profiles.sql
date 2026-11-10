-- Default income/expense company profiles; pays.from/to_profile_id + description.

ALTER TABLE public.pays
  ADD COLUMN IF NOT EXISTS from_profile_id bigint,
  ADD COLUMN IF NOT EXISTS to_profile_id bigint,
  ADD COLUMN IF NOT EXISTS description text;

CREATE INDEX IF NOT EXISTS pays_from_profile_id_idx ON public.pays USING btree (from_profile_id);
CREATE INDEX IF NOT EXISTS pays_to_profile_id_idx ON public.pays USING btree (to_profile_id);

DROP FUNCTION IF EXISTS public.post_ap_payout_with_allocations(
  bigint, bigint, date, bigint, text, text, jsonb, jsonb, text, numeric, numeric, text, numeric, bigint, text
);

DROP FUNCTION IF EXISTS public.post_customer_receipt_with_allocations(
  bigint, bigint, date, text, text, text, jsonb, jsonb, bigint, text, numeric, numeric, boolean, text, bigint, bigint, text, numeric
);

-- Tenant default income/expense sink profiles + pay from/to resolution.

-- Reserved company subject_ids (unique per parent_tenant_id + profile_type).
-- Do not use for real parties.

CREATE OR REPLACE FUNCTION public._kernel_tenant_mirror_profile_id(p_books_tenant_id bigint)
RETURNS bigint
LANGUAGE sql
STABLE
SET search_path TO public
AS $$
  SELECT pr.id
  FROM public.profiles pr
  WHERE pr.tenant_id = p_books_tenant_id
    AND pr.profile_type = 'tenant'::public.profile_party_type
    AND pr.subject_id = p_books_tenant_id
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.ensure_tenant_default_money_profiles(p_books_tenant_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_income_id bigint;
  v_expense_id bigint;
  v_pref jsonb;
begin
  if p_books_tenant_id is null then
    raise exception 'books_tenant_id is required';
  end if;

  if not exists (select 1 from public.tenants t where t.id = p_books_tenant_id) then
    raise exception 'tenant % not found', p_books_tenant_id;
  end if;

  v_income_id := public.upsert_profile_for_party(
    p_books_tenant_id,
    'company'::public.profile_party_type,
    -900001,
    'Default income',
    null, null, '+880', null, false, null, true, null
  );

  v_expense_id := public.upsert_profile_for_party(
    p_books_tenant_id,
    'company'::public.profile_party_type,
    -900002,
    'Default expense',
    null, null, '+880', null, false, null, true, null
  );

  update public.tenants t
  set
    preference = coalesce(t.preference, '{}'::jsonb)
      || jsonb_build_object(
        'default_income_profile_id', v_income_id,
        'default_expense_profile_id', v_expense_id
      ),
    updated_at = now()
  where t.id = p_books_tenant_id;

  return jsonb_build_object(
    'default_income_profile_id', v_income_id,
    'default_expense_profile_id', v_expense_id
  );
end;
$$;

CREATE OR REPLACE FUNCTION public.get_tenant_default_income_profile_id(p_books_tenant_id bigint)
RETURNS bigint
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_id bigint;
begin
  select nullif(t.preference->>'default_income_profile_id', '')::bigint
  into v_id
  from public.tenants t
  where t.id = p_books_tenant_id;

  if v_id is not null then
    return v_id;
  end if;

  v_id := nullif(public.ensure_tenant_default_money_profiles(p_books_tenant_id)->>'default_income_profile_id', '')::bigint;
  return v_id;
end;
$$;

CREATE OR REPLACE FUNCTION public.get_tenant_default_expense_profile_id(p_books_tenant_id bigint)
RETURNS bigint
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_id bigint;
begin
  select nullif(t.preference->>'default_expense_profile_id', '')::bigint
  into v_id
  from public.tenants t
  where t.id = p_books_tenant_id;

  if v_id is not null then
    return v_id;
  end if;

  v_id := nullif(public.ensure_tenant_default_money_profiles(p_books_tenant_id)->>'default_expense_profile_id', '')::bigint;
  return v_id;
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_resolve_pay_profile_endpoints(
  p_books_id bigint,
  p_source text,
  p_counterparty_profile_id bigint,
  p_from_profile_id bigint DEFAULT NULL,
  p_to_profile_id bigint DEFAULT NULL,
  p_description text DEFAULT NULL,
  p_note text DEFAULT NULL
)
RETURNS TABLE (
  from_profile_id bigint,
  to_profile_id bigint,
  description text,
  legacy_profile_id bigint
)
LANGUAGE plpgsql
STABLE
SET search_path TO public
AS $$
declare
  v_source text := lower(trim(coalesce(p_source, '')));
  v_tenant_profile bigint;
  v_income bigint;
  v_expense bigint;
  v_from bigint;
  v_to bigint;
  v_desc text;
begin
  perform public.ensure_tenant_default_money_profiles(p_books_id);

  v_tenant_profile := public._kernel_tenant_mirror_profile_id(p_books_id);
  v_income := public.get_tenant_default_income_profile_id(p_books_id);
  v_expense := public.get_tenant_default_expense_profile_id(p_books_id);

  v_desc := coalesce(
    nullif(btrim(coalesce(p_description, '')), ''),
    nullif(btrim(coalesce(p_note, '')), ''),
    ''
  );

  if v_source = 'ap_payout' then
    v_from := coalesce(p_from_profile_id, v_tenant_profile, v_expense);
    v_to := coalesce(p_to_profile_id, p_counterparty_profile_id, v_expense);
  elsif v_source = ANY (ARRAY['customer_cash', 'bank', 'store_credit', 'courier_remittance', 'deposit']) then
    v_from := coalesce(p_from_profile_id, p_counterparty_profile_id, v_income);
    v_to := coalesce(p_to_profile_id, v_tenant_profile, v_income);
  else
    v_from := coalesce(p_from_profile_id, p_counterparty_profile_id, v_income);
    v_to := coalesce(p_to_profile_id, v_tenant_profile, v_expense);
  end if;

  if v_from is null or v_to is null then
    raise exception 'from_profile_id and to_profile_id are required';
  end if;

  return query
  select
    v_from,
    v_to,
    v_desc,
    coalesce(p_counterparty_profile_id, case when v_source = 'ap_payout' then v_to else v_from end);
end;
$$;

GRANT EXECUTE ON FUNCTION public.ensure_tenant_default_money_profiles(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_tenant_default_income_profile_id(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_tenant_default_expense_profile_id(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._kernel_tenant_mirror_profile_id(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._kernel_resolve_pay_profile_endpoints(
  bigint, text, bigint, bigint, bigint, text, text
) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.trg_sync_profile_from_tenant()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO public
  AS $function$
declare
  v_books_id bigint;
begin
  v_books_id := coalesce(new.parent_id, new.id);

  perform public.upsert_profile_for_party(
    v_books_id,
    'tenant'::public.profile_party_type,
    new.id,
    new.name,
    null,
    null,
    '+880',
    null,
    false,
    null,
    coalesce(new.is_active, true),
    null
  );

  perform public.ensure_tenant_default_money_profiles(v_books_id);

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_tenant_for_superadmin (
  p_name          text,
  p_slug          text,
  p_is_active     boolean DEFAULT true,
  p_public_domain text    DEFAULT NULL::text,
  p_parent_id     bigint  DEFAULT NULL::bigint
)
  RETURNS TABLE (
    id            bigint,
    name          text,
    slug          text,
    public_domain text,
    is_active     boolean,
    parent_id     bigint,
    preference    jsonb,
    created_at    timestamp with time zone,
    updated_at    timestamp with time zone
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO public
  AS $function$
declare
  v_id bigint;
  v_name text;
  v_slug text;
  v_public_domain text;
  v_is_active boolean;
  v_parent_id bigint;
  v_preference jsonb;
  v_created_at timestamptz;
  v_updated_at timestamptz;
begin
  if not public.is_superadmin() then
    return;
  end if;

  insert into public.tenants (name, slug, public_domain, is_active, parent_id)
  values (
    trim(p_name),
    lower(trim(p_slug)),
    nullif(
      regexp_replace(
        lower(
          trim(
            split_part(
              regexp_replace(coalesce(p_public_domain, ''), '^https?://', '', 'i'),
              '/',
              1
            )
          )
        ),
        ':\d+$',
        ''
      ),
      ''
    ),
    coalesce(p_is_active, true),
    p_parent_id
  )
  returning
    tenants.id,
    tenants.name,
    tenants.slug,
    tenants.public_domain,
    tenants.is_active,
    tenants.parent_id,
    tenants.preference,
    tenants.created_at,
    tenants.updated_at
  into
    v_id,
    v_name,
    v_slug,
    v_public_domain,
    v_is_active,
    v_parent_id,
    v_preference,
    v_created_at,
    v_updated_at;

  if v_parent_id is null then
    perform public.ensure_default_vendor(v_id);
    perform public.ensure_default_cargo_company(v_id);
    perform public.ensure_tenant_default_money_profiles(v_id);
  end if;

  return query
  select
    v_id,
    v_name,
    v_slug,
    v_public_domain,
    v_is_active,
    v_parent_id,
    v_preference,
    v_created_at,
    v_updated_at;
end;
$function$;

CREATE OR REPLACE FUNCTION "public"."post_ap_payout_with_allocations"("p_tenant_id" bigint, "p_profile_id" bigint, "p_paid_on" "date", "p_cashbook_point_id" bigint, "p_note" "text" DEFAULT NULL::"text", "p_reference" "text" DEFAULT NULL::"text", "p_instruments" "jsonb" DEFAULT '[]'::"jsonb", "p_allocations" "jsonb" DEFAULT '[]'::"jsonb", "p_settlement_currency_code" "text" DEFAULT 'BDT'::"text", "p_foreign_amount" numeric DEFAULT NULL::numeric, "p_exchange_rate" numeric DEFAULT NULL::numeric, "p_source_currency_code" "text" DEFAULT NULL::"text", "p_transaction_rate" numeric DEFAULT NULL::numeric, "p_cashbook_point_pot_id" bigint DEFAULT NULL::bigint, "p_idempotency_key" "text" DEFAULT NULL::"text", "p_from_profile_id" bigint DEFAULT NULL::bigint, "p_to_profile_id" bigint DEFAULT NULL::bigint, "p_description" "text" DEFAULT NULL::"text") RETURNS "public"."pays"
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
  v_from_profile_id bigint;
  v_to_profile_id bigint;
  v_pay_description text;
  v_legacy_profile_id bigint;
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

  select e.from_profile_id, e.to_profile_id, e.description, e.legacy_profile_id
  into v_from_profile_id, v_to_profile_id, v_pay_description, v_legacy_profile_id
  from public._kernel_resolve_pay_profile_endpoints(
    v_parent_id,
    'ap_payout',
    p_profile_id,
    p_from_profile_id,
    p_to_profile_id,
    p_description,
    v_note
  ) e;

  insert into public.pays (
    tenant_id, profile_id, from_profile_id, to_profile_id, description,
    source, amount, unallocated_amount,
    payment_date, method, reference, note,
    settlement_currency_code, foreign_amount, exchange_rate, quote_currency_code, cashbook_point_id,
    source_currency_code, transaction_rate, source_amount, cashbook_point_pot_id
  ) values (
    v_parent_id, coalesce(v_legacy_profile_id, p_profile_id), v_from_profile_id, v_to_profile_id, nullif(v_pay_description, ''),
    'ap_payout', v_amount, 0,
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

CREATE OR REPLACE FUNCTION public."post_customer_receipt_with_allocations"("p_tenant_id" bigint, "p_profile_id" bigint, "p_received_on" date, "p_note" text DEFAULT NULL::text, "p_reference" text DEFAULT NULL::text, "p_source" text DEFAULT 'customer_cash'::text, "p_instruments" jsonb DEFAULT '[]'::jsonb, "p_allocations" jsonb DEFAULT '[]'::jsonb, "p_shop_order_id" bigint DEFAULT NULL::bigint, "p_settlement_currency_code" text DEFAULT 'BDT'::text, "p_foreign_amount" numeric DEFAULT NULL::numeric, "p_exchange_rate" numeric DEFAULT NULL::numeric, "p_credit_dropship_profit" boolean DEFAULT true, "p_idempotency_key" text DEFAULT NULL::text, "p_cashbook_point_id" bigint DEFAULT NULL::bigint, "p_cashbook_point_pot_id" bigint DEFAULT NULL::bigint, "p_source_currency_code" text DEFAULT NULL::text, "p_transaction_rate" numeric DEFAULT NULL::numeric, "p_from_profile_id" bigint DEFAULT NULL::bigint, "p_to_profile_id" bigint DEFAULT NULL::bigint, "p_description" text DEFAULT NULL::text) RETURNS public.pays
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
  v_from_profile_id bigint;
  v_to_profile_id bigint;
  v_pay_description text;
  v_legacy_profile_id bigint;
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

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);

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
    raise exception 'Permission denied: cannot record receipts for this tenant';
  end if;

  if not exists (
    select 1 from public.profiles pr
    where pr.id = p_profile_id and pr.tenant_id = v_parent_id
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
        and ca.tenant_id = v_parent_id
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
      and cpp.tenant_id = v_parent_id
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

  select e.from_profile_id, e.to_profile_id, e.description, e.legacy_profile_id
  into v_from_profile_id, v_to_profile_id, v_pay_description, v_legacy_profile_id
  from public._kernel_resolve_pay_profile_endpoints(
    v_parent_id,
    v_source,
    p_profile_id,
    p_from_profile_id,
    p_to_profile_id,
    p_description,
    v_note
  ) e;

  insert into public.pays (
    tenant_id, profile_id, from_profile_id, to_profile_id, description,
    source, amount, unallocated_amount,
    payment_date, method, reference, note, shop_order_id,
    settlement_currency_code, foreign_amount, exchange_rate, quote_currency_code,
    cashbook_point_id, source_currency_code, transaction_rate, source_amount, cashbook_point_pot_id
  ) values (
    v_parent_id, coalesce(v_legacy_profile_id, p_profile_id), v_from_profile_id, v_to_profile_id, nullif(v_pay_description, ''),
    v_source, v_amount, v_amount,
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
      if v_bill.tenant_id <> v_parent_id then
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
      p_tenant_id => v_parent_id,
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
      p_tenant_id => v_parent_id,
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
        p_tenant_id => v_parent_id,
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

CREATE OR REPLACE FUNCTION public._kernel_pay_row_json(
  py public.pays,
  p_direction text,
  p_counterparty_name text DEFAULT NULL,
  p_perspective text DEFAULT 'party'
) RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
  SELECT jsonb_build_object(
    'id', py.id,
    'payment_date', py.payment_date,
    'amount', py.amount,
    'unallocated_amount', coalesce(py.unallocated_amount, 0),
    'source', py.source,
    'direction', p_direction,
    'method', py.method,
    'reference', py.reference,
    'note', py.note,
    'voided_at', py.voided_at,
    'from_profile_id', py.from_profile_id,
    'to_profile_id', py.to_profile_id,
    'description', py.description,
    'profile_id', py.profile_id,
    'profile_name', (SELECT pr.name FROM public.profiles pr WHERE pr.id = py.profile_id),
    'counterparty_name', coalesce(
      nullif(btrim(p_counterparty_name), ''),
      (SELECT pr.name FROM public.profiles pr WHERE pr.id = py.profile_id)
    ),
    'shop_order_id', py.shop_order_id,
    'settlement_currency_code', coalesce(py.settlement_currency_code, 'BDT'),
    'foreign_amount', py.foreign_amount,
    'exchange_rate', coalesce(py.exchange_rate, 1),
    'cashbook_point_id', py.cashbook_point_id,
    'cashbook_point_name', (
      SELECT cp.name FROM public.cashbook_points cp WHERE cp.id = py.cashbook_point_id
    ),
    'related_invoice_no', (
      SELECT b.invoice_no
      FROM public.pay_allocations pa
      INNER JOIN public.bills b ON b.id = pa.bill_id
      WHERE pa.payment_id = py.id
      ORDER BY pa.id ASC
      LIMIT 1
    ),
    'perspective', p_perspective
  );
$$;

CREATE OR REPLACE FUNCTION public.get_payment_profile_for_staff(
  p_tenant_id bigint,
  p_entity_type text,
  p_entity_id bigint,
  p_currency_code text DEFAULT 'BDT'::text,
  p_ledger_limit integer DEFAULT 50,
  p_pays_limit integer DEFAULT 50
) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO public
    AS $$
DECLARE
  v_books_id bigint;
  v_detail jsonb;
  v_ledger_entity_id bigint;
  v_ledger jsonb := '[]'::jsonb;
  v_pays jsonb := '[]'::jsonb;
  v_due_total numeric(18, 4) := 0;
  v_ledger_lim integer;
  v_pays_lim integer;
  v_money_profile_id bigint;
BEGIN
  IF p_entity_type NOT IN ('tenant', 'customer', 'vendor', 'courier', 'cargo_company', 'investor') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid entity_type');
  END IF;

  v_books_id := public.resolve_books_tenant_id(p_tenant_id);
  v_money_profile_id := public._kernel_cashbook_money_profile_id(v_books_id, p_entity_type, p_entity_id);

  IF NOT (
    public.cashbook_staff_can_view(p_tenant_id)
    OR public.membership_has_module_action(v_books_id, 'payments', 'view')
    OR public.membership_has_module_action(p_tenant_id, 'payments', 'view')
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  v_detail := public.get_cashbook_detail_for_staff(
    p_tenant_id, p_entity_type, p_entity_id, p_currency_code
  );
  IF coalesce((v_detail->>'success')::boolean, false) IS NOT TRUE THEN
    RETURN v_detail;
  END IF;

  v_ledger_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' THEN
    v_ledger_entity_id := v_books_id;
  END IF;

  v_ledger_lim := greatest(least(coalesce(p_ledger_limit, 50), 200), 1);
  v_pays_lim := greatest(least(coalesce(p_pays_limit, 50), 200), 1);

  SELECT coalesce(jsonb_agg(row_data ORDER BY sort_created DESC, sort_id DESC), '[]'::jsonb)
  INTO v_ledger
  FROM (
    SELECT
      jsonb_build_object(
        'id', l.id::text,
        'type', l.type,
        'amount', l.amount,
        'balance_after', l.balance_after,
        'source_type', l.source_type,
        'source_id', l.source_id,
        'created_at', l.created_at,
        'is_reversal', (l.metadata ? 'reversal_of'),
        'metadata', coalesce(l.metadata, '{}'::jsonb),
        'cashbook_point_id', l.cashbook_point_id,
        'cashbook_point_name', cp.name
      ) AS row_data,
      l.created_at AS sort_created,
      l.id AS sort_id
    FROM public.cashbook_entries l
    LEFT JOIN public.cashbook_points cp ON cp.id = l.cashbook_point_id
    WHERE l.tenant_id = v_books_id
      AND l.entity_type = p_entity_type
      AND l.entity_id = v_ledger_entity_id
    ORDER BY l.created_at DESC, l.id DESC
    LIMIT v_ledger_lim
  ) ledger_rows;

  IF p_entity_type <> 'tenant' THEN
    SELECT coalesce(sum(b.due_amount), 0::numeric)
    INTO v_due_total
    FROM public.bills b
    WHERE b.tenant_id = v_books_id
      AND b.profile_id = coalesce(v_money_profile_id, p_entity_id)
      AND b.invoice_status = 'issued'
      AND coalesce(b.payment_status, '') <> 'paid';
  END IF;

  IF p_entity_type = 'tenant' THEN
    SELECT coalesce(jsonb_agg(row_data ORDER BY sort_payment_date DESC, sort_id DESC), '[]'::jsonb)
    INTO v_pays
    FROM (
      SELECT
        public._kernel_pay_row_json(
          py,
          public._kernel_pay_direction_tenant(py.source),
          coalesce((SELECT pr.name FROM public.profiles pr WHERE pr.id = py.profile_id), ''),
          'tenant'
        ) AS row_data,
        py.payment_date AS sort_payment_date,
        py.id AS sort_id
      FROM public.pays py
      WHERE py.tenant_id = v_books_id
        AND py.voided_at IS NULL
      ORDER BY py.payment_date DESC, py.id DESC
      LIMIT v_pays_lim
    ) pay_rows;

  ELSIF p_entity_type IN ('customer', 'vendor', 'courier', 'cargo_company', 'investor') THEN
    SELECT coalesce(jsonb_agg(row_data ORDER BY sort_payment_date DESC, sort_id DESC), '[]'::jsonb)
    INTO v_pays
    FROM (
      SELECT
        public._kernel_pay_row_json(
          py,
          public._kernel_pay_direction_party(py.source, p_entity_type),
          NULL,
          'party'
        ) AS row_data,
        py.payment_date AS sort_payment_date,
        py.id AS sort_id
      FROM public.pays py
      WHERE py.tenant_id = v_books_id
        AND (
          py.from_profile_id = coalesce(v_money_profile_id, p_entity_id)
          OR py.to_profile_id = coalesce(v_money_profile_id, p_entity_id)
          OR (
            py.from_profile_id IS NULL
            AND py.to_profile_id IS NULL
            AND py.profile_id = coalesce(v_money_profile_id, p_entity_id)
          )
        )
        AND py.voided_at IS NULL
      ORDER BY py.payment_date DESC, py.id DESC
      LIMIT v_pays_lim
    ) pay_rows;
  END IF;

  RETURN v_detail
    || jsonb_build_object(
      'due_total', v_due_total,
      'ledger', v_ledger,
      'pays', v_pays
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.list_profile_activity_for_staff(
  p_tenant_id bigint,
  p_entity_type text,
  p_entity_id bigint,
  p_kind text DEFAULT 'payments',
  p_limit integer DEFAULT 50,
  p_cursor text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_books_id bigint;
  v_ledger_entity_id bigint;
  v_lim integer;
  v_items jsonb := '[]'::jsonb;
  v_next_cursor text;
  v_cursor_pay_id bigint;
  v_cursor_bill_id bigint;
  v_cursor_created timestamptz;
  v_cursor_entry_id uuid;
  v_money_profile_id bigint;
BEGIN
  IF p_kind NOT IN ('payments', 'custody', 'bills') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid kind');
  END IF;

  IF p_entity_type NOT IN ('tenant', 'customer', 'vendor', 'courier', 'cargo_company', 'investor') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid entity_type');
  END IF;

  v_books_id := public.resolve_books_tenant_id(p_tenant_id);
  v_money_profile_id := public._kernel_cashbook_money_profile_id(v_books_id, p_entity_type, p_entity_id);

  IF NOT (
    public.cashbook_staff_can_view(p_tenant_id)
    OR public.membership_has_module_action(v_books_id, 'payments', 'view')
    OR public.membership_has_module_action(p_tenant_id, 'payments', 'view')
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  v_lim := greatest(least(coalesce(p_limit, 50), 200), 1);
  v_ledger_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' THEN
    v_ledger_entity_id := v_books_id;
  END IF;

  IF p_kind = 'payments' THEN
    v_cursor_pay_id := NULLIF(btrim(coalesce(p_cursor, '')), '')::bigint;

    IF p_entity_type = 'tenant' THEN
      SELECT coalesce(jsonb_agg(row_data ORDER BY sort_payment_date DESC, sort_id DESC), '[]'::jsonb)
      INTO v_items
      FROM (
        SELECT
          public._kernel_pay_row_json(
            py,
            public._kernel_pay_direction_tenant(py.source),
            coalesce((SELECT pr.name FROM public.profiles pr WHERE pr.id = py.profile_id), ''),
            'tenant'
          ) AS row_data,
          py.payment_date AS sort_payment_date,
          py.id AS sort_id
        FROM public.pays py
        WHERE py.tenant_id = v_books_id
          AND py.voided_at IS NULL
          AND (v_cursor_pay_id IS NULL OR py.id < v_cursor_pay_id)
        ORDER BY py.payment_date DESC, py.id DESC
        LIMIT v_lim + 1
      ) pay_rows;

    ELSE
      SELECT coalesce(jsonb_agg(row_data ORDER BY sort_payment_date DESC, sort_id DESC), '[]'::jsonb)
      INTO v_items
      FROM (
        SELECT
          public._kernel_pay_row_json(
            py,
            public._kernel_pay_direction_party(py.source, p_entity_type),
            NULL,
            'party'
          ) AS row_data,
          py.payment_date AS sort_payment_date,
          py.id AS sort_id
        FROM public.pays py
        WHERE py.tenant_id = v_books_id
          AND (
            py.from_profile_id = coalesce(v_money_profile_id, p_entity_id)
            OR py.to_profile_id = coalesce(v_money_profile_id, p_entity_id)
            OR (
              py.from_profile_id IS NULL
              AND py.to_profile_id IS NULL
              AND py.profile_id = coalesce(v_money_profile_id, p_entity_id)
            )
          )
          AND py.voided_at IS NULL
          AND (v_cursor_pay_id IS NULL OR py.id < v_cursor_pay_id)
        ORDER BY py.payment_date DESC, py.id DESC
        LIMIT v_lim + 1
      ) pay_rows;
    END IF;

    IF jsonb_array_length(v_items) > v_lim THEN
      v_next_cursor := (v_items->(v_lim - 1)->>'id');
      v_items := (
        SELECT coalesce(jsonb_agg(elem), '[]'::jsonb)
        FROM jsonb_array_elements(v_items) WITH ORDINALITY AS t(elem, ord)
        WHERE ord <= v_lim
      );
    END IF;

  ELSIF p_kind = 'custody' THEN
    IF coalesce(btrim(p_cursor), '') <> '' THEN
      v_cursor_entry_id := p_cursor::uuid;
    END IF;

    SELECT coalesce(jsonb_agg(row_data ORDER BY sort_created DESC, sort_id DESC), '[]'::jsonb)
    INTO v_items
    FROM (
      SELECT
        jsonb_build_object(
          'id', l.id::text,
          'type', l.type,
          'amount', l.amount,
          'balance_after', l.balance_after,
          'source_type', l.source_type,
          'source_id', l.source_id,
          'created_at', l.created_at,
          'is_reversal', (l.metadata ? 'reversal_of'),
          'metadata', coalesce(l.metadata, '{}'::jsonb),
          'cashbook_point_id', l.cashbook_point_id,
          'cashbook_point_name', cp.name
        ) AS row_data,
        l.created_at AS sort_created,
        l.id AS sort_id
      FROM public.cashbook_entries l
      LEFT JOIN public.cashbook_points cp ON cp.id = l.cashbook_point_id
      WHERE l.tenant_id = v_books_id
        AND l.entity_type = p_entity_type
        AND l.entity_id = v_ledger_entity_id
        AND (v_cursor_entry_id IS NULL OR l.created_at < (
          SELECT l2.created_at FROM public.cashbook_entries l2 WHERE l2.id = v_cursor_entry_id
        ))
      ORDER BY l.created_at DESC, l.id DESC
      LIMIT v_lim + 1
    ) ledger_rows;

    IF jsonb_array_length(v_items) > v_lim THEN
      v_next_cursor := (v_items->(v_lim - 1)->>'id');
      v_items := (
        SELECT coalesce(jsonb_agg(elem), '[]'::jsonb)
        FROM jsonb_array_elements(v_items) WITH ORDINALITY AS t(elem, ord)
        WHERE ord <= v_lim
      );
    END IF;

  ELSIF p_kind = 'bills' THEN
    v_cursor_bill_id := NULLIF(btrim(coalesce(p_cursor, '')), '')::bigint;

    SELECT coalesce(jsonb_agg(row_data ORDER BY sort_id DESC), '[]'::jsonb)
    INTO v_items
    FROM (
      SELECT
        jsonb_build_object(
          'bill_id', s.bill_id,
          'invoice_no', s.invoice_no,
          'total_amount', s.total_amount,
          'open_books', s.open_books,
          'due_date', s.due_date,
          'invoice_type', s.invoice_type,
          'document_kind', s.document_kind,
          'lifecycle_status', s.lifecycle_status,
          'payment_status', s.payment_status,
          'profile_id', s.profile_id,
          'from_profile_id', s.from_profile_id,
          'to_profile_id', s.to_profile_id
        ) AS row_data,
        s.bill_id AS sort_id
      FROM public.v_kernel_bill_summaries s
      WHERE s.tenant_id = v_books_id
        AND s.lifecycle_status = 'issued'::public.bill_lifecycle_status
        AND (
          (p_entity_type = 'tenant' AND s.tenant_id = v_books_id)
          OR (
            p_entity_type <> 'tenant'
            AND (
              s.profile_id = coalesce(v_money_profile_id, p_entity_id)
              OR s.from_profile_id = coalesce(v_money_profile_id, p_entity_id)
              OR s.to_profile_id = coalesce(v_money_profile_id, p_entity_id)
            )
          )
        )
        AND (v_cursor_bill_id IS NULL OR s.bill_id < v_cursor_bill_id)
      ORDER BY s.bill_id DESC
      LIMIT v_lim + 1
    ) bill_rows;

    IF jsonb_array_length(v_items) > v_lim THEN
      v_next_cursor := (v_items->(v_lim - 1)->>'bill_id');
      v_items := (
        SELECT coalesce(jsonb_agg(elem), '[]'::jsonb)
        FROM jsonb_array_elements(v_items) WITH ORDINALITY AS t(elem, ord)
        WHERE ord <= v_lim
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'kind', p_kind,
    'items', v_items,
    'next_cursor', v_next_cursor
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public._kernel_cashbook_money_profile_id(bigint, text, bigint)
  TO authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.get_payment_profile_for_staff(
  bigint, text, bigint, text, integer, integer
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.get_payment_profile_for_staff(
  bigint, text, bigint, text, integer, integer
) TO service_role;

GRANT EXECUTE ON FUNCTION public.list_profile_activity_for_staff(
  bigint, text, bigint, text, integer, text
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.list_profile_activity_for_staff(
  bigint, text, bigint, text, integer, text
) TO service_role;

DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT t.id
    FROM public.tenants t
    WHERE t.parent_id IS NULL
  LOOP
    PERFORM public.ensure_tenant_default_money_profiles(r.id);
  END LOOP;
END $$;

UPDATE public.pays py
SET
  from_profile_id = e.from_profile_id,
  to_profile_id = e.to_profile_id,
  description = nullif(e.description, '')
FROM (
  SELECT
    p.id AS pay_id,
    r.from_profile_id,
    r.to_profile_id,
    r.description
  FROM public.pays p
  CROSS JOIN LATERAL public._kernel_resolve_pay_profile_endpoints(
    p.tenant_id,
    p.source,
    p.profile_id,
    NULL,
    NULL,
    NULL,
    p.note
  ) r
  WHERE p.from_profile_id IS NULL
    AND p.to_profile_id IS NULL
) e
WHERE py.id = e.pay_id;

