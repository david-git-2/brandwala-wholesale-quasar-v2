-- BP9: kernel upsert adapter for shipment AP + shop dropship entry
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
  v_bill_id bigint;
begin
  v_tenant_id := nullif(p_payload->>'tenant_id', '')::bigint;
  if v_tenant_id is null then
    raise exception 'tenant_id required';
  end if;

  if coalesce(p_payload->>'adapter', '') = 'shipment_cost' then
    v_bill_id := public._upsert_shipment_ap_bill(
      nullif(p_payload->>'parent_tenant_id', '')::bigint,
      nullif(p_payload->>'issued_by_tenant_id', '')::bigint,
      nullif(p_payload->>'shipment_id', '')::bigint,
      p_payload->>'shipment_name',
      p_payload->>'ap_kind',
      nullif(p_payload->>'profile_id', '')::bigint,
      nullif(p_payload->>'amount', '')::numeric,
      coalesce(p_payload->'ap_paper', '{}'::jsonb),
      coalesce((p_payload->>'keep_as_draft')::boolean, true),
      nullif(p_payload->>'source_key', '')
    );
    if v_bill_id is null then
      raise exception 'shipment AP upsert returned no bill';
    end if;
    select * into v_bill from public.bills where id = v_bill_id;
    return v_bill;
  end if;

  v_result := public.create_sales_invoice_from_payload(v_tenant_id, p_payload);
  if coalesce(v_result->>'success', 'false') <> 'true' then
    raise exception '%', coalesce(v_result->>'error', 'upsert_draft_bill failed');
  end if;
  select * into v_bill from public.bills where id = (v_result->>'invoice_id')::bigint;
  return v_bill;
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

      if coalesce(v_amt, 0) <= 0 or v_profile is null then
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
      else
        select u.id
        into v_bill_id
        from public.upsert_draft_bill(
          jsonb_build_object(
            'tenant_id', v_issued_by,
            'adapter', 'shipment_cost',
            'parent_tenant_id', v_parent,
            'issued_by_tenant_id', v_issued_by,
            'shipment_id', p_shipment_id,
            'shipment_name', v_ship.name,
            'ap_kind', v_bucket::text,
            'profile_id', v_profile,
            'amount', v_amt,
            'ap_paper', v_slice,
            'keep_as_draft', v_keep_as_draft,
            'source_key', v_plug_key
          )
        ) u;
      end if;

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
