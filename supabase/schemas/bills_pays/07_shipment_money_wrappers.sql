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

CREATE OR REPLACE FUNCTION public._assert_shipment_ap_issue_allowed(p_shipment_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_ship public.global_shipments;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  select * into v_ship from public.global_shipments where id = p_shipment_id;
  if v_ship.id is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  if current_setting('app.bill_desk_issue_shipment_ap', true) = '1' then
    return;
  end if;

  if v_ship.status not in ('in_transit', 'received') then
    raise exception 'Shipment % must be in transit or received before issuing AP bills', p_shipment_id;
  end if;

  if not coalesce(v_ship.costs_locked, false) then
    raise exception 'Shipment % costs are not locked; use Lock costs on the shipment first', p_shipment_id;
  end if;

  if current_setting('app.shipment_ap_issue', true) is distinct from '1'
     and coalesce(auth.role(), '') is distinct from 'service_role' then
    raise exception 'Issue shipment AP only via lock_global_shipment_costs on the shipment';
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION public._assert_shipment_ap_payable(p_shipment_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_ship public.global_shipments;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  select * into v_ship from public.global_shipments where id = p_shipment_id;
  if v_ship.id is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION public._assert_shipment_ap_allocations_payable(p_allocations jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_elem jsonb;
  v_bill_id bigint;
  v_bill public.bills;
begin
  if p_allocations is null or jsonb_typeof(p_allocations) <> 'array' then
    return;
  end if;

  for v_elem in select value from jsonb_array_elements(p_allocations)
  loop
    v_bill_id := nullif(v_elem->>'bill_id', '')::bigint;
    if v_bill_id is null then
      continue;
    end if;

    select * into v_bill from public.bills where id = v_bill_id;
    if v_bill.id is null then
      raise exception 'Allocation bill % not found', v_bill_id;
    end if;

    if v_bill.invoice_type = 'ap'::public.global_invoice_type
       and v_bill.source_type = 'shipment_cost'
       and v_bill.invoice_status <> 'issued'::public.global_invoice_status then
      raise exception 'Bill % must be issued before shipment AP payout', v_bill_id;
    end if;

    if v_bill.ap_shipment_id is not null then
      perform public._assert_shipment_ap_payable(v_bill.ap_shipment_id);
    elsif v_bill.source_type = 'shipment_cost' and nullif(trim(v_bill.source_id), '') is not null then
      perform public._assert_shipment_ap_payable(nullif(trim(v_bill.source_id), '')::bigint);
    end if;
  end loop;
end;
$$;

CREATE OR REPLACE FUNCTION public.get_shipment_money_kernel_bundle(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
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
        'create_ap_bill_rpc', 'create_shipment_ap_bill_v2',
        'update_ap_bill_rpc', 'update_shipment_ap_bill_v2',
        'void_ap_bill_rpc', 'void_shipment_ap_bill_v2',
        'issue_draft_rpc', 'issue_shipment_ap_drafts_v2'
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
  p_cash_location_id bigint DEFAULT NULL,
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
  v_sid_loop bigint;
begin
  if p_shipment_ids is null or coalesce(array_length(p_shipment_ids, 1), 0) = 0 then
    raise exception 'shipment_ids is required';
  end if;

  perform public._shipment_money_lock_shipment_ids(p_shipment_ids);

  for v_sid_loop in
    select distinct x.id
    from unnest(p_shipment_ids) as x(id)
    where x.id is not null
  loop
    perform public._assert_shipment_ap_payable(v_sid_loop);
  end loop;

  perform public._assert_shipment_ap_allocations_payable(p_allocations);

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
    p_cash_location_id,
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
  p_cash_location_id bigint,
  p_note text DEFAULT NULL,
  p_reference text DEFAULT NULL,
  p_instruments jsonb DEFAULT '[]'::jsonb,
  p_allocations jsonb DEFAULT '[]'::jsonb,
  p_settlement_currency_code text DEFAULT 'BDT',
  p_foreign_amount numeric DEFAULT NULL,
  p_exchange_rate numeric DEFAULT NULL,
  p_source_currency_code text DEFAULT NULL,
  p_transaction_rate numeric DEFAULT NULL,
  p_cashbook_point_pot_id bigint DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_sid_loop bigint;
begin
  if p_shipment_ids is null or coalesce(array_length(p_shipment_ids, 1), 0) = 0 then
    raise exception 'shipment_ids is required';
  end if;

  perform public._shipment_money_lock_shipment_ids(p_shipment_ids);

  for v_sid_loop in
    select distinct x.id
    from unnest(p_shipment_ids) as x(id)
    where x.id is not null
  loop
    perform public._assert_shipment_ap_payable(v_sid_loop);
  end loop;

  perform public._assert_shipment_ap_allocations_payable(p_allocations);

  return public.post_ap_payout_with_allocations_snapshot(
    p_tenant_id,
    p_profile_id,
    p_paid_on,
    p_cash_location_id,
    p_note,
    p_reference,
    p_instruments,
    p_allocations,
    p_settlement_currency_code,
    p_foreign_amount,
    p_exchange_rate,
    p_source_currency_code,
    p_transaction_rate,
    p_cashbook_point_pot_id,
    p_idempotency_key
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

  select gs.tenant_id into v_parent
  from public.global_shipments gs
  where gs.id = p_shipment_id;

  if v_parent is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_books_tenant(v_parent)
  ) then
    raise exception 'Permission denied';
  end if;

  perform public._assert_shipment_ap_issue_allowed(p_shipment_id);
  perform public._shipment_money_advisory_lock(p_shipment_id);

  for v_bill_id in
    select b.id
    from public.bills b
    where b.tenant_id = v_parent
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
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  raise exception 'issue_shipment_ap_bill_for_kind is retired. Use lock_global_shipment_costs on shipment % to sync and issue all AP bills.',
    p_shipment_id;
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

  v_parent := v_ship.tenant_id;
  v_issued_by := coalesce(v_ship.assigned_child_tenant_id, v_parent);

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_books_tenant(v_parent)
  ) then
    raise exception 'Permission denied';
  end if;

  if v_ship.vendor_id is not null then
    select pr.id into v_vendor_profile
    from public.profiles pr
    where pr.tenant_id = v_parent
      and pr.profile_type = 'vendor'::public.profile_party_type
      and pr.subject_id = v_ship.vendor_id;
  end if;

  if v_ship.cargo_company_id is not null then
    select pr.id into v_cargo_profile
    from public.profiles pr
    where pr.tenant_id = v_parent
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
      where b.tenant_id = v_parent
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
        where b.tenant_id = v_parent
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
    where b.tenant_id = v_parent
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
    where b.tenant_id = v_parent
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

CREATE OR REPLACE FUNCTION public._list_shipment_cost_ap_bills_json(
  p_books_tenant_id bigint,
  p_shipment_id bigint,
  p_include_voided boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
  SELECT COALESCE(
    jsonb_agg(row_data ORDER BY (row_data->>'id')::bigint),
    '[]'::jsonb
  )
  FROM (
    SELECT jsonb_build_object(
      'id', b.id,
      'invoice_no', b.invoice_no,
      'invoice_type', b.invoice_type,
      'document_kind', b.document_kind,
      'ap_kind', COALESCE(
        NULLIF(btrim(b.ap_kind), ''),
        NULLIF(btrim(b.channel_meta->>'ap_kind'), ''),
        NULLIF(split_part(COALESCE(b.source_key, ''), ':', 1), '')
      ),
      'ap_shipment_id', b.ap_shipment_id,
      'source_type', b.source_type,
      'source_id', b.source_id,
      'source_key', b.source_key,
      'invoice_status', b.invoice_status,
      'payment_status', b.payment_status,
      'total_amount', b.total_amount,
      'due_amount', b.due_amount,
      'parent_bill_id', b.parent_bill_id,
      'net_balances', public.get_bill_net_balances(b.id)
    ) AS row_data
    FROM public.bills b
    WHERE b.tenant_id = p_books_tenant_id
      AND (p_include_voided OR b.invoice_status <> 'voided'::public.global_invoice_status)
      AND b.invoice_type = 'ap'::public.global_invoice_type
      AND b.document_kind = 'standard'::public.bill_document_kind
      AND (
        (b.source_type = 'shipment_cost' AND b.source_id = p_shipment_id::text)
        OR b.ap_shipment_id = p_shipment_id
      )
      AND (
        b.ap_shipment_id = p_shipment_id
        OR COALESCE(
          NULLIF(btrim(b.ap_kind), ''),
          NULLIF(btrim(b.channel_meta->>'ap_kind'), ''),
          NULLIF(btrim(b.source_key), ''),
          split_part(COALESCE(b.source_key, ''), ':', 1)
        ) IN (
          'material', 'freight', 'customs', 'handling', 'finance', 'other',
          'vendor', 'cargo', 'local'
        )
        OR COALESCE(b.source_key, '') ~ '^(material|freight|customs|handling|finance|other|vendor|cargo|local):'
      )

    UNION ALL

    SELECT jsonb_build_object(
      'id', kb.id,
      'invoice_no', kb.invoice_no,
      'invoice_type', 'ap',
      'document_kind', 'standard',
      'ap_kind', COALESCE(kb.meta->>'ap_kind', split_part(COALESCE(kb.source_key, ''), ':', 1)),
      'ap_shipment_id', (kb.meta->>'shipment_id')::bigint,
      'source_type', kb.source_type,
      'source_id', kb.source_id,
      'source_key', kb.source_key,
      'invoice_status', CASE kb.status WHEN 'voided' THEN 'voided' WHEN 'draft' THEN 'draft' ELSE 'issued' END,
      'payment_status', public._desk_kernel_status_payment(kb.status, kb.due_amount),
      'total_amount', kb.total_amount,
      'due_amount', kb.due_amount,
      'parent_bill_id', kb.parent_bill_id,
      'net_balances', public._desk_kernel_net_balances_json(kb.id),
      'cost_lines', COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object(
            'cost_component', COALESCE(NULLIF(btrim(bl.meta->>'cost_component'), ''), 'misc'),
            'amount', bl.line_total,
            'description', bl.description
          )
          ORDER BY bl.line_no
        )
        FROM money_kernel.bill_lines bl
        WHERE bl.tenant_id = kb.tenant_id
          AND bl.bill_id = kb.id
      ), '[]'::jsonb)
    ) AS row_data
    FROM money_kernel.bills kb
    WHERE kb.tenant_id = p_books_tenant_id
      AND kb.kind = 'shipment_cost_ap'
      AND kb.source_type = 'shipment_cost'
      AND kb.source_id = p_shipment_id::text
      AND (p_include_voided OR kb.status <> 'voided')
      AND NOT EXISTS (SELECT 1 FROM public.bills pb WHERE pb.id = kb.id)
  ) merged;
$$;

-- ---------------------------------------------------------------------------
-- Shipment cost entry AP v2 (money_kernel.bills via rpc_create_bill)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public._shipment_cost_ap_ensure_public_from_profile(p_books_tenant_id bigint)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_id bigint;
  v_name text;
BEGIN
  v_id := public._kernel_tenant_mirror_profile_id(p_books_tenant_id);
  IF v_id IS NOT NULL THEN
    RETURN v_id;
  END IF;

  SELECT t.name INTO v_name FROM public.tenants t WHERE t.id = p_books_tenant_id;
  RETURN public.upsert_profile_for_party(
    p_books_tenant_id,
    'tenant'::public.profile_party_type,
    p_books_tenant_id,
    COALESCE(v_name, 'Tenant #' || p_books_tenant_id::text),
    NULL, NULL, '+880', NULL, false, NULL, true, NULL
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._shipment_cost_ap_ensure_public_to_profile(
  p_books_tenant_id bigint,
  p_ship       public.global_shipments,
  p_bucket     public.global_shipment_cost_bucket,
  OUT profile_id bigint,
  OUT diagnostic text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_name text;
BEGIN
  profile_id := NULL;
  diagnostic := NULL;

  IF p_bucket = 'material'::public.global_shipment_cost_bucket THEN
    IF p_ship.vendor_id IS NULL THEN
      diagnostic := 'shipment vendor_id is required for material AP';
      RETURN;
    END IF;
    SELECT pr.id INTO profile_id
      FROM public.profiles pr
     WHERE pr.tenant_id = p_books_tenant_id
       AND pr.profile_type = 'vendor'::public.profile_party_type
       AND pr.subject_id = p_ship.vendor_id
       AND pr.is_active = true
       AND pr.deleted_at IS NULL
     LIMIT 1;
    IF profile_id IS NULL THEN
      SELECT v.name INTO v_name FROM public.vendors v WHERE v.id = p_ship.vendor_id;
      profile_id := public.upsert_profile_for_party(
        p_books_tenant_id,
        'vendor'::public.profile_party_type,
        p_ship.vendor_id,
        COALESCE(v_name, 'Vendor #' || p_ship.vendor_id::text),
        NULL, NULL, '+880', NULL, false, NULL, true, NULL
      );
    END IF;
    RETURN;
  END IF;

  IF p_bucket IN ('freight'::public.global_shipment_cost_bucket, 'customs'::public.global_shipment_cost_bucket) THEN
    IF p_ship.cargo_company_id IS NULL THEN
      diagnostic := 'shipment cargo_company_id is required for freight/customs AP';
      RETURN;
    END IF;
    SELECT pr.id INTO profile_id
      FROM public.profiles pr
     WHERE pr.tenant_id = p_books_tenant_id
       AND pr.profile_type = 'cargo'::public.profile_party_type
       AND pr.subject_id = p_ship.cargo_company_id
       AND pr.is_active = true
       AND pr.deleted_at IS NULL
     LIMIT 1;
    IF profile_id IS NULL THEN
      SELECT c.name INTO v_name FROM public.cargo_companies c WHERE c.id = p_ship.cargo_company_id;
      profile_id := public.upsert_profile_for_party(
        p_books_tenant_id,
        'cargo'::public.profile_party_type,
        p_ship.cargo_company_id,
        COALESCE(v_name, 'Cargo #' || p_ship.cargo_company_id::text),
        NULL, NULL, '+880', NULL, false, NULL, true, NULL
      );
    END IF;
    RETURN;
  END IF;

  SELECT t.name INTO v_name FROM public.tenants t WHERE t.id = p_books_tenant_id;
  profile_id := public.upsert_profile_for_party(
    p_books_tenant_id,
    'company'::public.profile_party_type,
    p_books_tenant_id,
    'Local opex',
    NULL, NULL, '+880', NULL, false, NULL, true, NULL
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._resolve_shipment_cost_ap_kernel_parties(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_ship public.global_shipments%ROWTYPE;
  v_parent bigint;
  v_from_profile bigint;
  v_buckets text[] := ARRAY[
    'material', 'freight', 'customs', 'handling', 'finance', 'other'
  ];
  v_bucket text;
  v_bucket_enum public.global_shipment_cost_bucket;
  v_to_profile bigint;
  v_diag text;
  v_payees jsonb := '{}'::jsonb;
BEGIN
  SELECT * INTO v_ship FROM public.global_shipments WHERE id = p_shipment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  v_parent := v_ship.tenant_id;

  BEGIN
    v_from_profile := public._shipment_cost_ap_ensure_public_from_profile(v_parent);
    IF v_from_profile IS NOT NULL THEN
      PERFORM money_kernel.ensure_profile_for_public_party(v_parent, v_from_profile);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_from_profile := NULL;
  END;

  FOREACH v_bucket IN ARRAY v_buckets
  LOOP
    v_bucket_enum := v_bucket::public.global_shipment_cost_bucket;
    SELECT tp.profile_id, tp.diagnostic
      INTO v_to_profile, v_diag
      FROM public._shipment_cost_ap_ensure_public_to_profile(v_parent, v_ship, v_bucket_enum) tp;

    IF v_to_profile IS NOT NULL THEN
      BEGIN
        PERFORM money_kernel.ensure_profile_for_public_party(v_parent, v_to_profile);
      EXCEPTION WHEN OTHERS THEN
        v_diag := COALESCE(v_diag, SQLERRM);
        v_to_profile := NULL;
      END;
    END IF;

    v_payees := v_payees || jsonb_build_object(
      v_bucket,
      jsonb_build_object(
        'profile_id', v_to_profile,
        'ready', (v_to_profile IS NOT NULL AND v_from_profile IS NOT NULL),
        'diagnostic', v_diag
      )
    );
  END LOOP;

  RETURN jsonb_build_object(
    'books_tenant_id', v_parent,
    'from_profile_id', v_from_profile,
    'payees_by_bucket', v_payees
  );
END;
$$;

-- issue_shipment_cost_entry_ap_v2 removed (Option A — table dropped in 20261112130000).

-- ---------------------------------------------------------------------------
-- Option A: shipment AP bills (kernel drafts) + buckets index
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public._shipment_ap_bucket_is_valid(p_bucket text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT p_bucket IN (
    'material', 'freight', 'customs', 'handling', 'finance', 'other',
    'vendor', 'cargo', 'local'
  );
$$;

CREATE OR REPLACE FUNCTION public._shipment_buckets_append(
  p_shipment_id bigint,
  p_bucket text,
  p_bill_id bigint,
  p_currency_code text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_ship public.global_shipments%ROWTYPE;
  v_buckets jsonb;
  v_elem jsonb;
BEGIN
  IF NOT public._shipment_ap_bucket_is_valid(p_bucket) THEN
    RAISE EXCEPTION 'invalid_arguments: unknown bucket %', p_bucket;
  END IF;

  SELECT * INTO v_ship FROM public.global_shipments WHERE id = p_shipment_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  v_buckets := COALESCE(v_ship.buckets, '[]'::jsonb);

  FOR v_elem IN SELECT value FROM jsonb_array_elements(v_buckets)
  LOOP
    IF (v_elem->>'bill_id')::bigint = p_bill_id THEN
      RAISE EXCEPTION 'invalid_arguments: bill % already indexed on shipment', p_bill_id;
    END IF;
  END LOOP;

  v_buckets := v_buckets || jsonb_build_array(
    jsonb_build_object(
      'bucket', p_bucket,
      'bill_id', p_bill_id,
      'currency_code', upper(p_currency_code)
    )
  );

  UPDATE public.global_shipments
     SET buckets = v_buckets,
         updated_at = now()
   WHERE id = p_shipment_id;

  RETURN v_buckets;
END;
$$;

CREATE OR REPLACE FUNCTION public._shipment_buckets_remove(p_shipment_id bigint, p_bill_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_buckets jsonb;
BEGIN
  SELECT COALESCE(buckets, '[]'::jsonb) INTO v_buckets
    FROM public.global_shipments
   WHERE id = p_shipment_id
   FOR UPDATE;

  v_buckets := COALESCE(
    (
      SELECT jsonb_agg(elem)
      FROM jsonb_array_elements(v_buckets) elem
      WHERE (elem->>'bill_id')::bigint IS DISTINCT FROM p_bill_id
    ),
    '[]'::jsonb
  );

  UPDATE public.global_shipments
     SET buckets = v_buckets,
         updated_at = now()
   WHERE id = p_shipment_id;

  RETURN v_buckets;
END;
$$;

CREATE OR REPLACE FUNCTION public._shipment_bill_belongs_to_shipment(
  p_shipment_id bigint,
  p_bill_id bigint
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_found boolean := false;
  v_parent bigint;
  v_issued_by bigint;
BEGIN
  SELECT gs.tenant_id, COALESCE(gs.assigned_child_tenant_id, gs.tenant_id)
    INTO v_parent, v_issued_by
  FROM public.global_shipments gs
  WHERE gs.id = p_shipment_id;

  SELECT EXISTS (
    SELECT 1 FROM jsonb_array_elements(
      COALESCE((SELECT buckets FROM public.global_shipments WHERE id = p_shipment_id), '[]'::jsonb)
    ) elem
    WHERE (elem->>'bill_id')::bigint = p_bill_id
  ) INTO v_found;
  IF v_found THEN
    RETURN true;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM money_kernel.bills b
     WHERE b.id = p_bill_id
       AND b.kind = 'shipment_cost_ap'
       AND (
         (b.source_type = 'shipment_cost' AND b.source_id = p_shipment_id::text)
         OR (b.meta->>'shipment_id')::bigint = p_shipment_id
       )
  ) INTO v_found;
  IF v_found THEN
    RETURN true;
  END IF;

  IF v_parent IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.bills b
      WHERE b.id = p_bill_id
        AND b.tenant_id IN (v_parent, v_issued_by)
        AND b.invoice_type = 'ap'::public.global_invoice_type
        AND b.document_kind = 'standard'::public.bill_document_kind
        AND (
          (b.source_type = 'shipment_cost' AND b.source_id = p_shipment_id::text)
          OR b.ap_shipment_id = p_shipment_id
        )
    ) INTO v_found;
  END IF;

  RETURN COALESCE(v_found, false);
END;
$$;

CREATE OR REPLACE FUNCTION public.create_shipment_ap_bill_v2(
  p_shipment_id bigint,
  p_bucket text,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_ship public.global_shipments%ROWTYPE;
  v_parent bigint;
  v_parties jsonb;
  v_from_kernel bigint;
  v_to_kernel bigint;
  v_currency_code text;
  v_ap_kind text;
  v_source_key text;
  v_suffix text;
  v_lines jsonb := '[]'::jsonb;
  v_line jsonb;
  v_line_obj jsonb;
  v_amount numeric(18, 4);
  v_component text;
  v_desc text;
  v_payload jsonb;
  v_result jsonb;
  v_bill_id bigint;
BEGIN
  IF p_shipment_id IS NULL OR p_bucket IS NULL THEN
    RAISE EXCEPTION 'shipment_id and bucket are required';
  END IF;

  PERFORM public._shipment_money_advisory_lock(p_shipment_id);

  SELECT * INTO v_ship FROM public.global_shipments WHERE id = p_shipment_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  v_parent := v_ship.tenant_id;
  IF NOT public.user_can_manage_books_tenant(v_parent) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  IF public.global_shipment_costs_are_locked(v_ship) THEN
    RAISE EXCEPTION 'shipment costs are locked';
  END IF;

  IF NOT public._shipment_ap_bucket_is_valid(p_bucket) THEN
    RAISE EXCEPTION 'invalid_arguments: unknown bucket %', p_bucket;
  END IF;

  v_ap_kind := lower(btrim(p_bucket));
  v_currency_code := upper(COALESCE(NULLIF(btrim(p_payload->>'currency_code'), ''), 'BDT'));

  IF NOT EXISTS (SELECT 1 FROM public.global_currencies c WHERE c.code = v_currency_code) THEN
    RAISE EXCEPTION 'invalid_arguments: currency % not in public.global_currencies', v_currency_code;
  END IF;

  v_parties := public._resolve_shipment_cost_ap_kernel_parties(v_ship.id);
  v_from_kernel := NULLIF(v_parties->>'from_profile_id', '')::bigint;
  v_to_kernel := NULLIF(v_parties->'payees_by_bucket'->v_ap_kind->>'profile_id', '')::bigint;

  IF v_from_kernel IS NULL OR v_to_kernel IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: AP parties not ready for bucket % (%)',
      v_ap_kind,
      COALESCE(v_parties->'payees_by_bucket'->v_ap_kind->>'diagnostic', 'missing profile');
  END IF;

  FOR v_line IN SELECT * FROM jsonb_array_elements(COALESCE(p_payload->'lines', '[]'::jsonb))
  LOOP
    v_amount := round(COALESCE((v_line->>'amount')::numeric, (v_line->>'unit_price')::numeric, 0), 2);
    IF v_amount <= 0 THEN
      CONTINUE;
    END IF;
    v_component := COALESCE(NULLIF(btrim(v_line->>'cost_component'), ''), 'misc');
    v_desc := COALESCE(
      NULLIF(btrim(v_line->>'description'), ''),
      initcap(replace(v_component, '_', ' '))
    );
    v_line_obj := jsonb_build_object(
      'item_kind', 'charge',
      'description', v_desc,
      'quantity', 1,
      'unit_price', v_amount,
      'line_total', v_amount,
      'meta', jsonb_build_object(
        'cost_component', v_component,
        'is_capitalizable', COALESCE((v_line->>'is_capitalizable')::boolean, true),
        'shipment_id', v_ship.id
      )
    );
    v_lines := v_lines || jsonb_build_array(v_line_obj);
  END LOOP;

  IF jsonb_array_length(v_lines) = 0 THEN
    RAISE EXCEPTION 'invalid_arguments: at least one positive amount line required';
  END IF;

  v_suffix := NULLIF(btrim(p_payload->>'source_key_suffix'), '');
  IF v_suffix IS NULL THEN
    v_suffix := substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
  END IF;
  v_source_key := v_ap_kind || ':' || v_currency_code || ':' || v_suffix;

  v_payload := jsonb_build_object(
    'tenant_id', v_parent,
    'kind', 'shipment_cost_ap',
    'source_entity', 'public.global_shipments',
    'source_type', 'shipment_cost',
    'source_id', v_ship.id::text,
    'source_key', v_source_key,
    'idempotency_key', 'shipment-' || v_ship.id::text || '-ap-' || v_source_key,
    'currency_code', v_currency_code,
    'from_profile_id', v_from_kernel,
    'to_profile_id', v_to_kernel,
    'counterparty_profile_id', v_to_kernel,
    'auto_issue', false,
    'note', COALESCE(
      p_payload->>'note',
      'Shipment ' || COALESCE(v_ship.name, v_ship.id::text) || ' — ' || initcap(v_ap_kind) || ' AP'
    ),
    'meta', jsonb_build_object(
      'ap_kind', v_ap_kind,
      'shipment_id', v_ship.id,
      'bucket', v_ap_kind
    ),
    'lines', v_lines
  );

  v_result := public.rpc_create_bill(v_payload);
  v_bill_id := NULLIF(v_result->>'bill_id', '')::bigint;
  IF v_bill_id IS NULL THEN
    RAISE EXCEPTION 'rpc_create_bill returned no bill_id';
  END IF;

  PERFORM public._shipment_buckets_append(p_shipment_id, v_ap_kind, v_bill_id, v_currency_code);

  RETURN v_result
    || jsonb_build_object(
      'shipment_id', p_shipment_id,
      'bucket', v_ap_kind,
      'ap_kind', v_ap_kind,
      'source_key', v_source_key,
      'cost_lines', COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object(
            'cost_component', COALESCE(NULLIF(btrim(bl.meta->>'cost_component'), ''), 'misc'),
            'amount', bl.line_total,
            'description', bl.description
          )
          ORDER BY bl.line_no
        )
        FROM money_kernel.bill_lines bl
        WHERE bl.tenant_id = v_parent
          AND bl.bill_id = v_bill_id
      ), '[]'::jsonb)
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.update_shipment_ap_bill_v2(
  p_shipment_id bigint,
  p_bill_id bigint,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_ship public.global_shipments%ROWTYPE;
  v_parent bigint;
  v_bill money_kernel.bills;
  v_lines jsonb := '[]'::jsonb;
  v_line jsonb;
  v_line_obj jsonb;
  v_amount numeric(18, 4);
  v_component text;
  v_desc text;
  v_update_payload jsonb;
  v_result jsonb;
BEGIN
  IF p_shipment_id IS NULL OR p_bill_id IS NULL THEN
    RAISE EXCEPTION 'shipment_id and bill_id are required';
  END IF;

  PERFORM public._shipment_money_advisory_lock(p_shipment_id);

  SELECT * INTO v_ship FROM public.global_shipments WHERE id = p_shipment_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  v_parent := v_ship.tenant_id;
  IF NOT public.user_can_manage_books_tenant(v_parent) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  IF public.global_shipment_costs_are_locked(v_ship) THEN
    RAISE EXCEPTION 'shipment costs are locked';
  END IF;

  IF NOT public._shipment_bill_belongs_to_shipment(p_shipment_id, p_bill_id) THEN
    RAISE EXCEPTION 'bill % is not linked to shipment %', p_bill_id, p_shipment_id;
  END IF;

  SELECT * INTO v_bill FROM money_kernel.bills
   WHERE id = p_bill_id AND tenant_id = v_parent;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'bill not found';
  END IF;
  IF v_bill.status <> 'draft' THEN
    RAISE EXCEPTION 'only draft bills can be edited';
  END IF;

  IF p_payload ? 'lines' THEN
    FOR v_line IN SELECT * FROM jsonb_array_elements(p_payload->'lines')
    LOOP
      v_amount := round(COALESCE((v_line->>'amount')::numeric, (v_line->>'unit_price')::numeric, 0), 2);
      IF v_amount <= 0 THEN
        CONTINUE;
      END IF;
      v_component := COALESCE(NULLIF(btrim(v_line->>'cost_component'), ''), 'misc');
      v_desc := COALESCE(
        NULLIF(btrim(v_line->>'description'), ''),
        initcap(replace(v_component, '_', ' '))
      );
      v_line_obj := jsonb_build_object(
        'item_kind', 'charge',
        'description', v_desc,
        'quantity', 1,
        'unit_price', v_amount,
        'line_total', v_amount,
        'meta', jsonb_build_object(
          'cost_component', v_component,
          'is_capitalizable', COALESCE((v_line->>'is_capitalizable')::boolean, true),
          'shipment_id', p_shipment_id
        )
      );
      v_lines := v_lines || jsonb_build_array(v_line_obj);
    END LOOP;

    IF jsonb_array_length(v_lines) = 0 THEN
      RAISE EXCEPTION 'invalid_arguments: at least one positive amount line required';
    END IF;
  END IF;

  v_update_payload := COALESCE(p_payload, '{}'::jsonb);
  IF jsonb_array_length(v_lines) > 0 THEN
    v_update_payload := v_update_payload || jsonb_build_object('lines', v_lines);
  END IF;

  v_result := public.rpc_update_draft_bill_v2(v_parent, p_bill_id, v_update_payload);

  RETURN v_result
    || jsonb_build_object(
      'shipment_id', p_shipment_id,
      'bill_id', p_bill_id,
      'cost_lines', COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object(
            'cost_component', COALESCE(NULLIF(btrim(bl.meta->>'cost_component'), ''), 'misc'),
            'amount', bl.line_total,
            'description', bl.description
          )
          ORDER BY bl.line_no
        )
        FROM money_kernel.bill_lines bl
        WHERE bl.tenant_id = v_parent
          AND bl.bill_id = p_bill_id
      ), '[]'::jsonb)
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.void_shipment_ap_bill_v2(p_shipment_id bigint, p_bill_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_parent bigint;
  v_issued_by bigint;
  v_bill money_kernel.bills;
  v_legacy public.bills;
BEGIN
  PERFORM public._shipment_money_advisory_lock(p_shipment_id);

  SELECT gs.tenant_id, COALESCE(gs.assigned_child_tenant_id, gs.tenant_id)
    INTO v_parent, v_issued_by
  FROM public.global_shipments gs
  WHERE gs.id = p_shipment_id
  FOR UPDATE;
  IF v_parent IS NULL THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF NOT public.user_can_manage_books_tenant(v_parent) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  IF NOT public._shipment_bill_belongs_to_shipment(p_shipment_id, p_bill_id) THEN
    RAISE EXCEPTION 'bill % is not linked to shipment %', p_bill_id, p_shipment_id;
  END IF;

  SELECT * INTO v_bill FROM money_kernel.bills
   WHERE id = p_bill_id AND tenant_id = v_parent
   FOR UPDATE;
  IF FOUND THEN
    IF v_bill.status <> 'draft' THEN
      RAISE EXCEPTION 'only draft bills can be permanently deleted';
    END IF;
    IF EXISTS (
      SELECT 1 FROM money_kernel.bill_settlements bs
      WHERE bs.bill_id = p_bill_id OR bs.source_bill_id = p_bill_id
    ) THEN
      RAISE EXCEPTION 'cannot delete bill with settlements';
    END IF;

    PERFORM public.assert_kernel_money_access(v_parent, 'void');
    PERFORM public._shipment_buckets_remove(p_shipment_id, p_bill_id);

    DELETE FROM money_kernel.bills
     WHERE id = p_bill_id AND tenant_id = v_parent;

    DELETE FROM public.bills pb
     WHERE pb.id = p_bill_id
       AND pb.tenant_id IN (v_parent, v_issued_by)
       AND pb.invoice_status = 'draft'::public.global_invoice_status
       AND NOT EXISTS (
         SELECT 1 FROM public.bill_settlements bs WHERE bs.bill_id = pb.id
       );

    RETURN jsonb_build_object(
      'bill_id', p_bill_id,
      'status', 'deleted',
      'permanent', true,
      'shipment_id', p_shipment_id
    );
  END IF;

  SELECT * INTO v_legacy
  FROM public.bills b
  WHERE b.id = p_bill_id
    AND b.tenant_id IN (v_parent, v_issued_by)
    AND b.invoice_type = 'ap'::public.global_invoice_type
    AND b.document_kind = 'standard'::public.bill_document_kind
    AND (
      (b.source_type = 'shipment_cost' AND b.source_id = p_shipment_id::text)
      OR b.ap_shipment_id = p_shipment_id
    )
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'bill not found';
  END IF;
  IF v_legacy.invoice_status IS DISTINCT FROM 'draft'::public.global_invoice_status THEN
    RAISE EXCEPTION 'only draft bills can be permanently deleted';
  END IF;
  IF COALESCE(v_legacy.paid_amount, 0) > 0 THEN
    RAISE EXCEPTION 'cannot delete a bill with payments';
  END IF;
  IF EXISTS (SELECT 1 FROM public.bill_settlements bs WHERE bs.bill_id = p_bill_id) THEN
    RAISE EXCEPTION 'cannot delete bill with settlements';
  END IF;

  PERFORM public._shipment_buckets_remove(p_shipment_id, p_bill_id);
  DELETE FROM public.bills WHERE id = p_bill_id;

  RETURN jsonb_build_object(
    'bill_id', p_bill_id,
    'status', 'deleted',
    'permanent', true,
    'shipment_id', p_shipment_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.issue_shipment_ap_bill_v2(
  p_shipment_id bigint,
  p_bill_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_parent bigint;
  v_bill money_kernel.bills;
  v_issue jsonb;
  v_bundle jsonb;
BEGIN
  PERFORM public._shipment_money_advisory_lock(p_shipment_id);

  SELECT tenant_id INTO v_parent
    FROM public.global_shipments
   WHERE id = p_shipment_id
   FOR UPDATE;
  IF v_parent IS NULL THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF NOT public.user_can_manage_books_tenant(v_parent) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  IF NOT public._shipment_bill_belongs_to_shipment(p_shipment_id, p_bill_id) THEN
    RAISE EXCEPTION 'bill % is not linked to shipment %', p_bill_id, p_shipment_id;
  END IF;

  SELECT * INTO v_bill
    FROM money_kernel.bills
   WHERE id = p_bill_id AND tenant_id = v_parent
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'bill not found';
  END IF;
  IF v_bill.kind IS DISTINCT FROM 'shipment_cost_ap' THEN
    RAISE EXCEPTION 'not a shipment cost AP bill';
  END IF;
  IF v_bill.status NOT IN ('draft', 'issued') THEN
    RAISE EXCEPTION 'cannot issue bill in status %', v_bill.status;
  END IF;

  IF v_bill.status = 'draft' THEN
    PERFORM set_config('app.bill_desk_issue_shipment_ap', '1', true);
    PERFORM set_config('app.shipment_ap_issue', '1', true);
    BEGIN
      v_issue := public.rpc_issue_bill(v_parent, p_bill_id);
    EXCEPTION
      WHEN OTHERS THEN
        PERFORM set_config('app.bill_desk_issue_shipment_ap', '0', true);
        PERFORM set_config('app.shipment_ap_issue', '0', true);
        RAISE;
    END;
    PERFORM set_config('app.bill_desk_issue_shipment_ap', '0', true);
    PERFORM set_config('app.shipment_ap_issue', '0', true);
  ELSE
    v_issue := jsonb_build_object(
      'bill_id', v_bill.id,
      'invoice_no', v_bill.invoice_no,
      'status', 'issued',
      'idempotent', true
    );
  END IF;

  v_bundle := public.get_shipment_money_kernel_bundle(p_shipment_id);

  RETURN jsonb_build_object(
    'shipment_id', p_shipment_id,
    'bill_id', p_bill_id,
    'issue', v_issue,
    'finance_bundle', v_bundle
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.issue_shipment_ap_drafts_v2(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_parent bigint;
  v_buckets jsonb;
  v_elem jsonb;
  v_bill_id bigint;
  v_bill money_kernel.bills;
  v_issued jsonb := '[]'::jsonb;
  v_result jsonb;
BEGIN
  SELECT tenant_id, COALESCE(buckets, '[]'::jsonb)
    INTO v_parent, v_buckets
    FROM public.global_shipments
   WHERE id = p_shipment_id
   FOR UPDATE;

  IF v_parent IS NULL THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF NOT public.user_can_manage_books_tenant(v_parent) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  FOR v_elem IN SELECT value FROM jsonb_array_elements(v_buckets)
  LOOP
    v_bill_id := NULLIF(v_elem->>'bill_id', '')::bigint;
    IF v_bill_id IS NULL THEN
      CONTINUE;
    END IF;

    SELECT * INTO v_bill FROM money_kernel.bills
     WHERE id = v_bill_id AND tenant_id = v_parent;

    IF NOT FOUND OR v_bill.status IN ('voided', 'issued', 'partial', 'paid', 'written_off') THEN
      CONTINUE;
    END IF;

    IF v_bill.status = 'draft' THEN
      v_result := public.rpc_issue_bill(v_parent, v_bill_id);
      v_issued := v_issued || jsonb_build_array(v_result);
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'shipment_id', p_shipment_id,
    'issued', v_issued
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._shipment_kernel_capitalizable_bucket_total(
  p_shipment_id bigint,
  p_bucket text
)
RETURNS numeric
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
  SELECT COALESCE(SUM(bl.line_total), 0)
    FROM money_kernel.bills b
    JOIN money_kernel.bill_lines bl ON bl.bill_id = b.id AND bl.tenant_id = b.tenant_id
   WHERE b.kind = 'shipment_cost_ap'
     AND b.source_type = 'shipment_cost'
     AND b.source_id = p_shipment_id::text
     AND b.status <> 'voided'
     AND COALESCE(b.meta->>'ap_kind', split_part(COALESCE(b.source_key, ''), ':', 1)) = p_bucket
     AND COALESCE((bl.meta->>'is_capitalizable')::boolean, true) = true;
$$;

CREATE OR REPLACE FUNCTION public.get_shipment_settings_finance_bundle(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_parent bigint;
  v_buckets jsonb;
  v_cost_entries jsonb;
  v_ap_bills jsonb;
  v_ap_fx jsonb;
  v_sid text;
  v_elem jsonb;
  v_slim jsonb := '[]'::jsonb;
begin
  select gs.tenant_id, coalesce(gs.buckets, '[]'::jsonb)
    into v_parent, v_buckets
  from public.global_shipments gs
  where gs.id = p_shipment_id;

  if v_parent is null then
    raise exception 'shipment not found';
  end if;

  if not (
    public.user_can_manage_books_tenant(v_parent)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_parent
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
  ) then
    raise exception 'not allowed';
  end if;

  v_cost_entries := '[]'::jsonb;
  v_sid := p_shipment_id::text;

  for v_elem in
    select value
    from jsonb_array_elements(
      public._list_shipment_cost_ap_bills_json(v_parent, p_shipment_id, false)
    )
  loop
    v_slim := v_slim || jsonb_build_array(
      jsonb_build_object(
        'id', v_elem->'id',
        'invoice_no', v_elem->'invoice_no',
        'ap_kind', v_elem->'ap_kind',
        'source_type', v_elem->'source_type',
        'source_id', v_elem->'source_id',
        'source_key', v_elem->'source_key',
        'invoice_status', v_elem->'invoice_status',
        'payment_status', v_elem->'payment_status',
        'total_amount', coalesce(
          nullif(v_elem->>'total_amount', '')::numeric,
          nullif(v_elem->'net_balances'->>'open_txn', '')::numeric,
          0
        ),
        'due_amount', coalesce(
          nullif(v_elem->'net_balances'->>'open_books', '')::numeric,
          nullif(v_elem->'net_balances'->>'open_txn', '')::numeric,
          nullif(v_elem->>'due_amount', '')::numeric,
          0
        ),
        'net_balances', v_elem->'net_balances',
        'cost_lines', coalesce(v_elem->'cost_lines', '[]'::jsonb)
      )
    );
  end loop;
  v_ap_bills := v_slim;

  v_ap_fx := public._global_shipment_landed_fx_inputs(p_shipment_id);
  v_ap_fx := v_ap_fx - 'blended_rate';

  return jsonb_build_object(
    'buckets', v_buckets,
    'cost_entries', v_cost_entries,
    'ap_bills', v_ap_bills,
    'ap_fx', v_ap_fx,
    'ap_issue_parties', public._resolve_shipment_cost_ap_kernel_parties(p_shipment_id)
  );
end;
$$;

REVOKE ALL ON FUNCTION public.get_shipment_settings_finance_bundle(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_shipment_settings_finance_bundle(bigint) TO authenticated, service_role;

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
GRANT EXECUTE ON FUNCTION public._resolve_shipment_cost_ap_kernel_parties(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_shipment_ap_bill_v2(bigint, text, jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_shipment_ap_bill_v2(bigint, bigint, jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.void_shipment_ap_bill_v2(bigint, bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.issue_shipment_ap_bill_v2(bigint, bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.issue_shipment_ap_drafts_v2(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.post_shipment_ap_money_out(
  bigint[], bigint, bigint, date, numeric, text, text, text, bigint, jsonb, jsonb, text, numeric, numeric, text, text, text
) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.post_shipment_ap_money_out_snapshot(
  bigint[], bigint, bigint, date, bigint, text, text, jsonb, jsonb, text, numeric, numeric, text, numeric, bigint, text
) TO authenticated, service_role;
