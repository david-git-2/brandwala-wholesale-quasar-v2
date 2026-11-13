-- One draft AP bill per Create; multiple money_kernel.bill_lines per component.
-- List bundle includes cost_lines for UI.

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

  IF NOT EXISTS (SELECT 1 FROM money_kernel.currencies c WHERE c.code = v_currency_code) THEN
    RAISE EXCEPTION 'invalid_arguments: currency % not in money_kernel.currencies', v_currency_code;
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
      'source_key', v_source_key
    );
END;
$$;
