-- Enrich issue_shipment_cost_entry_ap_v2 response for client cache (no finance refetch).

CREATE OR REPLACE FUNCTION public.issue_shipment_cost_entry_ap_v2(p_cost_entry_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_entry public.global_shipment_cost_entries%ROWTYPE;
  v_ship public.global_shipments%ROWTYPE;
  v_parent bigint;
  v_parties jsonb;
  v_from_kernel bigint;
  v_to_kernel bigint;
  v_currency_code text;
  v_paper jsonb;
  v_amount numeric(18, 4);
  v_desc text;
  v_payload jsonb;
  v_result jsonb;
  v_bill_id bigint;
  v_invoice_no text;
  v_ap_kind text;
BEGIN
  IF p_cost_entry_id IS NULL THEN
    RAISE EXCEPTION 'cost_entry_id is required';
  END IF;

  SELECT * INTO v_entry
    FROM public.global_shipment_cost_entries
   WHERE id = p_cost_entry_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'cost entry not found';
  END IF;

  SELECT * INTO v_ship
    FROM public.global_shipments
   WHERE id = v_entry.shipment_id
   FOR UPDATE;

  v_parent := v_ship.tenant_id;

  IF NOT public.user_can_manage_books_tenant(v_parent) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  PERFORM public._assert_shipment_cost_entry_mutable(p_cost_entry_id);

  IF COALESCE(v_entry.amount, 0) <= 0 THEN
    RAISE EXCEPTION 'cost amount must be greater than zero';
  END IF;

  IF COALESCE(v_entry.metadata->>'ap_bill_id', '') <> '' THEN
    RAISE EXCEPTION 'cost entry already has ap_bill_id';
  END IF;

  v_parties := public._resolve_shipment_cost_ap_kernel_parties(v_ship.id);
  v_from_kernel := NULLIF(v_parties->>'from_profile_id', '')::bigint;
  v_ap_kind := v_entry.cost_bucket::text;
  v_to_kernel := NULLIF(v_parties->'payees_by_bucket'->v_ap_kind->>'profile_id', '')::bigint;

  IF v_from_kernel IS NULL OR v_to_kernel IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: AP parties not ready for bucket % (% )',
      v_ap_kind,
      COALESCE(v_parties->'payees_by_bucket'->v_ap_kind->>'diagnostic', 'missing profile');
  END IF;

  SELECT upper(coalesce(gc.code, 'BDT')) INTO v_currency_code
    FROM public.global_currencies gc
   WHERE gc.id = COALESCE(
     v_entry.currency_id,
     v_ship.shipment_cost_currency_id,
     v_ship.shipment_purchase_currency_id
   );

  IF v_currency_code IS NULL OR v_currency_code = '' THEN
    v_currency_code := 'BDT';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM money_kernel.currencies c WHERE c.code = v_currency_code
  ) THEN
    RAISE EXCEPTION 'invalid_arguments: currency % not in money_kernel.currencies', v_currency_code;
  END IF;

  v_paper := public._build_shipment_ap_cost_entry_paper(v_entry, v_ship);
  v_amount := round(COALESCE((v_paper->>'foreign_total')::numeric, v_entry.amount), 2);

  v_desc := COALESCE(
    NULLIF(trim(v_entry.description), ''),
    NULLIF(trim(v_entry.metadata->>'description'), ''),
  initcap(replace(v_entry.cost_component::text, '_', ' '))
  );

  v_payload := jsonb_build_object(
    'tenant_id', v_parent,
    'kind', 'shipment_cost_ap',
    'source_type', 'shipment_cost',
    'source_id', v_ship.id::text,
    'source_key', 'entry:' || v_entry.id::text,
    'idempotency_key', 'shipment-' || v_ship.id::text || '-cost-entry-' || v_entry.id::text || '-issue',
    'currency_code', v_currency_code,
    'from_profile_id', v_from_kernel,
    'to_profile_id', v_to_kernel,
    'counterparty_profile_id', v_to_kernel,
    'auto_issue', true,
    'note', 'Shipment ' || COALESCE(v_ship.name, v_ship.id::text) || ' — '
            || initcap(v_ap_kind) || ' AP (entry:' || v_entry.id::text || ')',
    'meta', jsonb_build_object(
      'ap_kind', v_ap_kind,
      'shipment_id', v_ship.id,
      'ap_paper', v_paper
    ),
    'lines', jsonb_build_array(
      jsonb_build_object(
        'item_kind', 'charge',
        'description', v_desc,
        'quantity', 1,
        'unit_price', v_amount,
        'line_total', v_amount,
        'meta', jsonb_build_object('cost_entry_id', v_entry.id)
      )
    )
  );

  v_result := public.rpc_create_bill(v_payload);
  v_bill_id := NULLIF(v_result->>'bill_id', '')::bigint;
  v_invoice_no := v_result->>'invoice_no';

  IF v_bill_id IS NULL THEN
    RAISE EXCEPTION 'rpc_create_bill returned no bill_id';
  END IF;

  UPDATE public.global_shipment_cost_entries
     SET metadata = COALESCE(metadata, '{}'::jsonb)
       || jsonb_build_object(
         'ap_bill_id', v_bill_id,
         'ap_bill_issued_at', to_char(now() AT TIME ZONE 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
         'money_kernel_v2', true
       ),
         updated_at = now()
   WHERE id = p_cost_entry_id;

  RETURN v_result
    || jsonb_build_object(
      'cost_entry_id', p_cost_entry_id,
      'source_type', 'shipment_cost',
      'source_id', v_ship.id::text,
      'source_key', 'entry:' || v_entry.id::text,
      'ap_kind', v_ap_kind
    );
END;
$$;
