-- Inbound shipment ↔ money kernel adapters.
-- Do NOT edit 05_money_spine.sql. These wrappers call spine RPCs where supported.

CREATE OR REPLACE FUNCTION public._shipment_money_advisory_lock(p_shipment_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;
  perform pg_advisory_xact_lock(hashtext('shipment_money:' || p_shipment_id::text));
end;
$$;

CREATE OR REPLACE FUNCTION public._shipment_money_lock_shipment_ids(p_shipment_ids bigint[])
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_id bigint;
begin
  if p_shipment_ids is null or coalesce(array_length(p_shipment_ids, 1), 0) = 0 then
    return;
  end if;
  for v_id in
    select distinct x.id
    from unnest(p_shipment_ids) as x(id)
    where x.id is not null
    order by x.id asc
  loop
    perform public._shipment_money_advisory_lock(v_id);
  end loop;
end;
$$;

CREATE OR REPLACE FUNCTION public.get_shipment_money_kernel_bundle(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bundle jsonb;
  v_ap_bills jsonb;
  v_enriched jsonb := '[]'::jsonb;
  v_elem jsonb;
  v_bill_id bigint;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  v_bundle := public.get_shipment_settings_finance_bundle(p_shipment_id);
  v_ap_bills := coalesce(v_bundle->'ap_bills', '[]'::jsonb);

  for v_elem in select value from jsonb_array_elements(v_ap_bills)
  loop
    v_bill_id := nullif(v_elem->>'id', '')::bigint;
    if v_bill_id is not null then
      v_enriched := v_enriched || jsonb_build_array(
        v_elem || jsonb_build_object('net_balances', public.get_bill_net_balances(v_bill_id))
      );
    else
      v_enriched := v_enriched || jsonb_build_array(v_elem);
    end if;
  end loop;

  return v_bundle
    || jsonb_build_object('ap_bills', v_enriched)
    || jsonb_build_object(
      'kernel',
      jsonb_build_object(
        'source_type', 'shipment_cost',
        'source_id', p_shipment_id::text,
        'pay_out_rpc', 'post_shipment_ap_money_out',
        'issue_rpc', 'issue_bill'
      )
    );
end;
$$;

CREATE OR REPLACE FUNCTION public.post_shipment_ap_money_out(
  p_shipment_ids bigint[],
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
  p_source_type text DEFAULT 'shipment_cost',
  p_source_id text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
) RETURNS public.pays
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_pay public.pays;
  v_sid text;
  v_primary bigint;
begin
  if p_shipment_ids is null or coalesce(array_length(p_shipment_ids, 1), 0) = 0 then
    raise exception 'shipment_ids is required';
  end if;

  perform public._shipment_money_lock_shipment_ids(p_shipment_ids);

  select min(x.id) into v_primary from unnest(p_shipment_ids) as x(id) where x.id is not null;
  v_sid := coalesce(nullif(trim(p_source_id), ''), v_primary::text);

  v_pay := public.post_money_out(
    p_tenant_id,
    p_profile_id,
    p_paid_on,
    p_amount,
    p_source,
    p_note,
    p_reference,
    p_cashbook_point_id,
    p_instruments,
    p_allocations,
    p_settlement_currency_code,
    p_foreign_amount,
    p_exchange_rate,
    coalesce(nullif(trim(p_source_type), ''), 'shipment_cost'),
    v_sid,
    p_idempotency_key
  );

  return v_pay;
end;
$$;

CREATE OR REPLACE FUNCTION public.post_shipment_ap_money_out_snapshot(
  p_shipment_ids bigint[],
  p_tenant_id bigint,
  p_profile_id bigint,
  p_paid_on date,
  p_cashbook_point_id bigint,
  p_note text DEFAULT NULL,
  p_reference text DEFAULT NULL,
  p_instruments jsonb DEFAULT '[]'::jsonb,
  p_allocations jsonb DEFAULT '[]'::jsonb,
  p_settlement_currency_code text DEFAULT 'BDT',
  p_foreign_amount numeric DEFAULT NULL,
  p_exchange_rate numeric DEFAULT NULL,
  p_source_currency_code text DEFAULT NULL,
  p_transaction_rate numeric DEFAULT NULL,
  p_cashbook_point_pot_id bigint DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  if p_shipment_ids is null or coalesce(array_length(p_shipment_ids, 1), 0) = 0 then
    raise exception 'shipment_ids is required';
  end if;

  perform public._shipment_money_lock_shipment_ids(p_shipment_ids);

  return public.post_ap_payout_with_allocations_snapshot(
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
    p_cashbook_point_pot_id
  );
end;
$$;

CREATE OR REPLACE FUNCTION public.issue_shipment_ap_bills(p_shipment_id bigint)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_parent bigint;
  v_bill_id bigint;
  v_count integer := 0;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  select gs.parent_tenant_id into v_parent
  from public.global_shipments gs
  where gs.id = p_shipment_id;

  if v_parent is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_parent)
  ) then
    raise exception 'Permission denied';
  end if;

  perform public._shipment_money_advisory_lock(p_shipment_id);

  for v_bill_id in
    select b.id
    from public.bills b
    where b.parent_tenant_id = v_parent
      and b.invoice_type = 'ap'::public.global_invoice_type
      and b.document_kind = 'standard'::public.bill_document_kind
      and b.invoice_status = 'draft'::public.global_invoice_status
      and coalesce(b.total_amount, 0) > 0
      and (
        (b.source_type = 'shipment_cost' and b.source_id = p_shipment_id::text)
        or b.ap_shipment_id = p_shipment_id
      )
    order by b.id asc
  loop
    perform public.issue_bill(v_bill_id);
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

CREATE OR REPLACE FUNCTION public.issue_shipment_ap_bill_for_kind(
  p_shipment_id bigint,
  p_ap_kind text
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_parent bigint;
  v_bill_id bigint;
  v_issued public.bills;
  v_last_issued bigint;
begin
  if p_ap_kind not in (
    'vendor', 'cargo', 'local',
    'material', 'freight', 'customs', 'handling', 'finance', 'other'
  ) then
    raise exception 'Invalid ap_kind %', p_ap_kind;
  end if;

  select gs.parent_tenant_id into v_parent
  from public.global_shipments gs
  where gs.id = p_shipment_id;

  if v_parent is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_parent)
  ) then
    raise exception 'Permission denied';
  end if;

  perform public._shipment_money_advisory_lock(p_shipment_id);

  for v_bill_id in
    select b.id
    from public.bills b
    where b.parent_tenant_id = v_parent
      and b.invoice_type = 'ap'::public.global_invoice_type
      and b.document_kind = 'standard'::public.bill_document_kind
      and b.invoice_status = 'draft'::public.global_invoice_status
      and coalesce(b.total_amount, 0) > 0
      and (
        (
          b.source_type = 'shipment_cost'
          and b.source_id = p_shipment_id::text
          and (
            b.source_key = p_ap_kind
            or b.source_key like p_ap_kind || ':%'
          )
        )
        or (b.ap_shipment_id = p_shipment_id and b.ap_kind = p_ap_kind)
      )
    order by b.id asc
  loop
    v_issued := public.issue_bill(v_bill_id);
    v_last_issued := v_issued.id;
  end loop;

  if v_last_issued is null then
    raise exception 'No draft AP bill to issue for bucket %', p_ap_kind;
  end if;

  return v_last_issued;
end;
$$;

CREATE OR REPLACE FUNCTION public.sync_shipment_ap_bills(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
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
  v_void_id bigint;
  v_groups jsonb;
  v_grp jsonb;
  v_ccy text;
  v_plug_key text;
  v_group_count int;
  v_slice jsonb;
  v_active_keys text[] := '{}';
  v_elem jsonb;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  perform public._shipment_money_advisory_lock(p_shipment_id);

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
    for v_void_id in
      select b.id
      from public.bills b
      where b.parent_tenant_id = v_parent
        and b.ap_shipment_id = p_shipment_id
        and b.invoice_type = 'ap'::public.global_invoice_type
        and b.document_kind = 'standard'::public.bill_document_kind
        and b.invoice_status in (
          'issued'::public.global_invoice_status,
          'draft'::public.global_invoice_status
        )
        and coalesce(b.paid_amount, 0) = 0
      order by b.id asc
    loop
      perform public.void_bill(v_void_id);
    end loop;
    return jsonb_build_object('success', true, 'cancelled', true);
  end if;

  foreach v_bucket_text in array enum_range(null::public.global_shipment_cost_bucket)::text[]
  loop
    v_bucket := v_bucket_text::public.global_shipment_cost_bucket;
    v_paper := public._build_shipment_ap_bucket_paper(p_shipment_id, v_ship, v_bucket);
    v_groups := coalesce(v_paper->'currency_groups', '[]'::jsonb);
    v_group_count := jsonb_array_length(v_groups);

    v_profile := case v_bucket
      when 'material'::public.global_shipment_cost_bucket then v_vendor_profile
      when 'freight'::public.global_shipment_cost_bucket then v_cargo_profile
      when 'customs'::public.global_shipment_cost_bucket then v_cargo_profile
      else v_local_profile
    end;

    if v_group_count = 0 then
      for v_void_id in
        select b.id
        from public.bills b
        where b.parent_tenant_id = v_parent
          and b.source_type = 'shipment_cost'
          and b.source_id = p_shipment_id::text
          and b.invoice_type = 'ap'::public.global_invoice_type
          and b.document_kind = 'standard'::public.bill_document_kind
          and b.invoice_status in (
            'issued'::public.global_invoice_status,
            'draft'::public.global_invoice_status
          )
          and coalesce(b.paid_amount, 0) = 0
          and (
            b.source_key = v_bucket::text
            or b.source_key like v_bucket::text || ':%'
          )
        order by b.id asc
      loop
        perform public.void_bill(v_void_id);
      end loop;
      continue;
    end if;

    for v_elem in select value from jsonb_array_elements(v_groups)
    loop
      v_grp := v_elem;
      v_ccy := upper(trim(coalesce(v_grp->>'currency_code', 'BDT')));
      v_plug_key := case
        when v_group_count > 1 then v_bucket::text || ':' || v_ccy
        else v_bucket::text
      end;
      v_amt := round(coalesce((v_grp->>'foreign_total')::numeric, 0), 2);
      v_slice := v_paper
        || jsonb_build_object(
          'foreign_total', v_grp->>'foreign_total',
          'currency_code', v_ccy,
          'currency_symbol', v_grp->>'currency_symbol',
          'currency_groups', jsonb_build_array(v_grp),
          'mixed_currencies', false,
          'lines', coalesce(v_grp->'lines', '[]'::jsonb)
        );

      v_bill_id := public._upsert_shipment_ap_bill(
        v_parent,
        v_issued_by,
        p_shipment_id,
        v_ship.name,
        v_bucket::text,
        v_profile,
        v_amt,
        v_slice,
        v_keep_as_draft,
        v_plug_key
      );

      if v_bill_id is not null then
        v_active_keys := array_append(v_active_keys, v_plug_key);
        v_bills := v_bills || jsonb_build_object(v_plug_key, v_bill_id);
      end if;
    end loop;
  end loop;

  for v_void_id in
    select b.id
    from public.bills b
    where b.parent_tenant_id = v_parent
      and b.source_type = 'shipment_cost'
      and b.source_id = p_shipment_id::text
      and b.invoice_type = 'ap'::public.global_invoice_type
      and b.document_kind = 'standard'::public.bill_document_kind
      and b.invoice_status in (
        'draft'::public.global_invoice_status,
        'issued'::public.global_invoice_status
      )
      and coalesce(b.paid_amount, 0) = 0
      and b.source_key is not null
      and not (b.source_key = any(v_active_keys))
    order by b.id asc
  loop
    perform public.void_bill(v_void_id);
  end loop;

  for v_void_id in
    select b.id
    from public.bills b
    where b.parent_tenant_id = v_parent
      and b.ap_shipment_id = p_shipment_id
      and b.invoice_type = 'ap'::public.global_invoice_type
      and b.document_kind = 'standard'::public.bill_document_kind
      and b.ap_kind in ('vendor', 'cargo', 'local')
      and b.invoice_status = 'issued'::public.global_invoice_status
      and coalesce(b.paid_amount, 0) = 0
    order by b.id asc
  loop
    perform public.void_bill(v_void_id);
  end loop;

  return jsonb_build_object('success', true, 'bills', v_bills);
end;
$$;

CREATE OR REPLACE FUNCTION public.settle_shipment_payee(
  p_shipment_id bigint,
  p_entity_type text,
  p_entity_id bigint,
  p_action text,
  p_amount numeric,
  p_exchange_rate numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  raise exception
    'settle_shipment_payee is retired. Pay shipment AP via Finance → Payments: allocate to bucket bills using post_shipment_ap_money_out (kernel post_money_out). Shipment %.',
    p_shipment_id;
end;
$$;

GRANT EXECUTE ON FUNCTION public._shipment_money_advisory_lock(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._shipment_money_lock_shipment_ids(bigint[]) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_shipment_money_kernel_bundle(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.post_shipment_ap_money_out(
  bigint[], bigint, bigint, date, numeric, text, text, text, bigint, jsonb, jsonb, text, numeric, numeric, text, text, text
) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.post_shipment_ap_money_out_snapshot(
  bigint[], bigint, bigint, date, bigint, text, text, jsonb, jsonb, text, numeric, numeric, text, numeric, bigint
) TO authenticated, service_role;
