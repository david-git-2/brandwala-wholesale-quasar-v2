-- Create one draft AP bill per cost component line (not one combined invoice).

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
  v_line jsonb;
  v_line_obj jsonb;
  v_single_lines jsonb;
  v_amount numeric(18, 4);
  v_component text;
  v_desc text;
  v_payload jsonb;
  v_result jsonb;
  v_bill_id bigint;
  v_results jsonb := '[]'::jsonb;
  v_key_taken boolean;
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
    v_single_lines := jsonb_build_array(v_line_obj);

    v_source_key := v_ap_kind || ':' || v_currency_code || ':' || v_component;
    SELECT EXISTS (
      SELECT 1
      FROM money_kernel.bills b
      WHERE b.tenant_id = v_parent
        AND b.source_type = 'shipment_cost'
        AND b.source_id = v_ship.id::text
        AND b.source_key = v_source_key
        AND b.status <> 'voided'
    ) INTO v_key_taken;
    IF v_key_taken THEN
      v_source_key := v_source_key || ':'
        || COALESCE(NULLIF(btrim(p_payload->>'source_key_suffix'), ''), substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    END IF;

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
        'Shipment ' || COALESCE(v_ship.name, v_ship.id::text)
          || ' — ' || initcap(v_ap_kind) || ' AP (' || initcap(replace(v_component, '_', ' ')) || ')'
      ),
      'meta', jsonb_build_object(
        'ap_kind', v_ap_kind,
        'shipment_id', v_ship.id,
        'bucket', v_ap_kind,
        'cost_component', v_component
      ),
      'lines', v_single_lines
    );

    v_result := public.rpc_create_bill(v_payload);
    v_bill_id := NULLIF(v_result->>'bill_id', '')::bigint;
    IF v_bill_id IS NULL THEN
      RAISE EXCEPTION 'rpc_create_bill returned no bill_id for component %', v_component;
    END IF;

    PERFORM public._shipment_buckets_append(p_shipment_id, v_ap_kind, v_bill_id, v_currency_code);

    v_results := v_results || jsonb_build_array(
      v_result
        || jsonb_build_object(
          'shipment_id', p_shipment_id,
          'bucket', v_ap_kind,
          'ap_kind', v_ap_kind,
          'source_key', v_source_key,
          'cost_component', v_component
        )
    );
  END LOOP;

  IF jsonb_array_length(v_results) = 0 THEN
    RAISE EXCEPTION 'invalid_arguments: at least one positive amount line required';
  END IF;

  RETURN v_results->(jsonb_array_length(v_results) - 1)
    || jsonb_build_object(
      'bills', v_results,
      'created_count', jsonb_array_length(v_results)
    );
END;
$$;
