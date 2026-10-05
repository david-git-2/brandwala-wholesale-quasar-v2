-- AP bill print snapshot in bills.channel_meta.ap_paper (vendor / cargo / local layouts).

CREATE OR REPLACE FUNCTION public._upsert_shipment_ap_bill(
  p_parent_tenant_id bigint,
  p_issued_by_tenant_id bigint,
  p_shipment_id bigint,
  p_shipment_name text,
  p_ap_kind text,
  p_profile_id bigint,
  p_amount numeric,
  p_ap_paper jsonb DEFAULT NULL::jsonb
) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_bill public.bills;
  v_target numeric(12, 2);
  v_due numeric(12, 2);
  v_status text;
  v_invoice_no text;
  v_kind_label text;
  v_meta_base jsonb;
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
  v_meta_base := jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id);
  if p_ap_paper is not null then
    v_meta_base := v_meta_base || jsonb_build_object('ap_paper', p_ap_paper);
  end if;

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
      v_meta_base
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
    channel_meta = coalesce(channel_meta, '{}'::jsonb)
      || jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id)
      || case
        when p_ap_paper is not null and coalesce(v_bill.paid_amount, 0) = 0
        then jsonb_build_object('ap_paper', p_ap_paper)
        else '{}'::jsonb
      end,
    updated_at = now()
  where id = v_bill.id;

  return v_bill.id;
end;
$$;

CREATE OR REPLACE FUNCTION public.sync_shipment_ap_bills(p_shipment_id bigint) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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
  v_vendor_foreign numeric(12, 2) := 0;
  v_cargo_foreign numeric(12, 2) := 0;
  v_vendor_rate numeric(12, 4) := 1;
  v_cargo_rate numeric(12, 4) := 1;
  v_weight_kg numeric(12, 3);
  v_vendor_paper jsonb;
  v_cargo_paper jsonb;
  v_local_paper jsonb;
  v_local_lines jsonb;
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

  select coalesce(sum(round(e.amount, 2)), 0)
  into v_vendor_foreign
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id
    and e.cost_type = 'product'::public.global_shipment_cost_type;

  if v_vendor_foreign = 0 then
    v_vendor_foreign := coalesce(round(v_ship.purchase_invoice_total, 2), 0);
  end if;

  v_vendor_rate := case
    when v_vendor_foreign > 0 and v_vendor_amt > 0 then round(v_vendor_amt / v_vendor_foreign, 4)
    else 1
  end;

  v_vendor_paper := jsonb_build_object(
    'paper', 'vendor',
    'foreign_amount', v_vendor_foreign,
    'conversion_rate', v_vendor_rate,
    'bdt_amount', v_vendor_amt
  );

  select coalesce(sum(round(e.amount, 2)), 0)
  into v_cargo_foreign
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id
    and e.cost_type in ('cargo'::public.global_shipment_cost_type, 'duty'::public.global_shipment_cost_type);

  if v_cargo_foreign = 0 then
    v_cargo_foreign := coalesce(round(v_ship.cargo_invoice_total, 2), 0);
  end if;

  v_cargo_rate := case
    when v_cargo_foreign > 0 and v_cargo_amt > 0 then round(v_cargo_amt / v_cargo_foreign, 4)
    else 1
  end;

  v_weight_kg := coalesce(v_ship.total_weight_kg, v_ship.received_weight, 0);

  v_cargo_paper := jsonb_build_object(
    'paper', 'cargo',
    'weight_kg', v_weight_kg,
    'price', v_cargo_foreign,
    'conversion_rate', v_cargo_rate,
    'bdt_amount', v_cargo_amt
  );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'description', coalesce(nullif(trim(lc.description), ''), 'Local cost'),
        'amount', round(lc.amount, 2)
      )
      order by lc.id
    ),
    '[]'::jsonb
  )
  into v_local_lines
  from public.global_shipment_local_costs lc
  where lc.shipment_id = p_shipment_id;

  select coalesce(v_local_lines, '[]'::jsonb) || coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'description', initcap(replace(e.cost_type::text, '_', ' ')),
          'amount', round(e.amount * coalesce(e.exchange_rate, 1), 2)
        )
        order by e.id
      )
      from public.global_shipment_cost_entries e
      where e.shipment_id = p_shipment_id
        and e.cost_type in (
          'insurance'::public.global_shipment_cost_type,
          'labor'::public.global_shipment_cost_type,
          'washing'::public.global_shipment_cost_type,
          'transport'::public.global_shipment_cost_type,
          'handling'::public.global_shipment_cost_type
        )
    ),
    '[]'::jsonb
  )
  into v_local_lines;

  v_local_paper := jsonb_build_object(
    'paper', 'local',
    'lines', coalesce(v_local_lines, '[]'::jsonb),
    'bdt_amount', v_local_amt
  );

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
    'vendor_bill_id', public._upsert_shipment_ap_bill(v_parent, v_issued_by, p_shipment_id, v_ship.name, 'vendor', v_vendor_profile, v_vendor_amt, v_vendor_paper),
    'cargo_bill_id', public._upsert_shipment_ap_bill(v_parent, v_issued_by, p_shipment_id, v_ship.name, 'cargo', v_cargo_profile, v_cargo_amt, v_cargo_paper),
    'local_bill_id', public._upsert_shipment_ap_bill(v_parent, v_issued_by, p_shipment_id, v_ship.name, 'local', v_local_profile, v_local_amt, v_local_paper)
  );
end;
$$;

REVOKE ALL ON FUNCTION public._upsert_shipment_ap_bill(bigint, bigint, bigint, text, text, bigint, numeric, jsonb) FROM PUBLIC;
