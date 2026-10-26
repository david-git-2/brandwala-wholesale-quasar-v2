-- AP FX: allocations in BDT (books); foreign face on bill header until pay; fix landed FX totals.

CREATE OR REPLACE FUNCTION "public"."ap_bill_channel_foreign_face"("p_channel_meta" "jsonb") RETURNS numeric
    LANGUAGE "sql" IMMUTABLE
    AS $$
  select coalesce(
    nullif((p_channel_meta->'ap_paper'->>'foreign_total')::numeric, 0),
    nullif((p_channel_meta->'ap_paper'->'currency_groups'->0->>'foreign_total')::numeric, 0)
  );
$$;

CREATE OR REPLACE FUNCTION "public"."ap_bill_channel_currency"("p_channel_meta" "jsonb") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    AS $$
  select upper(coalesce(
    nullif(trim(p_channel_meta->'ap_paper'->>'currency_code'), ''),
    nullif(trim(p_channel_meta->'ap_paper'->'currency_groups'->0->>'currency_code'), ''),
    'BDT'
  ));
$$;

-- post_ap_payout_with_allocations + _build_shipment_ap_bucket_paper bdt_amount: copy from schemas/bills_pays/03_rpcs.sql
-- (applied via schema sync; bodies included below for migration replay)

CREATE OR REPLACE FUNCTION "public"."shipment_ap_bucket_paid_totals"("p_shipment_id" bigint, "p_ap_kind" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_bdt numeric := 0;
  v_foreign numeric := 0;
  v_count integer := 0;
  v_rate numeric := 1;
begin
  if p_shipment_id is null or nullif(trim(coalesce(p_ap_kind, '')), '') is null then
    return jsonb_build_object(
      'bdt_paid', 0,
      'foreign_paid', 0,
      'conversion_rate', 1,
      'payment_count', 0
    );
  end if;

  select
    coalesce(sum(round(pa.amount, 2)), 0),
    coalesce(sum(
      round(
        case
          when coalesce(p.exchange_rate, 0) > 0
               and upper(coalesce(p.settlement_currency_code, 'BDT')) <> 'BDT' then
            pa.amount / p.exchange_rate
          else pa.amount
        end,
        2
      )
    ), 0),
    count(distinct p.id)::integer
  into v_bdt, v_foreign, v_count
  from public.bills b
  inner join public.pay_allocations pa on pa.global_invoice_id = b.id
  inner join public.pays p on p.id = pa.payment_id
  where b.ap_shipment_id = p_shipment_id
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and b.ap_kind = p_ap_kind
    and p.voided_at is null;

  if v_foreign > 0 then
    v_rate := round(v_bdt / v_foreign, 6);
  end if;

  return jsonb_build_object(
    'bdt_paid', v_bdt,
    'foreign_paid', v_foreign,
    'conversion_rate', v_rate,
    'payment_count', v_count
  );
end;
$$;

-- Repair: foreign-unit allocations on FX AP pays → BDT books
with fixed_alloc as (
  update public.pay_allocations pa
  set amount = round(pa.amount * p.exchange_rate, 2)
  from public.pays p
  where pa.payment_id = p.id
    and p.source = 'ap_payout'
    and p.voided_at is null
    and upper(coalesce(p.settlement_currency_code, 'BDT')) <> 'BDT'
    and coalesce(p.exchange_rate, 0) > 0
    and pa.amount > 0
    and pa.amount < p.amount * 0.99
    and (
      abs(pa.amount - coalesce(p.foreign_amount, 0)) < 0.05
      or pa.amount < p.amount / p.exchange_rate * 1.5
    )
  returning pa.global_invoice_id as bill_id, pa.payment_id, pa.amount as alloc_bdt, p.exchange_rate
),
restamp_bills as (
  select distinct
    f.bill_id,
    f.exchange_rate,
    public.ap_bill_channel_foreign_face(b.channel_meta) as foreign_face
  from fixed_alloc f
  join public.bills b on b.id = f.bill_id
  where public.ap_bill_channel_foreign_face(b.channel_meta) is not null
)
update public.bills b
set
  channel_meta = jsonb_set(
    coalesce(b.channel_meta, '{}'::jsonb),
    '{ap_paper}',
    coalesce(b.channel_meta->'ap_paper', '{}'::jsonb)
      || jsonb_build_object(
        'conversion_rate', r.exchange_rate,
        'bdt_amount', round(r.foreign_face * r.exchange_rate, 2)
      )
  ),
  subtotal_amount = round(r.foreign_face * r.exchange_rate, 2),
  total_amount = round(r.foreign_face * r.exchange_rate, 2)
from restamp_bills r
where b.id = r.bill_id;

update public.pays p
set unallocated_amount = greatest(p.amount - coalesce(a.sum_alloc, 0), 0)
from (
  select payment_id, sum(amount)::numeric(12, 2) as sum_alloc
  from public.pay_allocations
  group by payment_id
) a
where p.id = a.payment_id
  and p.source = 'ap_payout'
  and p.voided_at is null;

do $$
declare
  v_bill_id bigint;
begin
  for v_bill_id in
    select distinct pa.global_invoice_id
    from public.pay_allocations pa
    join public.pays p on p.id = pa.payment_id
    where p.source = 'ap_payout'
      and p.voided_at is null
  loop
    perform public.recompute_global_invoice_payment_status(v_bill_id);
  end loop;
end;
$$;

-- post_ap_payout_with_allocations
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
  v_channel_meta jsonb;
  v_foreign_face numeric(12, 2);
  v_paper_currency text;
  v_effective_due numeric(12, 2);
  v_paper jsonb;
  v_books_total numeric(12, 2);
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

      v_channel_meta := coalesce(v_bill.channel_meta, '{}'::jsonb);
      v_foreign_face := public.ap_bill_channel_foreign_face(v_channel_meta);
      v_paper_currency := public.ap_bill_channel_currency(v_channel_meta);

      if v_settle_currency <> 'BDT'
         and v_fx_rate > 0
         and v_foreign_face is not null
         and v_foreign_face > 0
         and v_paper_currency <> 'BDT'
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

      if v_settle_currency <> 'BDT'
         and v_fx_rate > 0
         and v_foreign_face is not null
         and v_foreign_face > 0
         and v_paper_currency <> 'BDT'
      then
        v_books_total := round(v_foreign_face * v_fx_rate, 2);
        v_paper := coalesce(v_channel_meta->'ap_paper', '{}'::jsonb)
          || jsonb_build_object('conversion_rate', v_fx_rate, 'bdt_amount', v_books_total);
        update public.bills b
        set
          channel_meta = jsonb_set(coalesce(b.channel_meta, '{}'::jsonb), '{ap_paper}', v_paper),
          subtotal_amount = v_books_total,
          total_amount = v_books_total
        where b.id = v_bill_id;
        perform public.recompute_global_invoice_payment_status(v_bill_id);
      end if;

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

-- _build_shipment_ap_bucket_paper
CREATE OR REPLACE FUNCTION "public"."_build_shipment_ap_bucket_paper"("p_shipment_id" bigint, "p_ship" "public"."global_shipments", "p_bucket" "public"."global_shipment_cost_bucket") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public'
    AS $$
declare
  v_lines jsonb := '[]'::jsonb;
  v_currency_groups jsonb := '[]'::jsonb;
  v_group_count integer := 0;
  v_foreign_total numeric(12, 2);
  v_currency_code text := 'BDT';
  v_currency_symbol text := '৳';
  v_weight_kg numeric(12, 3);
  v_fallback_amount numeric(12, 2);
  v_mixed_currencies boolean := false;
  v_bill_amount numeric(12, 2) := 0;
  v_result jsonb;
begin
  select coalesce(def_cur.code, 'BDT'), coalesce(def_cur.symbol, def_cur.code, '৳')
  into v_currency_code, v_currency_symbol
  from public.global_currencies def_cur
  where def_cur.id = coalesce(p_ship.shipment_cost_currency_id, p_ship.shipment_purchase_currency_id);

  select coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'currency_code', g.currency_code,
          'currency_symbol', g.currency_symbol,
          'foreign_total', g.foreign_total,
          'lines', g.lines
        )
        order by g.currency_code
      )
      from (
        select
          coalesce(line_cur.code, v_currency_code) as currency_code,
          coalesce(line_cur.symbol, line_cur.code, v_currency_symbol) as currency_symbol,
          sum(round(e.amount, 2)) as foreign_total,
          jsonb_agg(
            jsonb_build_object(
              'description', coalesce(
                nullif(trim(e.description), ''),
                nullif(trim(e.metadata->>'description'), ''),
                initcap(replace(e.cost_component::text, '_', ' '))
              ),
              'amount', round(e.amount, 2),
              'currency_code', coalesce(line_cur.code, v_currency_code),
              'currency_symbol', coalesce(line_cur.symbol, line_cur.code, v_currency_symbol)
            )
            order by
              case e.cost_component
                when 'subtotal'::public.global_shipment_cost_component then 1
                when 'carriage'::public.global_shipment_cost_component then 2
                when 'vat_tax'::public.global_shipment_cost_component then 3
                when 'misc'::public.global_shipment_cost_component then 4
                else 5
              end,
              e.id desc
          ) as lines
        from public.global_shipment_cost_entries e
        left join public.global_currencies line_cur
          on line_cur.id = coalesce(e.currency_id, p_ship.shipment_cost_currency_id, p_ship.shipment_purchase_currency_id)
        where e.shipment_id = p_shipment_id
          and e.cost_bucket = p_bucket
          and coalesce(e.amount, 0) > 0
        group by
          coalesce(line_cur.code, v_currency_code),
          coalesce(line_cur.symbol, line_cur.code, v_currency_symbol)
      ) g
    ),
    '[]'::jsonb
  )
  into v_currency_groups;

  v_group_count := jsonb_array_length(coalesce(v_currency_groups, '[]'::jsonb));
  v_mixed_currencies := v_group_count > 1;

  select coalesce(
    (
      select jsonb_agg(line_elm order by (line_elm->>'currency_code'), (line_elm->>'description'))
      from (
        select jsonb_array_elements(g.elem->'lines') as line_elm
        from jsonb_array_elements(coalesce(v_currency_groups, '[]'::jsonb)) as g(elem)
      ) flat
    ),
    '[]'::jsonb
  )
  into v_lines;

  if v_group_count = 1 then
    v_foreign_total := (v_currency_groups->0->>'foreign_total')::numeric;
    v_currency_code := v_currency_groups->0->>'currency_code';
    v_currency_symbol := v_currency_groups->0->>'currency_symbol';
    v_bill_amount := coalesce(v_foreign_total, 0);
  elsif v_group_count > 1 then
    v_foreign_total := null;
    select coalesce(sum((g.elem->>'foreign_total')::numeric), 0)
    into v_bill_amount
    from jsonb_array_elements(v_currency_groups) as g(elem);
  else
    v_foreign_total := 0;
    v_bill_amount := 0;
  end if;

  if v_bill_amount = 0 and p_bucket = 'material'::public.global_shipment_cost_bucket then
    v_fallback_amount := coalesce(round(p_ship.purchase_invoice_total, 2), 0);
    if v_fallback_amount > 0 then
      v_foreign_total := v_fallback_amount;
      v_bill_amount := v_fallback_amount;
      v_lines := jsonb_build_array(
        jsonb_build_object(
          'description', 'Product subtotal',
          'amount', v_fallback_amount,
          'currency_code', v_currency_code,
          'currency_symbol', v_currency_symbol
        )
      );
      v_currency_groups := jsonb_build_array(
        jsonb_build_object(
          'currency_code', v_currency_code,
          'currency_symbol', v_currency_symbol,
          'foreign_total', v_fallback_amount,
          'lines', v_lines
        )
      );
      v_group_count := 1;
      v_mixed_currencies := false;
    end if;
  elsif v_bill_amount = 0 and p_bucket = 'freight'::public.global_shipment_cost_bucket then
    v_fallback_amount := coalesce(round(p_ship.cargo_invoice_total, 2), 0);
    if v_fallback_amount > 0 then
      v_foreign_total := v_fallback_amount;
      v_bill_amount := v_fallback_amount;
      v_lines := jsonb_build_array(
        jsonb_build_object(
          'description', 'Freight subtotal',
          'amount', v_fallback_amount,
          'currency_code', v_currency_code,
          'currency_symbol', v_currency_symbol
        )
      );
      v_currency_groups := jsonb_build_array(
        jsonb_build_object(
          'currency_code', v_currency_code,
          'currency_symbol', v_currency_symbol,
          'foreign_total', v_fallback_amount,
          'lines', v_lines
        )
      );
      v_group_count := 1;
      v_mixed_currencies := false;
    end if;
  end if;

  v_result := jsonb_build_object(
    'paper', p_bucket::text,
    'lines', coalesce(v_lines, '[]'::jsonb),
    'currency_groups', coalesce(v_currency_groups, '[]'::jsonb),
    'mixed_currencies', v_mixed_currencies,
    'foreign_total', v_foreign_total,
    'currency_code', v_currency_code,
    'currency_symbol', v_currency_symbol,
    'bdt_amount', case
      when upper(coalesce(v_currency_code, 'BDT')) in ('', 'BDT') then coalesce(v_foreign_total, v_bill_amount)
      else null
    end
  );

  if p_bucket = 'freight'::public.global_shipment_cost_bucket then
    v_weight_kg := coalesce(p_ship.total_weight_kg, p_ship.received_weight, 0);
    v_result := v_result || jsonb_build_object('weight_kg', v_weight_kg);
  end if;

  return v_result;
end;
$$;

ALTER FUNCTION "public"."_build_shipment_ap_bucket_paper"("p_shipment_id" bigint, "p_ship" "public"."global_shipments", "p_bucket" "public"."global_shipment_cost_bucket") OWNER TO "postgres";
