-- Shipment cost AP v2: books tenant on kernel bills; lawful draft hard-delete.

-- _resolve_shipment_cost_ap_kernel_parties
CREATE OR REPLACE FUNCTION public._resolve_shipment_cost_ap_kernel_parties(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_ship public.global_shipments%ROWTYPE;
  v_parent bigint;
  v_books bigint;
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
  v_books := public.resolve_books_tenant_id(v_parent);

  BEGIN
    v_from_profile := public._shipment_cost_ap_ensure_public_from_profile(v_books);
    IF v_from_profile IS NOT NULL THEN
      PERFORM money_kernel.ensure_profile_for_public_party(v_books, v_from_profile);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_from_profile := NULL;
  END;

  FOREACH v_bucket IN ARRAY v_buckets
  LOOP
    v_bucket_enum := v_bucket::public.global_shipment_cost_bucket;
    SELECT tp.profile_id, tp.diagnostic
      INTO v_to_profile, v_diag
      FROM public._shipment_cost_ap_ensure_public_to_profile(v_books, v_ship, v_bucket_enum) tp;

    IF v_to_profile IS NOT NULL THEN
      BEGIN
        PERFORM money_kernel.ensure_profile_for_public_party(v_books, v_to_profile);
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
    'books_tenant_id', v_books,
    'from_profile_id', v_from_profile,
    'payees_by_bucket', v_payees
  );
END;
$$;

-- create_shipment_ap_bill_v2
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
  v_books bigint;
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
  v_section_meta jsonb;
BEGIN
  IF p_shipment_id IS NULL OR p_bucket IS NULL THEN
    RAISE EXCEPTION 'shipment_id and bucket are required';
  END IF;

  v_section_meta := public._shipment_ap_bill_require_section_meta(
    p_shipment_id,
    COALESCE(p_payload->'meta', '{}'::jsonb)
  );

  PERFORM public._shipment_money_advisory_lock(p_shipment_id);

  SELECT * INTO v_ship FROM public.global_shipments WHERE id = p_shipment_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  v_parent := v_ship.tenant_id;
  v_books := public.resolve_books_tenant_id(v_parent);
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
    'tenant_id', v_books,
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
    ) || v_section_meta,
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
        WHERE bl.tenant_id = v_books
          AND bl.bill_id = v_bill_id
      ), '[]'::jsonb)
    );
END;
$$;

-- update_shipment_ap_bill_v2
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
  v_books bigint;
  v_bill money_kernel.bills;
  v_lines jsonb := '[]'::jsonb;
  v_line jsonb;
  v_line_obj jsonb;
  v_amount numeric(18, 4);
  v_component text;
  v_desc text;
  v_update_payload jsonb;
  v_result jsonb;
  v_section_meta jsonb;
BEGIN
  IF p_shipment_id IS NULL OR p_bill_id IS NULL THEN
    RAISE EXCEPTION 'shipment_id and bill_id are required';
  END IF;

  v_section_meta := public._shipment_ap_bill_require_section_meta(
    p_shipment_id,
    COALESCE(p_payload->'meta', '{}'::jsonb)
  );

  PERFORM public._shipment_money_advisory_lock(p_shipment_id);

  SELECT * INTO v_ship FROM public.global_shipments WHERE id = p_shipment_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  v_parent := v_ship.tenant_id;
  v_books := public.resolve_books_tenant_id(v_parent);
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
   WHERE id = p_bill_id AND tenant_id IN (v_books, v_parent);
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
  v_update_payload := v_update_payload || jsonb_build_object('meta', v_section_meta);

  v_result := public.rpc_update_draft_bill_v2(v_bill.tenant_id, p_bill_id, v_update_payload);

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
        WHERE bl.tenant_id = v_bill.tenant_id
          AND bl.bill_id = p_bill_id
      ), '[]'::jsonb)
    );
END;
$$;

-- void_shipment_ap_bill_v2
CREATE OR REPLACE FUNCTION public.void_shipment_ap_bill_v2(p_shipment_id bigint, p_bill_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_parent bigint;
  v_books bigint;
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

  v_books := public.resolve_books_tenant_id(v_parent);

  IF NOT public.user_can_manage_books_tenant(v_parent) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  IF NOT public._shipment_bill_belongs_to_shipment(p_shipment_id, p_bill_id) THEN
    RAISE EXCEPTION 'bill % is not linked to shipment %', p_bill_id, p_shipment_id;
  END IF;

  SELECT * INTO v_bill FROM money_kernel.bills
   WHERE id = p_bill_id AND tenant_id IN (v_books, v_parent)
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

    PERFORM public.assert_kernel_money_access(v_books, 'void');
    PERFORM public._shipment_buckets_remove(p_shipment_id, p_bill_id);

    PERFORM money_kernel.fn_kernel_settlement_delete_allowed();

    DELETE FROM money_kernel.bill_lines
     WHERE bill_id = p_bill_id AND tenant_id = v_bill.tenant_id;

    DELETE FROM money_kernel.bills
     WHERE id = p_bill_id AND tenant_id = v_bill.tenant_id;

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

-- issue_shipment_ap_bill_v2
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
  v_books bigint;
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

  v_books := public.resolve_books_tenant_id(v_parent);

  IF NOT public.user_can_manage_books_tenant(v_parent) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  IF NOT public._shipment_bill_belongs_to_shipment(p_shipment_id, p_bill_id) THEN
    RAISE EXCEPTION 'bill % is not linked to shipment %', p_bill_id, p_shipment_id;
  END IF;

  SELECT * INTO v_bill
    FROM money_kernel.bills
   WHERE id = p_bill_id AND tenant_id IN (v_books, v_parent)
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
      v_issue := public.rpc_issue_bill(v_bill.tenant_id, p_bill_id);
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

-- issue_shipment_ap_drafts_v2
CREATE OR REPLACE FUNCTION public.issue_shipment_ap_drafts_v2(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_parent bigint;
  v_books bigint;
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

  v_books := public.resolve_books_tenant_id(v_parent);

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
     WHERE id = v_bill_id AND tenant_id IN (v_books, v_parent);

    IF NOT FOUND OR v_bill.status IN ('voided', 'issued', 'partial', 'paid', 'written_off') THEN
      CONTINUE;
    END IF;

    IF v_bill.status = 'draft' THEN
      v_result := public.rpc_issue_bill(v_bill.tenant_id, v_bill_id);
      v_issued := v_issued || jsonb_build_array(v_result);
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'shipment_id', p_shipment_id,
    'issued', v_issued
  );
END;
$$;

-- get_shipment_settings_finance_bundle
CREATE OR REPLACE FUNCTION public.get_shipment_settings_finance_bundle(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_parent bigint;
  v_books bigint;
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

  v_books := public.resolve_books_tenant_id(v_parent);

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
      public._list_shipment_cost_ap_bills_json(v_books, p_shipment_id, false)
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

-- delete_draft_bill_from_desk
CREATE OR REPLACE FUNCTION public.delete_draft_bill_from_desk(p_bill_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_b money_kernel.bills;
BEGIN
  SELECT * INTO v_b FROM money_kernel.bills WHERE id = p_bill_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'bill not found';
  END IF;
  IF NOT public.user_can_manage_books_tenant(v_b.tenant_id) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;
  IF v_b.status IS DISTINCT FROM 'draft' THEN
    RAISE EXCEPTION 'Only draft bills can be deleted';
  END IF;
  PERFORM money_kernel.fn_kernel_settlement_delete_allowed();
  DELETE FROM money_kernel.bill_lines WHERE bill_id = p_bill_id AND tenant_id = v_b.tenant_id;
  DELETE FROM money_kernel.bills WHERE id = p_bill_id AND tenant_id = v_b.tenant_id;
END;
$$;

