-- Pay-weighted shipment FX: allocations are bill/foreign units; leftover in Taka.

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

  -- AP bill due is voucher/foreign. Allocations on FX pays are in that unit.
  -- Taka = alloc × pay.exchange_rate (not alloc/pay.amount, which inverted Shue).
  select
    coalesce(sum(
      round(
        case
          when coalesce(p.foreign_amount, 0) > 0 and coalesce(p.exchange_rate, 0) > 0 then
            pa.amount * p.exchange_rate
          else pa.amount
        end,
        2
      )
    ), 0),
    coalesce(sum(
      round(
        case
          when coalesce(p.foreign_amount, 0) > 0 then pa.amount
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

CREATE OR REPLACE FUNCTION "public"."_global_shipment_landed_fx_inputs"("p_shipment_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_mat jsonb;
  v_fre jsonb;
  v_prod_rate numeric := 1;
  v_cargo_fx numeric := 1;
  v_product_foreign numeric := 0;
  v_cargo_foreign numeric := 0;
  v_entry_material numeric := 0;
  v_entry_freight numeric := 0;
  v_goods_bdt numeric := 0;
  v_freight_bdt numeric := 0;
  v_blended numeric := 1;
  v_kg numeric := 0;
  v_cargo_per_kg numeric := 0;
  v_mat_count integer := 0;
  v_fre_count integer := 0;
begin
  v_mat := public.shipment_ap_bucket_paid_totals(p_shipment_id, 'material');
  v_fre := public.shipment_ap_bucket_paid_totals(p_shipment_id, 'freight');

  v_mat_count := coalesce((v_mat ->> 'payment_count')::integer, 0);
  v_fre_count := coalesce((v_fre ->> 'payment_count')::integer, 0);

  if v_mat_count > 0 then
    v_prod_rate := coalesce((v_mat ->> 'conversion_rate')::numeric, 1);
  end if;
  if v_fre_count > 0 then
    v_cargo_fx := coalesce((v_fre ->> 'conversion_rate')::numeric, 1);
  end if;

  select
    coalesce(sum(gce.amount) filter (where gce.is_capitalizable and gce.cost_bucket = 'material'), 0),
    coalesce(sum(gce.amount) filter (where gce.is_capitalizable and gce.cost_bucket = 'freight'), 0)
  into v_entry_material, v_entry_freight
  from public.global_shipment_cost_entries gce
  where gce.shipment_id = p_shipment_id;

  v_product_foreign := coalesce((v_mat ->> 'foreign_paid')::numeric, 0);
  if v_product_foreign <= 0 then
    v_product_foreign := v_entry_material;
  end if;

  v_cargo_foreign := coalesce((v_fre ->> 'foreign_paid')::numeric, 0);
  if v_cargo_foreign <= 0 then
    v_cargo_foreign := v_entry_freight;
  end if;

  v_goods_bdt := round(v_product_foreign * v_prod_rate, 2);
  v_freight_bdt := round(v_cargo_foreign * v_cargo_fx, 2);

  if (v_product_foreign + v_cargo_foreign) > 0 then
    v_blended := round((v_goods_bdt + v_freight_bdt) / (v_product_foreign + v_cargo_foreign), 6);
  else
    v_blended := 1;
  end if;

  select coalesce(gs.total_weight_kg, gs.received_weight, 0)
  into v_kg
  from public.global_shipments gs
  where gs.id = p_shipment_id;

  if coalesce(v_kg, 0) > 0 and v_cargo_foreign > 0 then
    v_cargo_per_kg := round(v_cargo_foreign / v_kg, 6);
  end if;

  return jsonb_build_object(
    'material', v_mat,
    'freight', v_fre,
    'goods_bdt', v_goods_bdt,
    'freight_bdt', v_freight_bdt,
    'product_foreign', v_product_foreign,
    'cargo_foreign', v_cargo_foreign,
    'product_conversion_rate', v_prod_rate,
    'cargo_conversion_rate', v_cargo_fx,
    'cargo_rate', v_cargo_per_kg,
    'transaction_rate', v_blended,
    'blended_rate', v_blended
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."refresh_global_shipment_fx_from_ap_payments"("p_shipment_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_fx jsonb;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  if not exists (select 1 from public.global_shipments gs where gs.id = p_shipment_id) then
    raise exception 'shipment not found';
  end if;

  v_fx := public._global_shipment_landed_fx_inputs(p_shipment_id);
  return v_fx;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."stamp_global_shipment_landed_costs"("p_shipment_id" bigint) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_cargo_foreign numeric := 0;
  v_prod_rate numeric := 1;
  v_cargo_fx numeric := 1;
  v_fx jsonb;
  v_pack_kg numeric := 0;
  v_updated integer := 0;
  r record;
  v_line_gross numeric;
  v_line_cargo_share numeric;
  v_unit_product numeric;
  v_unit_cargo numeric;
  v_landed numeric;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  perform public.ensure_global_shipment_cost_entries_from_header(p_shipment_id);

  v_fx := public._global_shipment_landed_fx_inputs(p_shipment_id);
  v_cargo_foreign := coalesce((v_fx ->> 'cargo_foreign')::numeric, 0);
  v_prod_rate := coalesce((v_fx ->> 'product_conversion_rate')::numeric, 1);
  v_cargo_fx := coalesce((v_fx ->> 'cargo_conversion_rate')::numeric, 1);

  select coalesce(sum(
    ((coalesce(gsi.product_weight, 0) + coalesce(gsi.package_weight, 0)) * gsi.ordered_quantity) / 1000.0
  ), 0)
  into v_pack_kg
  from public.global_shipment_items gsi
  where gsi.shipment_id = p_shipment_id;

  perform set_config('app.allow_landed_cost_stamp', '1', true);

  for r in
    select *
    from public.global_shipment_items
    where shipment_id = p_shipment_id
  loop
    v_line_gross := (
      (coalesce(r.product_weight, 0) + coalesce(r.package_weight, 0)) * r.ordered_quantity
    ) / 1000.0;

    if v_pack_kg > 0 then
      v_line_cargo_share := (v_line_gross / v_pack_kg) * v_cargo_foreign;
    elsif (select coalesce(sum(ordered_quantity), 0) from public.global_shipment_items where shipment_id = p_shipment_id) > 0 then
      v_line_cargo_share := (r.ordered_quantity::numeric
        / (select sum(ordered_quantity) from public.global_shipment_items where shipment_id = p_shipment_id)
      ) * v_cargo_foreign;
    else
      v_line_cargo_share := 0;
    end if;

    if r.ordered_quantity > 0 then
      v_unit_product := coalesce(r.purchase_price, 0);
      v_unit_cargo := v_line_cargo_share / r.ordered_quantity;
    else
      v_unit_product := coalesce(r.purchase_price, 0);
      v_unit_cargo := 0;
    end if;

    if v_ship.type::text in ('local', 'domestic') then
      v_landed := v_unit_product + v_unit_cargo;
    else
      v_landed := (v_unit_product * v_prod_rate) + (v_unit_cargo * v_cargo_fx);
    end if;

    update public.global_shipment_items
    set landed_cost_bdt = round(v_landed::numeric, 4)
    where id = r.id;

    v_updated := v_updated + 1;
  end loop;

  perform public._stamp_global_shipment_outcome_costs(p_shipment_id);

  return v_updated;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."calculate_landed_unit_cost"("p_shipment_item_id" bigint) RETURNS numeric
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_stamp numeric;
  v_shipment_id bigint;
  v_shipment_type public.global_shipment_type;

  v_purchase_price numeric;
  v_product_weight numeric;
  v_package_weight numeric;
  v_qty numeric;

  v_total_packaging_weight_kg numeric := 0;
  v_line_gross_weight_kg numeric;
  v_line_cargo_share numeric := 0;
  v_line_purchase_base numeric;
  v_prod_rate numeric := 1;
  v_cargo_fx numeric := 1;
  v_landed_cost numeric;
  v_total_qty numeric;
  v_cargo_foreign numeric := 0;
  v_fx jsonb;
begin
  select
    shipment_id,
    purchase_price,
    product_weight,
    package_weight,
    ordered_quantity,
    landed_cost_bdt
  into
    v_shipment_id,
    v_purchase_price,
    v_product_weight,
    v_package_weight,
    v_qty,
    v_stamp
  from public.global_shipment_items
  where id = p_shipment_item_id;

  if v_shipment_id is null then
    return 0.00;
  end if;

  if v_stamp is not null then
    return round(v_stamp::numeric, 4);
  end if;

  select type
  into v_shipment_type
  from public.global_shipments
  where id = v_shipment_id;

  v_fx := public._global_shipment_landed_fx_inputs(v_shipment_id);
  v_cargo_foreign := coalesce((v_fx ->> 'cargo_foreign')::numeric, 0);
  v_prod_rate := coalesce((v_fx ->> 'product_conversion_rate')::numeric, 1);
  v_cargo_fx := coalesce((v_fx ->> 'cargo_conversion_rate')::numeric, 1);

  select coalesce(sum(((product_weight + package_weight) * ordered_quantity) / 1000.0), 0)
  into v_total_packaging_weight_kg
  from public.global_shipment_items
  where shipment_id = v_shipment_id;

  v_line_gross_weight_kg := ((coalesce(v_product_weight, 0) + coalesce(v_package_weight, 0)) * coalesce(v_qty, 0)) / 1000.0;

  if v_qty > 0 and v_cargo_foreign > 0 then
    if v_total_packaging_weight_kg > 0 then
      v_line_cargo_share := ((v_line_gross_weight_kg / v_total_packaging_weight_kg) * v_cargo_foreign) / v_qty;
    else
      select coalesce(sum(ordered_quantity), 0) into v_total_qty
      from public.global_shipment_items
      where shipment_id = v_shipment_id;
      if v_total_qty > 0 then
        v_line_cargo_share := ((v_qty / v_total_qty) * v_cargo_foreign) / v_qty;
      end if;
    end if;
  end if;

  v_line_purchase_base := coalesce(v_purchase_price, 0) + coalesce(v_line_cargo_share, 0);

  if v_shipment_type::text in ('local', 'domestic') then
    return round(v_line_purchase_base::numeric, 4);
  end if;

  v_landed_cost := (coalesce(v_purchase_price, 0) * v_prod_rate)
    + (coalesce(v_line_cargo_share, 0) * v_cargo_fx);
  return round(v_landed_cost::numeric, 4);
end;
$$;

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
  v_alloc_bdt numeric(12, 2);
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

      insert into public.pay_allocations (tenant_id, payment_id, global_invoice_id, amount)
      values (v_parent_id, v_pay.id, v_bill_id, v_alloc_amount);

      perform public.recompute_global_invoice_payment_status(v_bill_id);
      if v_settle_currency is distinct from 'BDT' and coalesce(v_fx_rate, 0) > 0 then
        v_alloc_bdt := round(v_alloc_amount * v_fx_rate, 2);
      else
        v_alloc_bdt := v_alloc_amount;
      end if;
      v_total_alloc := v_total_alloc + v_alloc_bdt;

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


UPDATE public.pays p
SET unallocated_amount = greatest(
  0,
  round(
    p.amount - coalesce((
      SELECT sum(round(pa.amount * p.exchange_rate, 2))
      FROM public.pay_allocations pa
      WHERE pa.payment_id = p.id
    ), 0),
    2
  )
)
WHERE p.source = 'ap_payout'
  AND p.settlement_currency_code IS DISTINCT FROM 'BDT'
  AND coalesce(p.foreign_amount, 0) > 0
  AND p.voided_at IS NULL;

DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT DISTINCT b.ap_shipment_id AS id
    FROM public.bills b
    WHERE b.invoice_type = 'ap'
      AND b.ap_shipment_id IS NOT NULL
      AND b.ap_kind IN ('material', 'freight')
  LOOP
    PERFORM public.stamp_global_shipment_landed_costs(r.id);
  END LOOP;
END $$;
