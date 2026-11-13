-- Shipment cost AP Option A: P0 kernel + P1 buckets/adapters

ALTER TABLE public.global_shipments
  ADD COLUMN IF NOT EXISTS buckets jsonb NOT NULL DEFAULT '[]'::jsonb;

CREATE OR REPLACE FUNCTION public.rpc_create_bill(p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_books_rate numeric(15,6);
  v_exchange_rate numeric(15,6);
  v_tenant_id     bigint := (p_payload->>'tenant_id')::bigint;
  v_kind          text   := p_payload->>'kind';
  v_idem          text   := p_payload->>'idempotency_key';
  v_source_entity text   := nullif(btrim(p_payload->>'source_entity'), '');
  v_source_type   text   := nullif(btrim(p_payload->>'source_type'), '');
  v_source_id     text   := nullif(btrim(p_payload->>'source_id'), '');
  v_source_key    text   := nullif(btrim(p_payload->>'source_key'), '');
  v_bill money_kernel.bills;
  v_existing      bills;
  v_registry      bill_kind_registry;
  v_invoice_no    text;
  v_total         numeric(18,4) := 0;
  v_lines         jsonb;
  v_line          jsonb;
  v_line_no       int := 0;
  v_line_total    numeric(18,4);
  v_qty           numeric(18,4);
  v_price         numeric(18,4);
  v_meta          jsonb := COALESCE(p_payload->'meta', '{}'::jsonb);
  v_required_key  text;
BEGIN
  -- Basic validation
  IF v_tenant_id IS NULL THEN RAISE EXCEPTION 'invalid_arguments: tenant_id required'; END IF;
  PERFORM public.assert_kernel_money_access(v_tenant_id, 'bills');
  IF v_kind IS NULL THEN RAISE EXCEPTION 'invalid_arguments: kind required'; END IF;

  -- Registry lookup
  SELECT * INTO v_registry FROM money_kernel.bill_kind_registry
    WHERE kind = v_kind AND is_active = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_arguments: unknown or inactive kind %', v_kind;
  END IF;

  -- required_meta check
  FOREACH v_required_key IN ARRAY v_registry.required_meta LOOP
    IF NOT (v_meta ? v_required_key) THEN
      RAISE EXCEPTION
        'invalid_arguments: kind % requires meta key %', v_kind, v_required_key;
    END IF;
  END LOOP;

  -- Idempotency short-circuit
  IF v_idem IS NOT NULL THEN
    SELECT * INTO v_existing FROM money_kernel.bills
      WHERE tenant_id = v_tenant_id AND idempotency_key = v_idem
        AND status <> 'voided';
    IF FOUND THEN
      RETURN jsonb_build_object(
        'bill_id', v_existing.id, 'invoice_no', v_existing.invoice_no,
        'status', v_existing.status, 'kind', v_existing.kind,
        'total_amount', v_existing.total_amount, 'due_amount', v_existing.due_amount,
        'idempotent', true
      );
    END IF;
  END IF;

  -- Upsert short-circuit (source_entity or source_type + source_id + source_key)
  IF v_source_id IS NOT NULL
     AND (v_source_entity IS NOT NULL OR v_source_type IS NOT NULL) THEN
    SELECT * INTO v_existing FROM money_kernel.bills
      WHERE tenant_id = v_tenant_id
        AND source_id = v_source_id
        AND COALESCE(source_key, '') = COALESCE(v_source_key, '')
        AND status <> 'voided'
        AND (
          (v_source_entity IS NOT NULL AND source_entity IS NOT DISTINCT FROM v_source_entity)
          OR (v_source_entity IS NULL AND source_type IS NOT DISTINCT FROM v_source_type)
        );
    IF FOUND THEN
      RETURN jsonb_build_object(
        'bill_id', v_existing.id, 'invoice_no', v_existing.invoice_no,
        'status', v_existing.status, 'kind', v_existing.kind,
        'total_amount', v_existing.total_amount, 'due_amount', v_existing.due_amount,
        'idempotent', true
      );
    END IF;
  END IF;

  -- Compute total from lines
  v_lines := COALESCE(p_payload->'lines', '[]'::jsonb);
  IF jsonb_array_length(v_lines) = 0 THEN
    RAISE EXCEPTION 'invalid_arguments: lines required';
  END IF;
  FOR v_line IN SELECT * FROM jsonb_array_elements(v_lines) LOOP
    v_qty   := COALESCE((v_line->>'quantity')::numeric,   1);
    v_price := COALESCE((v_line->>'unit_price')::numeric, 0);
    v_line_total := COALESCE((v_line->>'line_total')::numeric, v_qty * v_price);
    v_total := v_total + v_line_total;
  END LOOP;

  IF v_kind = 'credit_note' THEN
    IF (p_payload->>'parent_bill_id') IS NULL THEN
      RAISE EXCEPTION 'invalid_arguments: credit_note requires parent_bill_id';
    END IF;
    SELECT * INTO v_existing FROM money_kernel.bills
     WHERE id = (p_payload->>'parent_bill_id')::bigint
       AND tenant_id = v_tenant_id;
    IF v_existing.id IS NULL THEN
      RAISE EXCEPTION 'not_found: parent_bill_id %', (p_payload->>'parent_bill_id')::bigint;
    END IF;
    IF v_existing.status NOT IN ('issued','partial','paid','written_off') THEN
      RAISE EXCEPTION
        'invalid_state: credit_note parent must be issued/partial/paid/written_off, got %',
        v_existing.status;
    END IF;
    -- Parties = swap of parent (payer/payee reversed). Omit both → inherit swap.
    IF (p_payload->>'from_profile_id') IS NULL
       <> ((p_payload->>'to_profile_id') IS NULL) THEN
      RAISE EXCEPTION 'invalid_arguments: credit_note from/to must both be set or both omitted';
    END IF;
    IF (p_payload->>'from_profile_id') IS NOT NULL AND (
         (p_payload->>'from_profile_id')::bigint IS DISTINCT FROM v_existing.to_profile_id
      OR (p_payload->>'to_profile_id')::bigint IS DISTINCT FROM v_existing.from_profile_id
    ) THEN
      RAISE EXCEPTION
        'invalid_arguments: credit_note from/to must be swap of parent (from=parent.to, to=parent.from)';
    END IF;
    -- Only validate when caller sends currency; omitted → inherit parent on INSERT
    IF (p_payload->>'currency_code') IS NOT NULL
       AND (p_payload->>'currency_code') <> v_existing.currency_code THEN
      RAISE EXCEPTION 'invalid_arguments: credit_note currency must match parent';
    END IF;
  END IF;

  PERFORM money_kernel.validate_bill_source_plug(
    v_source_entity, v_source_type, v_source_id, v_source_key
  );

  -- Allocate invoice_no atomically
  v_invoice_no := public.rpc_allocate_invoice_no(v_tenant_id, v_kind);

  -- Insert bill
  BEGIN
    INSERT INTO money_kernel.bills (
      tenant_id, kind, status,
      invoice_no, invoice_date, due_date,
      from_profile_id, to_profile_id,
      counterparty_profile_id, counterparty_tenant_id,
      currency_code, total_amount, paid_amount, due_amount, written_off_amount,
      parent_bill_id,
      source_entity, source_type, source_id, source_key, idempotency_key,
      meta, note, created_by
    ) VALUES (
      v_tenant_id, v_kind, 'draft',  -- always draft; issue via auto_issue / rpc_issue_bill
      v_invoice_no,
      COALESCE((p_payload->>'invoice_date')::date, CURRENT_DATE),
      (p_payload->>'due_date')::date,
      CASE WHEN v_kind = 'credit_note' AND (p_payload->>'from_profile_id') IS NULL
           THEN v_existing.to_profile_id
           ELSE (p_payload->>'from_profile_id')::bigint END,
      CASE WHEN v_kind = 'credit_note' AND (p_payload->>'to_profile_id') IS NULL
           THEN v_existing.from_profile_id
           ELSE (p_payload->>'to_profile_id')::bigint END,
      (p_payload->>'counterparty_profile_id')::bigint,
      (p_payload->>'counterparty_tenant_id')::bigint,
      CASE WHEN v_kind = 'credit_note' THEN v_existing.currency_code
           ELSE COALESCE(p_payload->>'currency_code', 'BDT') END,
      v_total, 0, v_total, 0,
      (p_payload->>'parent_bill_id')::bigint,
      v_source_entity, v_source_type, v_source_id, v_source_key, v_idem,
      v_meta,
      p_payload->>'note',
      auth.uid()
    ) RETURNING * INTO v_bill;
  EXCEPTION WHEN unique_violation THEN
    -- Concurrent create with same idempotency_key or source key
    IF v_idem IS NOT NULL THEN
      SELECT * INTO v_bill FROM money_kernel.bills
       WHERE tenant_id = v_tenant_id AND idempotency_key = v_idem AND status <> 'voided';
    END IF;
    IF v_bill.id IS NULL AND v_source_id IS NOT NULL
       AND (v_source_entity IS NOT NULL OR v_source_type IS NOT NULL) THEN
      SELECT * INTO v_bill FROM money_kernel.bills
       WHERE tenant_id = v_tenant_id
         AND source_id = v_source_id
         AND COALESCE(source_key, '') = COALESCE(v_source_key, '')
         AND status <> 'voided'
         AND (
           (v_source_entity IS NOT NULL AND source_entity IS NOT DISTINCT FROM v_source_entity)
           OR (v_source_entity IS NULL AND source_type IS NOT DISTINCT FROM v_source_type)
         );
    END IF;
    IF v_bill.id IS NULL THEN RAISE; END IF;
    RETURN jsonb_build_object(
      'bill_id', v_bill.id, 'invoice_no', v_bill.invoice_no,
      'status', v_bill.status, 'kind', v_bill.kind,
      'total_amount', v_bill.total_amount, 'due_amount', v_bill.due_amount,
      'idempotent', true
    );
  END;

  -- Insert lines in one statement
  INSERT INTO money_kernel.bill_lines (
    tenant_id, bill_id, line_no, item_kind, product_id,
    description, quantity, unit_price, line_total,
    shipment_item_id, global_stock_id, shipment_id, meta
  )
  SELECT
    v_tenant_id,
    v_bill.id,
    a.ord::int,
    COALESCE(a.elem->>'item_kind', 'stock'),
    (a.elem->>'product_id')::bigint,
    a.elem->>'description',
    COALESCE((a.elem->>'quantity')::numeric, 1),
    COALESCE((a.elem->>'unit_price')::numeric, 0),
    COALESCE(
      (a.elem->>'line_total')::numeric,
      COALESCE((a.elem->>'quantity')::numeric, 1)
        * COALESCE((a.elem->>'unit_price')::numeric, 0)
    ),
    COALESCE(
      NULLIF(a.elem->>'shipment_item_id', '')::bigint,
      NULLIF(a.elem->'meta'->>'shipment_item_id', '')::bigint
    ),
    COALESCE(
      NULLIF(a.elem->>'global_stock_id', '')::bigint,
      NULLIF(a.elem->'meta'->>'global_stock_id', '')::bigint,
      NULLIF(a.elem->'meta'->'stock_ref'->>'global_stock_id', '')::bigint
    ),
    COALESCE(
      NULLIF(a.elem->>'shipment_id', '')::bigint,
      NULLIF(a.elem->'meta'->>'shipment_id', '')::bigint,
      gsi.shipment_id
    ),
    COALESCE(a.elem->'meta', '{}'::jsonb)
  FROM jsonb_array_elements(v_lines) WITH ORDINALITY AS a(elem, ord)
  LEFT JOIN public.global_shipment_items gsi
    ON gsi.id = COALESCE(
      NULLIF(a.elem->>'shipment_item_id', '')::bigint,
      NULLIF(a.elem->'meta'->>'shipment_item_id', '')::bigint
    );

  -- Optional auto-issue
  IF (p_payload->>'auto_issue')::boolean = true AND v_registry.can_be_issued THEN
    PERFORM public.rpc_issue_bill(v_tenant_id, v_bill.id);
    SELECT * INTO v_bill FROM money_kernel.bills WHERE id = v_bill.id;
  END IF;

  RETURN jsonb_build_object(
    'bill_id', v_bill.id, 'invoice_no', v_bill.invoice_no,
    'status', v_bill.status, 'kind', v_bill.kind,
    'total_amount', v_bill.total_amount, 'due_amount', v_bill.due_amount,
    'idempotent', false
  );
END;
$$;
CREATE OR REPLACE FUNCTION public.rpc_update_draft_bill_v2(
  p_tenant_id bigint,
  p_bill_id   bigint,
  p_payload   jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_bill          money_kernel.bills;
  v_lines         jsonb;
  v_line          jsonb;
  v_total         numeric(18,4) := 0;
  v_line_total    numeric(18,4);
  v_qty           numeric(18,4);
  v_price         numeric(18,4);
  v_meta          jsonb;
  v_registry      bill_kind_registry;
BEGIN
  IF p_tenant_id IS NULL OR p_bill_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: tenant_id and bill_id required';
  END IF;
  PERFORM public.assert_kernel_money_access(p_tenant_id, 'bills');

  SELECT * INTO v_bill FROM money_kernel.bills
    WHERE id = p_bill_id AND tenant_id = p_tenant_id
    FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: bill % in tenant %', p_bill_id, p_tenant_id;
  END IF;
  IF v_bill.status <> 'draft' THEN
    RAISE EXCEPTION 'invalid_state: only draft bills can be updated (got %)', v_bill.status;
  END IF;

  SELECT * INTO v_registry FROM money_kernel.bill_kind_registry
    WHERE kind = v_bill.kind AND is_active = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_state: inactive kind %', v_bill.kind;
  END IF;

  v_lines := COALESCE(p_payload->'lines', '[]'::jsonb);
  IF jsonb_array_length(v_lines) = 0 THEN
    RAISE EXCEPTION 'invalid_arguments: lines required';
  END IF;
  FOR v_line IN SELECT * FROM jsonb_array_elements(v_lines) LOOP
    v_qty   := COALESCE((v_line->>'quantity')::numeric, 1);
    v_price := COALESCE((v_line->>'unit_price')::numeric, 0);
    v_line_total := COALESCE((v_line->>'line_total')::numeric, v_qty * v_price);
    v_total := v_total + v_line_total;
  END LOOP;

  v_meta := COALESCE(v_bill.meta, '{}'::jsonb) || COALESCE(p_payload->'meta', '{}'::jsonb);

  UPDATE money_kernel.bills
     SET invoice_date = COALESCE((p_payload->>'invoice_date')::date, invoice_date),
         due_date     = COALESCE((p_payload->>'due_date')::date, due_date),
         note         = COALESCE(p_payload->>'note', note),
         currency_code = COALESCE(NULLIF(p_payload->>'currency_code', ''), currency_code),
         from_profile_id = COALESCE((p_payload->>'from_profile_id')::bigint, from_profile_id),
         to_profile_id   = COALESCE((p_payload->>'to_profile_id')::bigint, to_profile_id),
         counterparty_profile_id = COALESCE(
           (p_payload->>'counterparty_profile_id')::bigint,
           counterparty_profile_id
         ),
         total_amount = v_total,
         due_amount   = v_total - paid_amount - written_off_amount,
         meta         = v_meta,
         updated_at   = now()
   WHERE id = p_bill_id;

  DELETE FROM money_kernel.bill_lines
   WHERE tenant_id = p_tenant_id AND bill_id = p_bill_id;

  INSERT INTO money_kernel.bill_lines (
    tenant_id, bill_id, line_no, item_kind, product_id,
    description, quantity, unit_price, line_total,
    shipment_item_id, global_stock_id, shipment_id, meta
  )
  SELECT
    p_tenant_id,
    p_bill_id,
    a.ord::int,
    COALESCE(a.elem->>'item_kind', 'charge'),
    (a.elem->>'product_id')::bigint,
    a.elem->>'description',
    COALESCE((a.elem->>'quantity')::numeric, 1),
    COALESCE((a.elem->>'unit_price')::numeric, 0),
    COALESCE(
      (a.elem->>'line_total')::numeric,
      COALESCE((a.elem->>'quantity')::numeric, 1)
        * COALESCE((a.elem->>'unit_price')::numeric, 0)
    ),
    COALESCE(
      NULLIF(a.elem->>'shipment_item_id', '')::bigint,
      NULLIF(a.elem->'meta'->>'shipment_item_id', '')::bigint
    ),
    COALESCE(
      NULLIF(a.elem->>'global_stock_id', '')::bigint,
      NULLIF(a.elem->'meta'->>'global_stock_id', '')::bigint,
      NULLIF(a.elem->'meta'->'stock_ref'->>'global_stock_id', '')::bigint
    ),
    COALESCE(
      NULLIF(a.elem->>'shipment_id', '')::bigint,
      NULLIF(a.elem->'meta'->>'shipment_id', '')::bigint,
      gsi.shipment_id
    ),
    COALESCE(a.elem->'meta', '{}'::jsonb)
  FROM jsonb_array_elements(v_lines) WITH ORDINALITY AS a(elem, ord)
  LEFT JOIN public.global_shipment_items gsi
    ON gsi.id = COALESCE(
      NULLIF(a.elem->>'shipment_item_id', '')::bigint,
      NULLIF(a.elem->'meta'->>'shipment_item_id', '')::bigint
    );

  SELECT * INTO v_bill FROM money_kernel.bills WHERE id = p_bill_id;

  RETURN jsonb_build_object(
    'bill_id', v_bill.id,
    'invoice_no', v_bill.invoice_no,
    'status', v_bill.status,
    'kind', v_bill.kind,
    'total_amount', v_bill.total_amount,
    'due_amount', v_bill.due_amount,
    'updated', true
  );
END;
$$;

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
BEGIN
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
       AND b.source_type = 'shipment_cost'
       AND b.source_id = p_shipment_id::text
  ) INTO v_found;

  RETURN v_found;
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

  RETURN v_result || jsonb_build_object('shipment_id', p_shipment_id, 'bill_id', p_bill_id);
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
  v_bill money_kernel.bills;
  v_result jsonb;
BEGIN
  PERFORM public._shipment_money_advisory_lock(p_shipment_id);

  SELECT tenant_id INTO v_parent FROM public.global_shipments WHERE id = p_shipment_id FOR UPDATE;
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
   WHERE id = p_bill_id AND tenant_id = v_parent;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'bill not found';
  END IF;
  IF v_bill.status <> 'draft' THEN
    RAISE EXCEPTION 'only draft bills can be deleted (voided)';
  END IF;

  v_result := public.rpc_void_bill(v_parent, p_bill_id);
  PERFORM public._shipment_buckets_remove(p_shipment_id, p_bill_id);

  RETURN v_result || jsonb_build_object('shipment_id', p_shipment_id, 'bill_id', p_bill_id);
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

  perform public.ensure_global_shipment_cost_entries_from_header(p_shipment_id);

  v_sid := p_shipment_id::text;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', ce.id,
        'shipment_id', ce.shipment_id,
        'cost_bucket', ce.cost_bucket,
        'cost_component', ce.cost_component,
        'is_capitalizable', ce.is_capitalizable,
        'description', ce.description,
        'amount', ce.amount,
        'currency_id', ce.currency_id,
        'metadata', ce.metadata,
        'section_id', ce.section_id
      )
      order by ce.cost_bucket, ce.cost_component, ce.id
    ),
    '[]'::jsonb
  )
  into v_cost_entries
  from public.global_shipment_cost_entries ce
  where ce.shipment_id = p_shipment_id;

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
        'net_balances', v_elem->'net_balances'
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

-- Procurement: lock shipment costs → issue kernel AP drafts on buckets index.

-- Procurement: lock shipment costs → sync AP → issue AP (calls bills_pays adapters).

CREATE OR REPLACE FUNCTION public.lock_global_shipment_costs(p_shipment_id bigint)
RETURNS public.global_shipments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_ship public.global_shipments%rowtype;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_books_tenant(v_ship.tenant_id) then
    raise exception 'not allowed';
  end if;

  if v_ship.status not in ('in_transit', 'received') then
    raise exception 'Set shipment to in transit or received before locking costs';
  end if;

  if not public.global_shipment_stock_is_posted(v_ship) then
    raise exception 'shipment stock is not posted; receive before locking costs';
  end if;

  if public.global_shipment_costs_are_locked(v_ship) then
    raise exception 'shipment costs are already locked';
  end if;

  perform set_config('app.allow_costs_lock', '1', true);

  update public.global_shipments
  set costs_locked = true,
      costs_locked_at = now(),
      costs_locked_by = auth.uid(),
      updated_at = now()
  where id = p_shipment_id
  returning * into v_ship;

  perform public.issue_shipment_ap_drafts_v2(p_shipment_id);

  return v_ship;
end;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_update_draft_bill_v2(bigint, bigint, jsonb) TO authenticated, service_role;
