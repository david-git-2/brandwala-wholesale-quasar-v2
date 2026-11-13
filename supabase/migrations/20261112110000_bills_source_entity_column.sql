-- bills.source_entity on row; drop bill_source_registry.

ALTER TABLE money_kernel.bills
  ADD COLUMN IF NOT EXISTS source_entity text;

UPDATE money_kernel.bills
   SET source_entity = 'public.global_shipments'
 WHERE source_entity IS NULL
   AND source_type = 'shipment_cost';

UPDATE money_kernel.bills
   SET source_entity = 'public.shop_orders'
 WHERE source_entity IS NULL
   AND source_type IN ('shop_order', 'dropship_order', 'wholesale_order');

UPDATE money_kernel.bills
   SET source_entity = 'public.delivery_paper'
 WHERE source_entity IS NULL
   AND source_type = 'delivery_close';

CREATE UNIQUE INDEX IF NOT EXISTS uq_bills_source_entity_key
  ON money_kernel.bills (tenant_id, source_entity, source_id, COALESCE(source_key, ''::text))
  WHERE source_entity IS NOT NULL AND status <> 'voided';

DROP TABLE IF EXISTS money_kernel.bill_source_registry;
DROP FUNCTION IF EXISTS public.rpc_list_bill_source_types();
DROP FUNCTION IF EXISTS money_kernel.validate_bill_source_plug(text, text, text);

CREATE OR REPLACE FUNCTION money_kernel.validate_bill_source_plug(
  p_source_entity text,
  p_source_type   text,
  p_source_id     text,
  p_source_key    text
) RETURNS void
LANGUAGE plpgsql
STABLE
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_entity text := nullif(btrim(p_source_entity), '');
  v_type   text := nullif(btrim(p_source_type), '');
  v_id     text := nullif(btrim(p_source_id), '');
  v_key    text := nullif(btrim(p_source_key), '');
BEGIN
  IF v_entity IS NULL AND v_type IS NULL AND v_id IS NULL AND v_key IS NULL THEN
    RETURN;
  END IF;

  IF v_entity IS NULL AND (v_id IS NOT NULL OR v_key IS NOT NULL) THEN
    RAISE EXCEPTION 'invalid_arguments: source_entity required when source_id or source_key is set';
  END IF;

  IF v_entity IS NOT NULL AND v_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: source_id required when source_entity is set';
  END IF;

  IF v_entity IS NOT NULL
     AND v_entity !~ '^[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*$' THEN
    RAISE EXCEPTION
      'invalid_arguments: source_entity % must be schema.table (e.g. public.global_shipments)',
      v_entity;
  END IF;

  IF v_id IS NOT NULL AND v_id ~ '^\d+$' AND v_id::bigint <= 0 THEN
    RAISE EXCEPTION 'invalid_arguments: source_id must be a positive id';
  END IF;
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

CREATE OR REPLACE FUNCTION money_kernel.fn_bills_guard_financial_spine()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
DECLARE
  v_has_settlements boolean;
BEGIN
  IF OLD.status = 'voided' THEN
    RAISE EXCEPTION 'voided bill % cannot be updated', OLD.id;
  END IF;

  IF OLD.status = 'draft' THEN
    IF NEW.status IS DISTINCT FROM OLD.status
       AND NEW.status NOT IN ('issued', 'voided') THEN
      RAISE EXCEPTION
        'illegal status transition for bill %: draft → %', OLD.id, NEW.status;
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.tenant_id             <> OLD.tenant_id
     OR NEW.invoice_no         <> OLD.invoice_no
     OR NEW.invoice_date       <> OLD.invoice_date
     OR NEW.kind               <> OLD.kind
     OR NEW.parent_bill_id     IS DISTINCT FROM OLD.parent_bill_id
     OR NEW.currency_code      <> OLD.currency_code
     OR NEW.from_profile_id    IS DISTINCT FROM OLD.from_profile_id
     OR NEW.to_profile_id      IS DISTINCT FROM OLD.to_profile_id
     OR NEW.counterparty_profile_id IS DISTINCT FROM OLD.counterparty_profile_id
     OR NEW.counterparty_tenant_id  IS DISTINCT FROM OLD.counterparty_tenant_id
     OR NEW.source_entity      IS DISTINCT FROM OLD.source_entity
     OR NEW.source_type        IS DISTINCT FROM OLD.source_type
     OR NEW.source_id          IS DISTINCT FROM OLD.source_id
     OR NEW.source_key         IS DISTINCT FROM OLD.source_key THEN
    RAISE EXCEPTION
      'issued bill % — structural columns are immutable (void and recreate if needed)', OLD.id;
  END IF;

  IF NEW.total_amount IS DISTINCT FROM OLD.total_amount
     OR NEW.due_date IS DISTINCT FROM OLD.due_date THEN
    SELECT EXISTS (
      SELECT 1 FROM money_kernel.bill_settlements
       WHERE bill_id = OLD.id OR source_bill_id = OLD.id
    ) INTO v_has_settlements;
  ELSE
    v_has_settlements := false;
  END IF;

  IF v_has_settlements THEN
    IF NEW.total_amount <> OLD.total_amount
       OR NEW.due_date IS DISTINCT FROM OLD.due_date THEN
      RAISE EXCEPTION
        'bill % has settlements — total_amount and due_date cannot change', OLD.id;
    END IF;
  END IF;

  IF NEW.status <> OLD.status THEN
    IF NOT (
      (OLD.status = 'issued' AND NEW.status IN ('partial', 'paid', 'written_off', 'voided')) OR
      (OLD.status = 'partial' AND NEW.status IN ('issued', 'paid', 'written_off', 'voided')) OR
      (OLD.status = 'paid' AND NEW.status IN ('partial', 'issued', 'voided')) OR
      (OLD.status = 'written_off' AND NEW.status = 'voided')
    ) THEN
      RAISE EXCEPTION
        'illegal status transition for bill %: % → %', OLD.id, OLD.status, NEW.status;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION money_kernel.fn_bill_events_from_bills()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
DECLARE
  v_event_type text;
  v_payload    jsonb;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_event_type := 'created';
    v_payload := jsonb_build_object(
      'kind',                     NEW.kind,
      'invoice_no',               NEW.invoice_no,
      'status',                   NEW.status,
      'total_amount',             NEW.total_amount,
      'currency_code',            NEW.currency_code,
      'source_entity',            NEW.source_entity,
      'source_type',              NEW.source_type,
      'source_id',                NEW.source_id,
      'source_key',               NEW.source_key,
      'parent_bill_id',           NEW.parent_bill_id,
      'counterparty_profile_id',  NEW.counterparty_profile_id
    );
    INSERT INTO money_kernel.bill_events
      (tenant_id, bill_id, event_type, payload, actor_id)
    VALUES
      (NEW.tenant_id, NEW.id, v_event_type, v_payload, auth.uid());
    INSERT INTO money_kernel.money_outbox
      (tenant_id, event_type, payload, bill_id)
    VALUES
      (NEW.tenant_id, v_event_type, v_payload, NEW.id);
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.status = 'voided' AND OLD.status IS DISTINCT FROM 'voided' THEN
      v_event_type := 'voided';
      v_payload := jsonb_build_object(
        'from_status',        OLD.status,
        'to_status',          'voided',
        'due_before',         OLD.due_amount,
        'written_off_before', OLD.written_off_amount
      );
      INSERT INTO money_kernel.bill_events
        (tenant_id, bill_id, event_type, payload, actor_id)
      VALUES (NEW.tenant_id, NEW.id, v_event_type, v_payload, auth.uid());
      INSERT INTO money_kernel.money_outbox
        (tenant_id, event_type, payload, bill_id)
      VALUES (NEW.tenant_id, v_event_type, v_payload, NEW.id);
      RETURN NEW;
    END IF;

    IF NEW.paid_amount IS DISTINCT FROM OLD.paid_amount THEN
      v_event_type := CASE
        WHEN NEW.paid_amount > OLD.paid_amount THEN 'payment_applied'
        ELSE 'payment_reversed'
      END;
      v_payload := jsonb_build_object(
        'delta',        NEW.paid_amount - OLD.paid_amount,
        'paid_before',  OLD.paid_amount,
        'paid_after',   NEW.paid_amount,
        'due_after',    NEW.due_amount,
        'status_after', NEW.status
      );
      INSERT INTO money_kernel.bill_events
        (tenant_id, bill_id, event_type, payload, actor_id)
      VALUES (NEW.tenant_id, NEW.id, v_event_type, v_payload, auth.uid());
      INSERT INTO money_kernel.money_outbox
        (tenant_id, event_type, payload, bill_id)
      VALUES (NEW.tenant_id, v_event_type, v_payload, NEW.id);
      RETURN NEW;
    END IF;

    IF NEW.written_off_amount IS DISTINCT FROM OLD.written_off_amount THEN
      v_event_type := 'written_off';
      v_payload := jsonb_build_object(
        'delta',             NEW.written_off_amount - OLD.written_off_amount,
        'written_off_total', NEW.written_off_amount,
        'due_after',         NEW.due_amount,
        'status_after',      NEW.status
      );
      INSERT INTO money_kernel.bill_events
        (tenant_id, bill_id, event_type, payload, actor_id)
      VALUES (NEW.tenant_id, NEW.id, v_event_type, v_payload, auth.uid());
      INSERT INTO money_kernel.money_outbox
        (tenant_id, event_type, payload, bill_id)
      VALUES (NEW.tenant_id, v_event_type, v_payload, NEW.id);
      RETURN NEW;
    END IF;

    IF NEW.status <> OLD.status AND NEW.status = 'issued' THEN
      v_event_type := 'issued';
      v_payload := jsonb_build_object(
        'from_status', OLD.status,
        'to_status',   NEW.status
      );
      INSERT INTO money_kernel.bill_events
        (tenant_id, bill_id, event_type, payload, actor_id)
      VALUES (NEW.tenant_id, NEW.id, v_event_type, v_payload, auth.uid());
      INSERT INTO money_kernel.money_outbox
        (tenant_id, event_type, payload, bill_id)
      VALUES (NEW.tenant_id, v_event_type, v_payload, NEW.id);
      RETURN NEW;
    END IF;

    RETURN NEW;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP VIEW IF EXISTS public.v_bills_unified;
CREATE VIEW public.v_bills_unified
  WITH (security_invoker = true)
AS
SELECT
  b.id                                       AS bill_id,
  b.tenant_id,
  b.kind,
  b.status,
  b.invoice_no,
  b.invoice_date,
  b.due_date,
  b.from_profile_id,
  b.to_profile_id,
  b.counterparty_profile_id,
  b.counterparty_tenant_id,
  b.currency_code,
  b.total_amount,
  b.paid_amount,
  b.due_amount,
  b.written_off_amount,
  b.parent_bill_id,
  b.source_entity,
  b.source_type,
  b.source_id,
  b.source_key,
  b.meta,
  b.note,
  b.created_by,
  b.created_at,
  b.updated_at,

  -- Derived helpers (stable semantics — additions allowed, changes not)
  CASE WHEN b.due_amount > 0 THEN true ELSE false END       AS has_due,
  CASE WHEN b.status = 'voided' THEN true ELSE false END    AS is_voided
FROM money_kernel.bills b;

DROP VIEW IF EXISTS public.v_bill_lines_unified;
CREATE VIEW public.v_bill_lines_unified
  WITH (security_invoker = true)
AS
SELECT
  bl.id                         AS line_id,
  bl.bill_id,
  b.tenant_id,
  b.kind                        AS bill_kind,
  b.status                      AS bill_status,
  b.invoice_no,
  b.invoice_date,
  b.due_date,
  b.counterparty_profile_id,
  b.counterparty_tenant_id,
  b.currency_code               AS bill_currency_code,
  b.source_entity,
  b.source_type,
  b.source_id,
  b.source_key,

  bl.line_no,
  bl.item_kind,
  bl.product_id,
  bl.description,
  bl.quantity,
  bl.unit_price,
  bl.line_total,
  bl.shipment_item_id,
  bl.global_stock_id,
  bl.shipment_id,
  bl.meta                       AS line_meta,
  bl.created_at                 AS line_created_at,

  CASE WHEN (bl.meta ? 'assigned_child_tenant_id')
       THEN (bl.meta->>'assigned_child_tenant_id')::bigint
       ELSE NULL END            AS assigned_child_tenant_id,
  CASE WHEN (bl.meta ? 'barcode')
       THEN bl.meta->>'barcode'
       ELSE NULL END            AS barcode,

  b.meta                        AS bill_meta
FROM money_kernel.bill_lines bl
JOIN money_kernel.bills b ON b.id = bl.bill_id;


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
    'source_entity', 'public.global_shipments',
    'source_type', 'shipment_cost',
    'source_id', v_ship.id::text,
    'source_key', v_ap_kind,
    'idempotency_key', 'shipment-' || v_ship.id::text || '-bucket-' || v_ap_kind || '-issue',
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
      'source_entity', 'public.global_shipments',
      'source_type', 'shipment_cost',
      'source_id', v_ship.id::text,
      'source_key', v_ap_kind,
      'ap_kind', v_ap_kind
    );
END;
$$;
