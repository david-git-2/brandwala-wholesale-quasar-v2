-- BP20/WA15/BP22 function refresh


CREATE OR REPLACE FUNCTION "public"."_upsert_shipment_ap_bill"("p_parent_tenant_id" bigint, "p_issued_by_tenant_id" bigint, "p_shipment_id" bigint, "p_shipment_name" "text", "p_ap_kind" "text", "p_profile_id" bigint, "p_amount" numeric, "p_ap_paper" "jsonb" DEFAULT NULL::"jsonb", "p_keep_as_draft" boolean DEFAULT false, "p_source_key" "text" DEFAULT NULL::"text") RETURNS bigint
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
  v_meta_base jsonb;
  v_paper_status public.global_invoice_status;
  v_plug_key text;
  v_face_currency text;
begin
  if p_ap_kind not in (
    'vendor', 'cargo', 'local',
    'material', 'freight', 'customs', 'handling', 'finance', 'other'
  ) then
    raise exception 'Invalid ap_kind %', p_ap_kind;
  end if;

  v_plug_key := coalesce(nullif(btrim(p_source_key), ''), p_ap_kind);
  v_face_currency := upper(trim(coalesce(p_ap_paper->>'currency_code', 'BDT')));

  select * into v_bill
  from public.bills b
  where b.parent_tenant_id = p_parent_tenant_id
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and b.source_type = 'shipment_cost'
    and b.source_id = p_shipment_id::text
    and b.source_key = v_plug_key
  for update;

  if p_profile_id is null or coalesce(p_amount, 0) <= 0 then
    if v_bill.id is not null and coalesce(v_bill.paid_amount, 0) = 0
       and v_bill.invoice_status in (
         'issued'::public.global_invoice_status,
         'draft'::public.global_invoice_status
       ) then
      update public.bills
      set invoice_status = 'voided'::public.global_invoice_status, updated_at = now()
      where id = v_bill.id;
    end if;
    return null;
  end if;

  v_target := round(p_amount, 2);
  v_kind_label := initcap(replace(p_ap_kind, '_', ' '));
  v_meta_base := jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id);
  if p_ap_paper is not null then
    v_meta_base := v_meta_base || jsonb_build_object('ap_paper', p_ap_paper);
  end if;

  v_paper_status := case
    when p_keep_as_draft then 'draft'::public.global_invoice_status
    else 'issued'::public.global_invoice_status
  end;

  if v_bill.id is null then
    v_invoice_no := public.generate_sales_invoice_number(p_issued_by_tenant_id, 'ap'::public.global_invoice_type, current_date);
    insert into public.bills (
      parent_tenant_id, issued_by_tenant_id, invoice_no, invoice_type, invoice_date,
      invoice_status, profile_id, collection_source, payment_status,
      subtotal_amount, total_amount, due_amount, paid_amount,
      ap_shipment_id, ap_kind, source_type, source_id, source_key, currency_code,
      note, channel_meta, document_kind
    ) values (
      p_parent_tenant_id, p_issued_by_tenant_id, v_invoice_no, 'ap'::public.global_invoice_type, current_date,
      v_paper_status, p_profile_id, 'profile'::public.collection_source_type, 'due',
      v_target, v_target, v_target, 0,
      p_shipment_id, p_ap_kind, 'shipment_cost', p_shipment_id::text, v_plug_key, v_face_currency,
      format(
        'Shipment %s — %s AP%s',
        coalesce(p_shipment_name, p_shipment_id::text),
        v_kind_label,
        case when v_plug_key <> p_ap_kind then ' (' || v_plug_key || ')' else '' end
      ),
      v_meta_base,
      'standard'::public.bill_document_kind
    )
    returning id into v_bill.id;
    perform public.stamp_bill_kernel_fields(v_bill.id);
    return v_bill.id;
  end if;

  if v_bill.invoice_status = 'voided'::public.global_invoice_status then
    if coalesce(v_bill.paid_amount, 0) > 0 then
      return v_bill.id;
    end if;

    update public.bills
    set
      invoice_status = v_paper_status,
      profile_id = p_profile_id,
      subtotal_amount = v_target,
      total_amount = v_target,
      due_amount = v_target,
      payment_status = 'due',
      source_type = coalesce(source_type, 'shipment_cost'),
      source_id = coalesce(source_id, p_shipment_id::text),
      source_key = coalesce(source_key, v_plug_key),
      currency_code = coalesce(nullif(trim(v_face_currency), ''), nullif(trim(currency_code), ''), 'BDT'),
      note = format(
        'Shipment %s — %s AP%s',
        coalesce(p_shipment_name, p_shipment_id::text),
        v_kind_label,
        case when v_plug_key <> p_ap_kind then ' (' || v_plug_key || ')' else '' end
      ),
      channel_meta = coalesce(channel_meta, '{}'::jsonb)
        || jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id)
        || case
          when p_ap_paper is not null then jsonb_build_object('ap_paper', p_ap_paper)
          else '{}'::jsonb
        end,
      updated_at = now()
    where id = v_bill.id;

    perform public.stamp_bill_kernel_fields(v_bill.id);
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
    source_type = coalesce(source_type, 'shipment_cost'),
    source_id = coalesce(source_id, p_shipment_id::text),
    source_key = coalesce(source_key, v_plug_key),
    currency_code = coalesce(nullif(trim(v_face_currency), ''), nullif(trim(currency_code), ''), 'BDT'),
    note = format(
      'Shipment %s — %s AP%s',
      coalesce(p_shipment_name, p_shipment_id::text),
      v_kind_label,
      case when v_plug_key <> p_ap_kind then ' (' || v_plug_key || ')' else '' end
    ),
    channel_meta = coalesce(channel_meta, '{}'::jsonb)
      || jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id)
      || case
        when p_ap_paper is not null and coalesce(v_bill.paid_amount, 0) = 0
        then jsonb_build_object('ap_paper', p_ap_paper)
        else '{}'::jsonb
      end,
    updated_at = now()
  where id = v_bill.id;

  perform public.stamp_bill_kernel_fields(v_bill.id);
  return v_bill.id;
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

CREATE OR REPLACE FUNCTION "public"."record_ledger_transaction"("p_parent_tenant_id" bigint, "p_operating_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_type" "text", "p_amount" numeric, "p_currency_code" "text" DEFAULT 'BDT'::"text", "p_exchange_rate" numeric DEFAULT 1.000000, "p_source_type" "text" DEFAULT 'adjustment'::"text", "p_source_id" "text" DEFAULT NULL::"text", "p_metadata" "jsonb" DEFAULT '{}'::"jsonb", "p_target_bucket" "text" DEFAULT 'available'::"text", "p_allow_overdraft" boolean DEFAULT false, "p_cashbook_point_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_account_id bigint;
  v_avail numeric(18,4);
  v_pend numeric(18,4);
  v_lock numeric(18,4);
  v_base_amount numeric(18,4);
  v_new_balance numeric(18,4);
  v_ledger_entry jsonb;
  v_ledger_id uuid;
  v_entity_id bigint;
  v_point_ok boolean;
  v_pot_id bigint;
BEGIN
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Transaction amount must be greater than zero.';
  END IF;

  IF p_type NOT IN ('credit', 'debit') THEN
    RAISE EXCEPTION 'Transaction type must be credit or debit.';
  END IF;

  IF p_target_bucket NOT IN ('available', 'pending', 'locked') THEN
    RAISE EXCEPTION 'Target bucket must be available, pending, or locked.';
  END IF;

  v_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' AND v_entity_id IS DISTINCT FROM p_parent_tenant_id THEN
    v_entity_id := p_parent_tenant_id;
  END IF;

  INSERT INTO public.cashbook_accounts (
    tenant_id, parent_tenant_id, entity_type, entity_id, currency_code,
    available_balance, pending_balance, locked_balance
  )
  VALUES (
    p_parent_tenant_id, p_parent_tenant_id, p_entity_type, v_entity_id,
    coalesce(p_currency_code, 'BDT'), 0.0000, 0.0000, 0.0000
  )
  ON CONFLICT (parent_tenant_id, entity_type, entity_id, currency_code)
  DO UPDATE SET updated_at = now()
  RETURNING id, available_balance, pending_balance, locked_balance
  INTO v_account_id, v_avail, v_pend, v_lock;

  IF p_cashbook_point_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.cashbook_points cp
      WHERE cp.id = p_cashbook_point_id
        AND cp.parent_tenant_id = p_parent_tenant_id
        AND cp.cashbook_account_id = v_account_id
        AND cp.is_active = true
    ) INTO v_point_ok;
    IF NOT coalesce(v_point_ok, false) THEN
      RAISE EXCEPTION 'Invalid cashbook point for this account.';
    END IF;

    v_pot_id := public._kernel_ensure_cashbook_point_pot(
      p_parent_tenant_id,
      p_cashbook_point_id,
      coalesce(p_currency_code, 'BDT')
    );
    PERFORM 1
    FROM public.cashbook_point_pots cpp
    WHERE cpp.id = v_pot_id
    FOR UPDATE;
  END IF;

  SELECT available_balance, pending_balance, locked_balance
  INTO v_avail, v_pend, v_lock
  FROM public.cashbook_accounts
  WHERE id = v_account_id
  FOR UPDATE;

  IF p_target_bucket = 'available' THEN
    IF p_type = 'credit' THEN
      v_avail := v_avail + p_amount;
    ELSE
      v_avail := v_avail - p_amount;
    END IF;
    v_new_balance := v_avail;
  ELSIF p_target_bucket = 'pending' THEN
    IF p_type = 'credit' THEN
      v_pend := v_pend + p_amount;
    ELSE
      v_pend := v_pend - p_amount;
    END IF;
    v_new_balance := v_pend;
  ELSIF p_target_bucket = 'locked' THEN
    IF p_type = 'credit' THEN
      v_lock := v_lock + p_amount;
    ELSE
      v_lock := v_lock - p_amount;
    END IF;
    v_new_balance := v_lock;
  END IF;

  UPDATE public.cashbook_accounts
  SET
    available_balance = v_avail,
    pending_balance = v_pend,
    locked_balance = v_lock,
    tenant_id = p_parent_tenant_id,
    updated_at = now()
  WHERE id = v_account_id;

  v_base_amount := p_amount * coalesce(p_exchange_rate, 1.000000);

  INSERT INTO public.cashbook_entries (
    tenant_id,
    parent_tenant_id,
    operating_tenant_id,
    entity_type,
    entity_id,
    type,
    amount,
    currency_code,
    exchange_rate,
    base_amount,
    balance_after,
    source_type,
    source_id,
    metadata,
    cashbook_point_id,
    cashbook_point_pot_id
  )
  VALUES (
    p_parent_tenant_id,
    p_parent_tenant_id,
    p_operating_tenant_id,
    p_entity_type,
    v_entity_id,
    p_type,
    p_amount,
    coalesce(p_currency_code, 'BDT'),
    coalesce(p_exchange_rate, 1.000000),
    v_base_amount,
    v_new_balance,
    coalesce(p_source_type, 'adjustment'),
    p_source_id,
    coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object('target_bucket', p_target_bucket),
    p_cashbook_point_id,
    v_pot_id
  )
  RETURNING id INTO v_ledger_id;

  SELECT jsonb_build_object(
    'id', id,
    'parent_tenant_id', parent_tenant_id,
    'operating_tenant_id', operating_tenant_id,
    'tenant_id', parent_tenant_id,
    'entity_type', entity_type,
    'entity_id', entity_id,
    'type', type,
    'amount', amount,
    'currency_code', currency_code,
    'exchange_rate', exchange_rate,
    'base_amount', base_amount,
    'balance_after', balance_after,
    'source_type', source_type,
    'source_id', source_id,
    'metadata', metadata,
    'cashbook_point_id', cashbook_point_id,
    'created_at', created_at
  ) INTO v_ledger_entry
  FROM public.cashbook_entries
  WHERE id = v_ledger_id;

  RETURN v_ledger_entry;
END;
$$;

CREATE OR REPLACE FUNCTION "public"."post_ap_payout_with_allocations"("p_tenant_id" bigint, "p_profile_id" bigint, "p_paid_on" "date", "p_cashbook_point_id" bigint, "p_note" "text" DEFAULT NULL::"text", "p_reference" "text" DEFAULT NULL::"text", "p_instruments" "jsonb" DEFAULT '[]'::"jsonb", "p_allocations" "jsonb" DEFAULT '[]'::"jsonb", "p_settlement_currency_code" "text" DEFAULT 'BDT'::"text", "p_foreign_amount" numeric DEFAULT NULL::numeric, "p_exchange_rate" numeric DEFAULT NULL::numeric, "p_source_currency_code" "text" DEFAULT NULL::"text", "p_transaction_rate" numeric DEFAULT NULL::numeric, "p_cashbook_point_pot_id" bigint DEFAULT NULL::bigint) RETURNS "public"."pays"
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
begin
  if p_tenant_id is null then
    raise exception 'Tenant is required';
  end if;
  if p_profile_id is null then
    raise exception 'Profile is required';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_base_currency := public.resolve_tenant_base_currency_code(p_tenant_id);

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

  if p_cashbook_point_id is null then
    raise exception 'Choose a cash point for this pay out';
  end if;

  if not exists (
    select 1
    from public.cashbook_points cp
    join public.cashbook_accounts ca on ca.id = cp.cashbook_account_id
    where cp.id = p_cashbook_point_id
      and cp.is_active = true
      and ca.parent_tenant_id = v_parent_id
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
      and cpp.parent_tenant_id = v_parent_id
    order by case when upper(cpp.currency_code) = 'BDT' then 0 else 1 end, cpp.id
    limit 1;
  end if;

  if v_pot_id is null and coalesce(v_source_currency, '') <> '' then
    select cpp.id
    into v_pot_id
    from public.cashbook_point_pots cpp
    where cpp.cashbook_point_id = p_cashbook_point_id
      and cpp.parent_tenant_id = v_parent_id
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

  insert into public.pays (
    tenant_id, profile_id, source, amount, unallocated_amount,
    payment_date, method, reference, note,
    settlement_currency_code, foreign_amount, exchange_rate, quote_currency_code, cashbook_point_id,
    source_currency_code, transaction_rate, source_amount, cashbook_point_pot_id
  ) values (
    v_parent_id, p_profile_id, 'ap_payout', v_amount, 0,
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

  return v_pay;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."post_customer_receipt_with_allocations"("p_tenant_id" bigint, "p_profile_id" bigint, "p_received_on" "date", "p_note" "text" DEFAULT NULL::"text", "p_reference" "text" DEFAULT NULL::"text", "p_source" "text" DEFAULT 'customer_cash'::"text", "p_instruments" "jsonb" DEFAULT '[]'::"jsonb", "p_allocations" "jsonb" DEFAULT '[]'::"jsonb", "p_shop_order_id" bigint DEFAULT NULL::bigint, "p_settlement_currency_code" "text" DEFAULT 'BDT'::"text", "p_foreign_amount" numeric DEFAULT NULL::numeric, "p_exchange_rate" numeric DEFAULT NULL::numeric, "p_credit_dropship_profit" boolean DEFAULT true) RETURNS "public"."pays"
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
  v_bill_ids bigint[] := '{}';
  v_sid bigint;
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
    raise exception 'Permission denied: cannot record receipts for this tenant';
  end if;

  if not exists (
    select 1 from public.profiles pr
    where pr.id = p_profile_id and pr.parent_tenant_id = v_parent_id
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

  insert into public.pays (
    tenant_id, profile_id, source, amount, unallocated_amount,
    payment_date, method, reference, note, shop_order_id,
    settlement_currency_code, foreign_amount, exchange_rate
  ) values (
    v_parent_id, p_profile_id, v_source, v_amount, v_amount,
    v_received_on, v_header_method, v_reference, v_note, p_shop_order_id,
    v_settle_currency, v_foreign_amt, v_fx_rate
  ) returning * into v_pay;

  if v_line_count > 0 then
    perform public.insert_global_payment_instruments(v_pay.id, p_instruments);
  end if;

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
      if v_bill.parent_tenant_id <> v_parent_id then
        raise exception 'Bill % belongs to other books', v_bill_id;
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

  v_cashbook_point_id := null;
  if coalesce(jsonb_typeof(p_instruments), 'null') = 'array' then
    for v_line in select value from jsonb_array_elements(p_instruments)
    loop
      if nullif(v_line.value ->> 'cashbook_point_id', '') is not null then
        v_cashbook_point_id := (v_line.value ->> 'cashbook_point_id')::bigint;
        exit;
      end if;
    end loop;
  end if;

  if v_source in ('customer_cash', 'bank', 'courier_remittance') then
    if v_source = 'courier_remittance' and v_cashbook_point_id is null then
      raise exception 'Courier remittance requires a cashbook location';
    end if;

    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_id,
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_parent_id,
      p_type => 'credit',
      p_amount => v_amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
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
        'shop_order_id', case when v_source = 'courier_remittance' then p_shop_order_id else null end
      ),
      p_cashbook_point_id => v_cashbook_point_id
    );
  elsif v_source = 'store_credit' then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_id,
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
        p_parent_tenant_id => v_parent_id,
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

  return v_pay;
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_ensure_cashbook_point_pot(
  p_parent_tenant_id bigint,
  p_cashbook_point_id bigint,
  p_currency_code text
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_id bigint;
  v_ccy text := upper(trim(coalesce(p_currency_code, 'BDT')));
begin
  if p_cashbook_point_id is null then
    return null;
  end if;
  if v_ccy = '' then
    v_ccy := 'BDT';
  end if;

  insert into public.cashbook_point_pots (
    parent_tenant_id, cashbook_point_id, currency_code, amount
  ) values (
    p_parent_tenant_id, p_cashbook_point_id, v_ccy, 0
  )
  on conflict (cashbook_point_id, currency_code)
  do update set updated_at = now()
  returning id into v_id;

  return v_id;
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_lock_cashbook_point_pots(p_cashbook_point_id bigint)
RETURNS void
LANGUAGE plpgsql
AS $$
declare
  v_id bigint;
begin
  if p_cashbook_point_id is null then
    return;
  end if;
  for v_id in
    select cpp.id
    from public.cashbook_point_pots cpp
    where cpp.cashbook_point_id = p_cashbook_point_id
    order by cpp.currency_code asc, cpp.id asc
  loop
    perform 1 from public.cashbook_point_pots where id = v_id for update;
  end loop;
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_deny_cashbook_entry_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
begin
  if coalesce(current_setting('role', true), '') = 'service_role'
     or current_user in ('postgres', 'supabase_admin') then
    if TG_OP = 'DELETE' then
      return OLD;
    end if;
    return NEW;
  end if;
  raise exception 'cashbook_entries are append-only; post a reversing entry instead';
end;
$$;

DROP TRIGGER IF EXISTS trg_cashbook_entries_immutable ON public.cashbook_entries;
CREATE TRIGGER trg_cashbook_entries_immutable
  BEFORE UPDATE OR DELETE ON public.cashbook_entries
  FOR EACH ROW
  EXECUTE FUNCTION public._kernel_deny_cashbook_entry_mutation();

REVOKE UPDATE, DELETE ON TABLE public.cashbook_entries FROM authenticated;

