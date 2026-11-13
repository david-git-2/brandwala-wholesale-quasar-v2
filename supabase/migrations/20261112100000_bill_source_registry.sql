-- bill_source_registry, validate_bill_source_plug, rpc_create_bill source validation, rpc_list_bill_source_types
-- 008b bill_source_registry
CREATE TABLE IF NOT EXISTS money_kernel.bill_source_registry (
  source_type        text PRIMARY KEY,
  entity_table       text NOT NULL,
  entity_id_type     text NOT NULL DEFAULT 'bigint'
    CHECK (entity_id_type IN ('bigint', 'uuid', 'text')),
  source_key_rule    text NOT NULL
    CHECK (source_key_rule IN (
      'none',
      'optional',
      'required_ap_bucket',
      'required_close_action',
      'required_discriminator'
    )),
  allowed_key_values text[] NOT NULL DEFAULT '{}',
  description        text,
  is_active          boolean NOT NULL DEFAULT true,
  created_at         timestamptz NOT NULL DEFAULT now()
);

INSERT INTO money_kernel.bill_source_registry
  (source_type, entity_table, entity_id_type, source_key_rule, allowed_key_values, description)
VALUES
  ('shipment_cost', 'public.global_shipments', 'bigint', 'required_ap_bucket',
    ARRAY['vendor','cargo','local','material','freight','customs','handling','finance','other'],
    'Shipment cost AP — source_id = shipment id; source_key = cost bucket'),
  ('shop_order', 'public.shop_orders', 'bigint', 'optional',
    '{}', 'Shop-channel bills — source_id = shop_orders.id'),
  ('dropship_order', 'public.shop_orders', 'bigint', 'required_discriminator',
    ARRAY['courier','merchant'], 'Dropship bills on a shop order'),
  ('delivery_close', 'public.delivery_paper', 'bigint', 'required_close_action',
    ARRAY['take','condition'], 'Packed-close money outcome on a delivery paper'),
  ('wholesale_order', 'public.shop_orders', 'bigint', 'optional',
    '{}', 'Wholesale compose AR until a dedicated parent table exists')
ON CONFLICT (source_type) DO NOTHING;

CREATE OR REPLACE FUNCTION money_kernel.validate_bill_source_plug(
  p_source_type text,
  p_source_id   text,
  p_source_key  text
) RETURNS void
LANGUAGE plpgsql
STABLE
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_type text := nullif(btrim(p_source_type), '');
  v_id   text := nullif(btrim(p_source_id), '');
  v_key  text := nullif(btrim(p_source_key), '');
  v_reg  money_kernel.bill_source_registry%ROWTYPE;
BEGIN
  IF v_type IS NULL AND v_id IS NULL AND v_key IS NULL THEN
    RETURN;
  END IF;

  IF v_type IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: source_type required when source_id or source_key is set';
  END IF;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: source_id required when source_type is set';
  END IF;

  SELECT * INTO v_reg
    FROM money_kernel.bill_source_registry
   WHERE source_type = v_type AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_arguments: unknown or inactive source_type %', v_type;
  END IF;

  IF v_reg.entity_id_type = 'bigint' THEN
    IF v_id !~ '^\d+$' OR v_id::bigint <= 0 THEN
      RAISE EXCEPTION
        'invalid_arguments: source_id % is not a positive bigint',
        v_id;
    END IF;
  ELSIF v_reg.entity_id_type = 'uuid' THEN
    BEGIN
      PERFORM v_id::uuid;
    EXCEPTION
      WHEN invalid_text_representation THEN
        RAISE EXCEPTION
          'invalid_arguments: source_id % is not a valid uuid',
          v_id;
    END;
  END IF;

  CASE v_reg.source_key_rule
    WHEN 'none' THEN
      IF v_key IS NOT NULL THEN
        RAISE EXCEPTION 'invalid_arguments: source_key must be null for source_type %', v_type;
      END IF;
    WHEN 'optional' THEN
      NULL;
    WHEN 'required_ap_bucket', 'required_close_action', 'required_discriminator' THEN
      IF v_key IS NULL THEN
        RAISE EXCEPTION
          'invalid_arguments: source_key required for source_type % (rule %)',
          v_type, v_reg.source_key_rule;
      END IF;
      IF coalesce(array_length(v_reg.allowed_key_values, 1), 0) > 0
         AND NOT (v_key = ANY (v_reg.allowed_key_values)) THEN
        RAISE EXCEPTION
          'invalid_arguments: source_key % not allowed for source_type %',
          v_key, v_type;
      END IF;
    ELSE
      RAISE EXCEPTION 'invalid_arguments: unknown source_key_rule %', v_reg.source_key_rule;
  END CASE;
END;
$$;

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

  -- Upsert short-circuit (for source-keyed kinds)
  IF v_source_type IS NOT NULL AND v_source_id IS NOT NULL THEN
    SELECT * INTO v_existing FROM money_kernel.bills
      WHERE tenant_id = v_tenant_id
        AND source_type = v_source_type
        AND source_id = v_source_id
        AND COALESCE(source_key, '') = COALESCE(v_source_key, '')
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

  PERFORM money_kernel.validate_bill_source_plug(v_source_type, v_source_id, v_source_key);

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
      source_type, source_id, source_key, idempotency_key,
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
      v_source_type, v_source_id, v_source_key, v_idem,
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
    IF v_bill.id IS NULL AND v_source_type IS NOT NULL AND v_source_id IS NOT NULL THEN
      SELECT * INTO v_bill FROM money_kernel.bills
       WHERE tenant_id = v_tenant_id
         AND source_type = v_source_type
         AND source_id = v_source_id
         AND COALESCE(source_key, '') = COALESCE(v_source_key, '')
         AND status <> 'voided';
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

CREATE OR REPLACE FUNCTION public.rpc_list_bill_source_types()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = money_kernel, public, pg_temp
AS $$
BEGIN
  RETURN jsonb_build_object(
    'source_types', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'source_type',        r.source_type,
        'entity_table',       r.entity_table,
        'entity_id_type',     r.entity_id_type,
        'source_key_rule',    r.source_key_rule,
        'allowed_key_values', to_jsonb(r.allowed_key_values),
        'description',        r.description,
        'is_active',          r.is_active
      ) ORDER BY r.source_type)
      FROM money_kernel.bill_source_registry r
      WHERE r.is_active = true
    ), '[]'::jsonb),
    'count', (SELECT COUNT(*) FROM money_kernel.bill_source_registry WHERE is_active = true)
  );
END;
$$;

ALTER TABLE money_kernel.bill_source_registry ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS mk_bill_source_registry_select ON money_kernel.bill_source_registry;
CREATE POLICY mk_bill_source_registry_select ON money_kernel.bill_source_registry
  FOR SELECT TO authenticated
  USING (true);

REVOKE EXECUTE ON FUNCTION public.rpc_list_bill_source_types() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_list_bill_source_types() TO authenticated, service_role;
