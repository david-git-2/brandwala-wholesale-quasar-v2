-- Shipment AP: workspace tenant (x-selected-tenant-id); rpc_get_bill direct tenant; retire child procurement RPCs.

CREATE OR REPLACE FUNCTION public._shipment_money_workspace_tenant(p_shipment_id bigint)
RETURNS bigint
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_workspace bigint;
  v_ship_tenant bigint;
BEGIN
  v_workspace := public.current_tenant_id();
  IF v_workspace IS NULL AND COALESCE(auth.role(), '') IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'workspace tenant required (x-selected-tenant-id header)';
  END IF;

  SELECT gs.tenant_id INTO v_ship_tenant
  FROM public.global_shipments gs
  WHERE gs.id = p_shipment_id;

  IF v_ship_tenant IS NULL THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF v_workspace IS NOT NULL AND v_ship_tenant IS DISTINCT FROM v_workspace THEN
    RAISE EXCEPTION 'shipment % is not in workspace tenant %', p_shipment_id, v_workspace;
  END IF;

  RETURN COALESCE(v_workspace, v_ship_tenant);
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
  v_workspace bigint;
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

  v_workspace := public._shipment_money_workspace_tenant(p_shipment_id);

  BEGIN
    v_from_profile := public._shipment_cost_ap_ensure_public_from_profile(v_workspace);
    IF v_from_profile IS NOT NULL THEN
      PERFORM money_kernel.ensure_profile_for_public_party(v_workspace, v_from_profile);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_from_profile := NULL;
  END;

  FOREACH v_bucket IN ARRAY v_buckets
  LOOP
    v_bucket_enum := v_bucket::public.global_shipment_cost_bucket;
    SELECT tp.profile_id, tp.diagnostic
      INTO v_to_profile, v_diag
      FROM public._shipment_cost_ap_ensure_public_to_profile(v_workspace, v_ship, v_bucket_enum) tp;

    IF v_to_profile IS NOT NULL THEN
      BEGIN
        PERFORM money_kernel.ensure_profile_for_public_party(v_workspace, v_to_profile);
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
    'books_tenant_id', v_workspace,
    'from_profile_id', v_from_profile,
    'payees_by_bucket', v_payees
  );
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
  v_workspace bigint;
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

  v_workspace := public._shipment_money_workspace_tenant(p_shipment_id);
  IF NOT public.user_can_manage_books_tenant(v_workspace) THEN
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
    'tenant_id', v_workspace,
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
        WHERE bl.tenant_id = v_workspace
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
  v_workspace bigint;
  v_bill money_kernel.bills;
  v_lines jsonb := '[]'::jsonb;
  v_line jsonb;
  v_line_obj jsonb;
  v_bl money_kernel.bill_lines;
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

  v_workspace := public._shipment_money_workspace_tenant(p_shipment_id);
  IF NOT public.user_can_manage_books_tenant(v_workspace) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  IF public.global_shipment_costs_are_locked(v_ship) THEN
    RAISE EXCEPTION 'shipment costs are locked';
  END IF;

  IF NOT public._shipment_bill_belongs_to_shipment(p_shipment_id, p_bill_id) THEN
    RAISE EXCEPTION 'bill % is not linked to shipment %', p_bill_id, p_shipment_id;
  END IF;

  SELECT * INTO v_bill FROM money_kernel.bills
   WHERE id = p_bill_id AND tenant_id = v_workspace;
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
  ELSE
    FOR v_bl IN
      SELECT * FROM money_kernel.bill_lines bl
       WHERE bl.bill_id = p_bill_id AND bl.tenant_id = v_workspace
       ORDER BY bl.line_no
    LOOP
      v_lines := v_lines || jsonb_build_array(
        jsonb_build_object(
          'item_kind', v_bl.item_kind,
          'description', v_bl.description,
          'quantity', v_bl.quantity,
          'unit_price', v_bl.unit_price,
          'line_total', v_bl.line_total,
          'meta', v_bl.meta
        )
      );
    END LOOP;
    IF jsonb_array_length(v_lines) = 0 THEN
      RAISE EXCEPTION 'invalid_arguments: bill has no lines to update';
    END IF;
  END IF;

  v_update_payload := COALESCE(p_payload, '{}'::jsonb);
  v_update_payload := v_update_payload || jsonb_build_object('lines', v_lines);
  v_update_payload := v_update_payload || jsonb_build_object('meta', v_section_meta);

  v_result := public.rpc_update_draft_bill_v2(v_workspace, p_bill_id, v_update_payload);

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

CREATE OR REPLACE FUNCTION public.void_shipment_ap_bill_v2(p_shipment_id bigint, p_bill_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_workspace bigint;
  v_bill money_kernel.bills;
  v_legacy public.bills;
BEGIN
  PERFORM public._shipment_money_advisory_lock(p_shipment_id);

  PERFORM 1
  FROM public.global_shipments gs
  WHERE gs.id = p_shipment_id
  FOR UPDATE;

  v_workspace := public._shipment_money_workspace_tenant(p_shipment_id);

  IF NOT public.user_can_manage_books_tenant(v_workspace) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  IF NOT public._shipment_bill_belongs_to_shipment(p_shipment_id, p_bill_id) THEN
    RAISE EXCEPTION 'bill % is not linked to shipment %', p_bill_id, p_shipment_id;
  END IF;

  SELECT * INTO v_bill FROM money_kernel.bills
   WHERE id = p_bill_id AND tenant_id = v_workspace
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

    PERFORM public.assert_kernel_money_access(v_workspace, 'void');
    PERFORM public._shipment_buckets_remove(p_shipment_id, p_bill_id);

    PERFORM money_kernel.fn_kernel_settlement_delete_allowed();

    DELETE FROM money_kernel.bill_lines
     WHERE bill_id = p_bill_id AND tenant_id = v_bill.tenant_id;

    DELETE FROM money_kernel.bills
     WHERE id = p_bill_id AND tenant_id = v_bill.tenant_id;

    DELETE FROM public.bills pb
     WHERE pb.id = p_bill_id
       AND pb.tenant_id = v_workspace
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
    AND b.tenant_id = v_workspace
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
  v_workspace bigint;
  v_bill money_kernel.bills;
  v_issue jsonb;
  v_bundle jsonb;
BEGIN
  PERFORM public._shipment_money_advisory_lock(p_shipment_id);

  PERFORM 1
  FROM public.global_shipments
   WHERE id = p_shipment_id
   FOR UPDATE;

  v_workspace := public._shipment_money_workspace_tenant(p_shipment_id);

  IF NOT public.user_can_manage_books_tenant(v_workspace) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  IF NOT public._shipment_bill_belongs_to_shipment(p_shipment_id, p_bill_id) THEN
    RAISE EXCEPTION 'bill % is not linked to shipment %', p_bill_id, p_shipment_id;
  END IF;

  SELECT * INTO v_bill
    FROM money_kernel.bills
   WHERE id = p_bill_id AND tenant_id = v_workspace
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
      v_issue := public.rpc_issue_bill(v_workspace, p_bill_id);
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
  v_workspace bigint;
  v_buckets jsonb;
  v_elem jsonb;
  v_bill_id bigint;
  v_bill money_kernel.bills;
  v_issued jsonb := '[]'::jsonb;
  v_result jsonb;
BEGIN
  SELECT COALESCE(buckets, '[]'::jsonb)
    INTO v_buckets
    FROM public.global_shipments
   WHERE id = p_shipment_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  v_workspace := public._shipment_money_workspace_tenant(p_shipment_id);

  IF NOT public.user_can_manage_books_tenant(v_workspace) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  FOR v_elem IN SELECT value FROM jsonb_array_elements(v_buckets)
  LOOP
    v_bill_id := NULLIF(v_elem->>'bill_id', '')::bigint;
    IF v_bill_id IS NULL THEN
      CONTINUE;
    END IF;

    SELECT * INTO v_bill FROM money_kernel.bills
     WHERE id = v_bill_id AND tenant_id = v_workspace;

    IF NOT FOUND OR v_bill.status IN ('voided', 'issued', 'partial', 'paid', 'written_off') THEN
      CONTINUE;
    END IF;

    IF v_bill.status = 'draft' THEN
      v_result := public.rpc_issue_bill(v_workspace, v_bill_id);
      v_issued := v_issued || jsonb_build_array(v_result);
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'shipment_id', p_shipment_id,
    'issued', v_issued
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_shipment_settings_finance_bundle(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_workspace bigint;
  v_buckets jsonb;
  v_cost_entries jsonb;
  v_ap_bills jsonb;
  v_ap_fx jsonb;
  v_sid text;
  v_elem jsonb;
  v_slim jsonb := '[]'::jsonb;
begin
  select coalesce(gs.buckets, '[]'::jsonb)
    into v_buckets
  from public.global_shipments gs
  where gs.id = p_shipment_id;

  if not found then
    raise exception 'shipment not found';
  end if;

  v_workspace := public._shipment_money_workspace_tenant(p_shipment_id);

  if not (
    public.user_can_manage_books_tenant(v_workspace)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_workspace
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
      public._list_shipment_cost_ap_bills_json(v_workspace, p_shipment_id, false)
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

CREATE OR REPLACE FUNCTION public.sync_shipment_ap_bills(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_ship public.global_shipments;
  v_parent bigint;
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

  v_parent := public._shipment_money_workspace_tenant(p_shipment_id);

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
          v_parent,
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
            'tenant_id', v_parent,
            'adapter', 'shipment_cost',
            'parent_tenant_id', v_parent,
            'issued_by_tenant_id', v_parent,
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
BEGIN
  SELECT gs.tenant_id
    INTO v_parent
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
        AND b.tenant_id = v_parent
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

CREATE OR REPLACE FUNCTION public.rpc_get_bill(
  p_tenant_id bigint,
  p_bill_id   bigint,
  p_include   text[] DEFAULT '{lines}'
    -- any subset of: lines | settlements | events | meta_expanded
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_bill money_kernel.bills;
  v_result     jsonb;
  v_lines      jsonb;
  v_settlements jsonb;
  v_events     jsonb;
  v_meta_exp   jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_bill_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: tenant_id and bill_id are required';
  END IF;

  SELECT * INTO v_bill FROM money_kernel.bills
    WHERE id = p_bill_id AND tenant_id = p_tenant_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: bill % in tenant %', p_bill_id, p_tenant_id;
  END IF;

  -- Core bill fields (always present)
  v_result := jsonb_build_object(
    'bill_id',                 v_bill.id,
    'tenant_id',               v_bill.tenant_id,
    'kind',                    v_bill.kind,
    'status',                  v_bill.status,
    'invoice_no',              v_bill.invoice_no,
    'invoice_date',            v_bill.invoice_date,
    'due_date',                v_bill.due_date,
    'from_profile_id',         v_bill.from_profile_id,
    'to_profile_id',           v_bill.to_profile_id,
    'counterparty_profile_id', v_bill.counterparty_profile_id,
    'counterparty_tenant_id',  v_bill.counterparty_tenant_id,
    'currency_code',           v_bill.currency_code,
    'total_amount',            v_bill.total_amount,
    'paid_amount',             v_bill.paid_amount,
    'due_amount',              v_bill.due_amount,
    'written_off_amount',      v_bill.written_off_amount,
    'parent_bill_id',          v_bill.parent_bill_id,
    'source_entity',           v_bill.source_entity,
    'source_type',             v_bill.source_type,
    'source_id',               v_bill.source_id,
    'source_key',              v_bill.source_key,
    'note',                    v_bill.note,
    'meta',                    v_bill.meta,
    'created_by',              v_bill.created_by,
    'created_at',              v_bill.created_at,
    'updated_at',              v_bill.updated_at
  );

  -- Lines
  IF 'lines' = ANY(p_include) THEN
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'id',          bl.id,
      'line_no',     bl.line_no,
      'item_kind',   bl.item_kind,
      'product_id',  bl.product_id,
      'description', bl.description,
      'quantity',    bl.quantity,
      'unit_price',  bl.unit_price,
      'line_total',        bl.line_total,
      'shipment_item_id',  bl.shipment_item_id,
      'global_stock_id',   bl.global_stock_id,
      'shipment_id',       bl.shipment_id,
      'meta',              bl.meta
    ) ORDER BY bl.line_no), '[]'::jsonb)
    INTO v_lines
    FROM money_kernel.bill_lines bl WHERE bl.bill_id = p_bill_id;

    v_result := v_result || jsonb_build_object('lines', v_lines);
  END IF;

  -- Settlements (payments applied)
  IF 'settlements' = ANY(p_include) THEN
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'settlement_id',          bs.id,
      'settlement_kind',        bs.settlement_kind,
      'pays_id',                bs.pays_id,
      'source_bill_id',         bs.source_bill_id,
      'allocated_amount',       bs.allocated_amount,
      'allocated_books_amount', bs.allocated_books_amount,
      'payment_date',           p.payment_date,
      'payment_kind',           p.kind,
      'payment_status',         p.status,
      'payment_amount',         p.amount,
      'payment_currency',       p.currency_code,
      'from_cash_bundle_id',            p.from_cash_bundle_id,
      'to_cash_bundle_id',              p.to_cash_bundle_id,
      'payment_meta',           p.meta,
      'settled_at',             bs.created_at
    ) ORDER BY bs.created_at DESC), '[]'::jsonb)
    INTO v_settlements
    FROM money_kernel.bill_settlements bs
    LEFT JOIN money_kernel.pays p ON p.id = bs.pays_id
    WHERE bs.bill_id = p_bill_id;

    v_result := v_result || jsonb_build_object('settlements', v_settlements);
  END IF;

  -- Events (lifecycle)
  IF 'events' = ANY(p_include) THEN
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'event_id',   be.id,
      'event_type', be.event_type,
      'payload',    be.payload,
      'actor_id',   be.actor_id,
      'created_at', be.created_at
    ) ORDER BY be.created_at DESC, be.id DESC), '[]'::jsonb)
    INTO v_events
    FROM money_kernel.bill_events be WHERE be.bill_id = p_bill_id;

    v_result := v_result || jsonb_build_object('events', v_events);
  END IF;

  -- Meta expanded: raw meta + well-known keys extracted for typed access
  IF 'meta_expanded' = ANY(p_include) THEN
    v_meta_exp := jsonb_build_object(
      'raw', v_bill.meta,
      'well_known', jsonb_build_object(
        'shipment_id',          (v_bill.meta->>'shipment_id')::bigint,
        'ap_kind',              v_bill.meta->>'ap_kind',
        'original_bill_id',     (v_bill.meta->>'original_bill_id')::bigint,
        'retail_billing_mode',  v_bill.meta->>'retail_billing_mode',
        'reason',               v_bill.meta->>'reason'
      )
    );
    v_result := v_result || jsonb_build_object('meta_expanded', v_meta_exp);
  END IF;

  RETURN v_result || jsonb_build_object('echoed_filters', jsonb_build_object(
    'tenant_id', p_tenant_id,
    'bill_id',   p_bill_id,
    'include',   to_jsonb(p_include)
  ));
END;
$$;


-- Retired child-procurement RPCs (procurement single workspace tenant)
CREATE OR REPLACE FUNCTION public.assign_shipment_to_child(
  p_tenant_id bigint,
  p_child_tenant_id bigint,
  p_shipment_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  RAISE EXCEPTION 'feature_retired: assign_shipment_to_child';
END;
$$;

CREATE OR REPLACE FUNCTION public.list_child_procurement_lines(
  p_tenant_id bigint,
  p_child_tenant_id bigint DEFAULT NULL,
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 100,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  source_type text,
  source_id bigint,
  child_tenant_id bigint,
  child_tenant_name text,
  name text,
  product_id bigint,
  quantity integer,
  cost_bdt numeric,
  price_gbp numeric,
  image_url text,
  barcode text,
  product_code text,
  reference_label text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  RAISE EXCEPTION 'feature_retired: list_child_procurement_lines';
END;
$$;

CREATE OR REPLACE FUNCTION public.add_child_line_to_parent_shipment(
  p_parent_shipment_id bigint,
  p_source_type text,
  p_source_id bigint
)
RETURNS public.global_shipment_items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  RAISE EXCEPTION 'feature_retired: add_child_line_to_parent_shipment';
END;
$$;
