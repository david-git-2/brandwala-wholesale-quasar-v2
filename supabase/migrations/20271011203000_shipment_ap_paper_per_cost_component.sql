-- AP bucket paper: one print line per cost component with invoice currency (no FX until payout).

CREATE OR REPLACE FUNCTION public._build_shipment_ap_bucket_paper(
  p_shipment_id bigint,
  p_ship public.global_shipments,
  p_bucket public.global_shipment_cost_bucket
) RETURNS jsonb
    LANGUAGE plpgsql STABLE
    SET search_path TO public
    AS $$
declare
  v_lines jsonb := '[]'::jsonb;
  v_foreign_total numeric(12, 2) := 0;
  v_currency_code text := 'BDT';
  v_currency_symbol text := '৳';
  v_weight_kg numeric(12, 3);
  v_fallback_amount numeric(12, 2);
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
      )
      from public.global_shipment_cost_entries e
      left join public.global_currencies line_cur
        on line_cur.id = coalesce(e.currency_id, p_ship.shipment_cost_currency_id, p_ship.shipment_purchase_currency_id)
      where e.shipment_id = p_shipment_id
        and e.cost_bucket = p_bucket
        and coalesce(e.amount, 0) > 0
    ),
    '[]'::jsonb
  ),
  coalesce(sum(round(e.amount, 2)), 0)
  into v_lines, v_foreign_total
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id
    and e.cost_bucket = p_bucket
    and coalesce(e.amount, 0) > 0;

  if v_foreign_total = 0 and p_bucket = 'material'::public.global_shipment_cost_bucket then
    v_fallback_amount := coalesce(round(p_ship.purchase_invoice_total, 2), 0);
    if v_fallback_amount > 0 then
      v_foreign_total := v_fallback_amount;
      v_lines := jsonb_build_array(
        jsonb_build_object(
          'description', 'Product subtotal',
          'amount', v_fallback_amount,
          'currency_code', v_currency_code,
          'currency_symbol', v_currency_symbol
        )
      );
    end if;
  elsif v_foreign_total = 0 and p_bucket = 'freight'::public.global_shipment_cost_bucket then
    v_fallback_amount := coalesce(round(p_ship.cargo_invoice_total, 2), 0);
    if v_fallback_amount > 0 then
      v_foreign_total := v_fallback_amount;
      v_lines := jsonb_build_array(
        jsonb_build_object(
          'description', 'Freight subtotal',
          'amount', v_fallback_amount,
          'currency_code', v_currency_code,
          'currency_symbol', v_currency_symbol
        )
      );
    end if;
  end if;

  if jsonb_array_length(v_lines) > 0 then
    select coalesce(line_cur.code, v_currency_code), coalesce(line_cur.symbol, line_cur.code, v_currency_symbol)
    into v_currency_code, v_currency_symbol
    from public.global_shipment_cost_entries e
    left join public.global_currencies line_cur
      on line_cur.id = coalesce(e.currency_id, p_ship.shipment_cost_currency_id, p_ship.shipment_purchase_currency_id)
    where e.shipment_id = p_shipment_id
      and e.cost_bucket = p_bucket
      and coalesce(e.amount, 0) > 0
    order by e.id desc
    limit 1;
  end if;

  v_result := jsonb_build_object(
    'paper', p_bucket::text,
    'lines', coalesce(v_lines, '[]'::jsonb),
    'foreign_total', v_foreign_total,
    'currency_code', v_currency_code,
    'currency_symbol', v_currency_symbol,
    'bdt_amount', v_foreign_total
  );

  if p_bucket = 'freight'::public.global_shipment_cost_bucket then
    v_weight_kg := coalesce(p_ship.total_weight_kg, p_ship.received_weight, 0);
    v_result := v_result || jsonb_build_object('weight_kg', v_weight_kg);
  end if;

  return v_result;
end;
$$;

CREATE OR REPLACE FUNCTION public.sync_shipment_ap_bills(p_shipment_id bigint) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO public
    AS $$
declare
  v_ship public.global_shipments;
  v_parent bigint;
  v_issued_by bigint;
  v_vendor_profile bigint;
  v_cargo_profile bigint;
  v_local_profile bigint;
  v_tenant_name text;
  v_bucket public.global_shipment_cost_bucket;
  v_bucket_text text;
  v_paper jsonb;
  v_amt numeric(12, 2);
  v_profile bigint;
  v_bill_id bigint;
  v_bills jsonb := '{}'::jsonb;
  v_keep_as_draft boolean := false;
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

  v_keep_as_draft := not coalesce(v_ship.costs_locked, false);

  if v_ship.status = 'cancelled' then
    update public.bills
    set invoice_status = 'voided'::public.global_invoice_status, updated_at = now()
    where parent_tenant_id = v_parent
      and ap_shipment_id = p_shipment_id
      and invoice_type = 'ap'::public.global_invoice_type
      and invoice_status in (
        'issued'::public.global_invoice_status,
        'draft'::public.global_invoice_status
      )
      and coalesce(paid_amount, 0) = 0;
    return jsonb_build_object('success', true, 'cancelled', true);
  end if;

  foreach v_bucket_text in array enum_range(null::public.global_shipment_cost_bucket)::text[]
  loop
    v_bucket := v_bucket_text::public.global_shipment_cost_bucket;
    v_paper := public._build_shipment_ap_bucket_paper(p_shipment_id, v_ship, v_bucket);
    v_amt := coalesce(
      (v_paper->>'foreign_total')::numeric,
      (v_paper->>'bdt_amount')::numeric,
      0
    );

    v_profile := case v_bucket
      when 'material'::public.global_shipment_cost_bucket then v_vendor_profile
      when 'freight'::public.global_shipment_cost_bucket then v_cargo_profile
      when 'customs'::public.global_shipment_cost_bucket then v_cargo_profile
      else v_local_profile
    end;

    v_bill_id := public._upsert_shipment_ap_bill(
      v_parent,
      v_issued_by,
      p_shipment_id,
      v_ship.name,
      v_bucket::text,
      v_profile,
      v_amt,
      v_paper,
      v_keep_as_draft
    );

    if v_bill_id is not null then
      v_bills := v_bills || jsonb_build_object(v_bucket::text, v_bill_id);
    end if;
  end loop;

  update public.bills
  set invoice_status = 'voided'::public.global_invoice_status, updated_at = now()
  where parent_tenant_id = v_parent
    and ap_shipment_id = p_shipment_id
    and invoice_type = 'ap'::public.global_invoice_type
    and ap_kind in ('vendor', 'cargo', 'local')
    and invoice_status = 'issued'::public.global_invoice_status
    and coalesce(paid_amount, 0) = 0;

  return jsonb_build_object('success', true, 'bills', v_bills);
end;
$$;
