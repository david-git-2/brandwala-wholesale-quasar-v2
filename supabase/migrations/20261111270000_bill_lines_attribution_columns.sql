-- money_kernel.bill_lines: shipment_item_id, global_stock_id, shipment_id (+ RPC/view refresh)

ALTER TABLE money_kernel.bill_lines
  ADD COLUMN IF NOT EXISTS shipment_item_id bigint,
  ADD COLUMN IF NOT EXISTS global_stock_id bigint,
  ADD COLUMN IF NOT EXISTS shipment_id bigint;

ALTER TABLE money_kernel.bill_lines DISABLE TRIGGER trg_bill_lines_guard;

UPDATE money_kernel.bill_lines bl
SET
  shipment_item_id = COALESCE(
    bl.shipment_item_id,
    NULLIF(bl.meta->>'shipment_item_id', '')::bigint
  ),
  global_stock_id = COALESCE(
    bl.global_stock_id,
    NULLIF(bl.meta->>'global_stock_id', '')::bigint,
    NULLIF(bl.meta->'stock_ref'->>'global_stock_id', '')::bigint
  )
WHERE bl.shipment_item_id IS NULL
   OR bl.global_stock_id IS NULL;

UPDATE money_kernel.bill_lines bl
SET shipment_id = gsi.shipment_id
FROM public.global_shipment_items gsi
WHERE bl.shipment_item_id = gsi.id
  AND bl.shipment_id IS NULL;

ALTER TABLE money_kernel.bill_lines ENABLE TRIGGER trg_bill_lines_guard;

CREATE INDEX IF NOT EXISTS ix_bill_lines_shipment_item
  ON money_kernel.bill_lines (shipment_item_id)
  WHERE shipment_item_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_bill_lines_global_stock
  ON money_kernel.bill_lines (global_stock_id)
  WHERE global_stock_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_bill_lines_shipment
  ON money_kernel.bill_lines (tenant_id, shipment_id)
  WHERE shipment_id IS NOT NULL;

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
  v_source_type   text   := p_payload->>'source_type';
  v_source_id     text   := p_payload->>'source_id';
  v_source_key    text   := p_payload->>'source_key';
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

CREATE OR REPLACE FUNCTION public.rpc_issue_bill(
  p_tenant_id bigint,
  p_bill_id   bigint
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_books_rate numeric(15,6);
  v_exchange_rate numeric(15,6);
  v_bill money_kernel.bills;
  v_registry bill_kind_registry;
BEGIN
  PERFORM public.assert_kernel_money_access(p_tenant_id, 'bills');

  SELECT * INTO v_bill FROM money_kernel.bills
    WHERE id = p_bill_id AND tenant_id = p_tenant_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: bill % in tenant %', p_bill_id, p_tenant_id;
  END IF;

  IF v_bill.status = 'issued' THEN
    RETURN jsonb_build_object(
      'bill_id', v_bill.id, 'invoice_no', v_bill.invoice_no,
      'status', 'issued', 'idempotent', true
    );
  END IF;
  IF v_bill.status <> 'draft' THEN
    RAISE EXCEPTION 'invalid_state: cannot issue bill with status %', v_bill.status;
  END IF;
  IF v_bill.from_profile_id IS NULL OR v_bill.to_profile_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: from_profile_id and to_profile_id required before issue';
  END IF;

  SELECT * INTO v_registry FROM money_kernel.bill_kind_registry WHERE kind = v_bill.kind;
  IF NOT v_registry.can_be_issued THEN
    RAISE EXCEPTION 'invalid_state: kind % cannot be issued', v_bill.kind;
  END IF;

  IF EXISTS (
    SELECT 1
      FROM money_kernel.bill_lines bl
      LEFT JOIN public.global_shipment_items gsi ON gsi.id = bl.shipment_item_id
     WHERE bl.bill_id = p_bill_id
       AND bl.item_kind = 'stock'
       AND (
         bl.shipment_item_id IS NULL
         OR bl.global_stock_id IS NULL
         OR (
           bl.shipment_id IS NOT NULL
           AND gsi.id IS NOT NULL
           AND bl.shipment_id IS DISTINCT FROM gsi.shipment_id
         )
       )
  ) THEN
    RAISE EXCEPTION
      'invalid_arguments: stock bill lines require shipment_item_id, global_stock_id, and consistent shipment_id';
  END IF;

  UPDATE money_kernel.bills
     SET status = 'issued', updated_at = now()
   WHERE id = p_bill_id;

  RETURN jsonb_build_object(
    'bill_id', v_bill.id, 'invoice_no', v_bill.invoice_no,
    'status', 'issued', 'idempotent', false
  );
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
      'from_pot_id',            p.from_pot_id,
      'to_pot_id',              p.to_pot_id,
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

CREATE OR REPLACE FUNCTION public.rpc_query_bills(
  p_tenant_id          bigint,
  p_kinds              text[]      DEFAULT NULL,
  p_statuses           text[]      DEFAULT NULL,
  p_source_type        text        DEFAULT NULL,
  p_source_id          text        DEFAULT NULL,
  p_source_key         text        DEFAULT NULL,
  p_counterparty_profile_id  bigint  DEFAULT NULL,
  p_counterparty_tenant_id   bigint  DEFAULT NULL,
  p_parent_bill_id     bigint      DEFAULT NULL,
  p_invoice_no         text        DEFAULT NULL,
  p_from_date          date        DEFAULT NULL,
  p_to_date            date        DEFAULT NULL,
  p_due_before         date        DEFAULT NULL,
  p_has_due            boolean     DEFAULT NULL,
  p_changed_since      timestamptz DEFAULT NULL,
  p_include_voided     boolean     DEFAULT false,
  p_include            text[]      DEFAULT '{summary}',
    -- any subset of: summary | lines | settlements | events
  p_group_by           text        DEFAULT NULL,
    -- NULL (rows) | kind | status | counterparty | month  (groups: no cursor; full agg)
  p_order_by           text        DEFAULT 'invoice_date DESC, id DESC',
  p_limit              int         DEFAULT 50,
  p_cursor             jsonb       DEFAULT NULL
    -- {"k": "...", "id": 123}; null = first page
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_order_mode text;
  v_result     jsonb;
  v_rows       jsonb;
  v_groups     jsonb;
  v_filters    jsonb;
  v_has_more   boolean := false;
  v_next       jsonb := NULL;
  v_cursor_id  bigint;
  v_cursor_k   text;
  v_include_lines        boolean := 'lines'       = ANY(p_include);
  v_include_settlements  boolean := 'settlements' = ANY(p_include);
  v_include_events       boolean := 'events'      = ANY(p_include);
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: tenant_id required';
  END IF;
  IF p_limit < 1 OR p_limit > 500 THEN
    RAISE EXCEPTION 'invalid_arguments: limit must be 1..500';
  END IF;
  IF p_group_by IS NULL
     AND (v_include_lines OR v_include_settlements OR v_include_events)
     AND p_limit > 50 THEN
    RAISE EXCEPTION 'invalid_arguments: heavy includes require limit <= 50';
  END IF;
  IF p_group_by IS NOT NULL AND p_group_by NOT IN ('kind','status','counterparty','month') THEN
    RAISE EXCEPTION
      'invalid_arguments: group_by must be kind/status/counterparty/month, got %', p_group_by;
  END IF;
  IF p_cursor IS NOT NULL AND (p_cursor ? 'id') IS NOT TRUE THEN
    RAISE EXCEPTION 'invalid_arguments: cursor requires id';
  END IF;

  v_order_mode := CASE
    WHEN p_order_by LIKE '%created_at%'   THEN 'created_at'
    WHEN p_order_by LIKE '%updated_at%'   THEN 'updated_at'
    WHEN p_order_by LIKE '%due_date%'     THEN 'due_date'
    WHEN p_order_by LIKE '%total_amount%' THEN 'total_amount'
    WHEN p_order_by LIKE '%due_amount%'   THEN 'due_amount'
    ELSE 'invoice_date'
  END;

  IF p_cursor IS NOT NULL THEN
    v_cursor_id := (p_cursor->>'id')::bigint;
    v_cursor_k  := p_cursor->>'k';
    IF v_cursor_id IS NULL OR v_cursor_k IS NULL THEN
      RAISE EXCEPTION 'invalid_arguments: cursor requires k and id';
    END IF;
  END IF;

  -- Rows mode (cursor keyset)
  IF p_group_by IS NULL THEN
    WITH filtered AS (
      SELECT b.*
      FROM money_kernel.bills b
      WHERE b.tenant_id = p_tenant_id
        AND (p_kinds IS NULL OR b.kind = ANY(p_kinds))
        AND (p_statuses IS NULL OR b.status = ANY(p_statuses))
        AND (p_include_voided OR b.status <> 'voided')
        AND (p_source_type IS NULL OR b.source_type = p_source_type)
        AND (p_source_id IS NULL OR b.source_id = p_source_id)
        AND (p_source_key IS NULL OR b.source_key = p_source_key)
        AND (p_counterparty_profile_id IS NULL OR b.counterparty_profile_id = p_counterparty_profile_id)
        AND (p_counterparty_tenant_id IS NULL OR b.counterparty_tenant_id = p_counterparty_tenant_id)
        AND (p_parent_bill_id IS NULL OR b.parent_bill_id = p_parent_bill_id)
        AND (p_invoice_no IS NULL
             OR b.invoice_no = p_invoice_no
             OR b.invoice_no ILIKE p_invoice_no || '%')
        AND (p_from_date IS NULL OR b.invoice_date >= p_from_date)
        AND (p_to_date IS NULL OR b.invoice_date <= p_to_date)
        AND (p_due_before IS NULL OR (b.due_amount > 0 AND b.due_date <= p_due_before))
        AND (p_has_due IS NULL OR
             (p_has_due = true  AND b.due_amount > 0) OR
             (p_has_due = false AND b.due_amount = 0))
        AND (p_changed_since IS NULL OR b.updated_at > p_changed_since)
        AND (
          p_cursor IS NULL
          OR CASE v_order_mode
               WHEN 'invoice_date' THEN
                 (b.invoice_date, b.id) < (v_cursor_k::date, v_cursor_id)
               WHEN 'created_at' THEN
                 (b.created_at, b.id) < (v_cursor_k::timestamptz, v_cursor_id)
               WHEN 'updated_at' THEN
                 (b.updated_at, b.id) < (v_cursor_k::timestamptz, v_cursor_id)
               WHEN 'due_date' THEN
                 (b.due_date, b.id) < (v_cursor_k::date, v_cursor_id)
               WHEN 'total_amount' THEN
                 (b.total_amount, b.id) < (v_cursor_k::numeric, v_cursor_id)
               WHEN 'due_amount' THEN
                 (b.due_amount, b.id) < (v_cursor_k::numeric, v_cursor_id)
             END
        )
      ORDER BY
        CASE v_order_mode WHEN 'invoice_date'  THEN b.invoice_date  END DESC NULLS LAST,
        CASE v_order_mode WHEN 'created_at'    THEN b.created_at    END DESC NULLS LAST,
        CASE v_order_mode WHEN 'updated_at'    THEN b.updated_at    END DESC NULLS LAST,
        CASE v_order_mode WHEN 'due_date'      THEN b.due_date      END DESC NULLS LAST,
        CASE v_order_mode WHEN 'total_amount'  THEN b.total_amount  END DESC NULLS LAST,
        CASE v_order_mode WHEN 'due_amount'    THEN b.due_amount    END DESC NULLS LAST,
        b.id DESC
      LIMIT p_limit + 1
    ),
    page_rows AS (
      SELECT f.*, row_number() OVER () AS _rn
        FROM filtered f
       LIMIT p_limit
    )
    SELECT
      (SELECT count(*) > p_limit FROM filtered),
      COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'bill_id',                 b.id,
          'tenant_id',               b.tenant_id,
          'kind',                    b.kind,
          'status',                  b.status,
          'invoice_no',              b.invoice_no,
          'invoice_date',            b.invoice_date,
          'due_date',                b.due_date,
          'counterparty_profile_id', b.counterparty_profile_id,
          'counterparty_tenant_id',  b.counterparty_tenant_id,
          'currency_code',           b.currency_code,
          'total_amount',            b.total_amount,
          'paid_amount',             b.paid_amount,
          'due_amount',              b.due_amount,
          'written_off_amount',      b.written_off_amount,
          'parent_bill_id',          b.parent_bill_id,
          'source_type',             b.source_type,
          'source_id',               b.source_id,
          'source_key',              b.source_key,
          'note',                    b.note,
          'meta',                    b.meta,
          'created_at',              b.created_at,
          'updated_at',              b.updated_at,
          'lines', CASE WHEN v_include_lines THEN COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
              'id', bl.id, 'line_no', bl.line_no, 'item_kind', bl.item_kind,
              'product_id', bl.product_id, 'description', bl.description,
              'quantity', bl.quantity, 'unit_price', bl.unit_price,
              'line_total', bl.line_total,
              'shipment_item_id', bl.shipment_item_id,
              'global_stock_id', bl.global_stock_id,
              'shipment_id', bl.shipment_id,
              'meta', bl.meta
            ) ORDER BY bl.line_no)
            FROM money_kernel.bill_lines bl WHERE bl.bill_id = b.id
          ), '[]'::jsonb) ELSE NULL END,
          'settlements', CASE WHEN v_include_settlements THEN COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
              'settlement_id', bs.id,
              'pays_id', bs.pays_id,
              'allocated_amount', bs.allocated_amount,
              'payment_date', p.payment_date,
              'payment_status', p.status
            ) ORDER BY bs.created_at DESC)
            FROM money_kernel.bill_settlements bs
            LEFT JOIN money_kernel.pays p ON p.id = bs.pays_id
            WHERE bs.bill_id = b.id
          ), '[]'::jsonb) ELSE NULL END,
          'events', CASE WHEN v_include_events THEN COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
              'event_id', be.id, 'event_type', be.event_type,
              'payload', be.payload, 'created_at', be.created_at
            ) ORDER BY be.created_at DESC)
            FROM money_kernel.bill_events be WHERE be.bill_id = b.id
          ), '[]'::jsonb) ELSE NULL END
        ) ORDER BY
          CASE v_order_mode WHEN 'invoice_date' THEN b.invoice_date END DESC NULLS LAST,
          CASE v_order_mode WHEN 'created_at'   THEN b.created_at   END DESC NULLS LAST,
          CASE v_order_mode WHEN 'updated_at'   THEN b.updated_at   END DESC NULLS LAST,
          CASE v_order_mode WHEN 'due_date'     THEN b.due_date     END DESC NULLS LAST,
          CASE v_order_mode WHEN 'total_amount' THEN b.total_amount END DESC NULLS LAST,
          CASE v_order_mode WHEN 'due_amount'   THEN b.due_amount   END DESC NULLS LAST,
          b.id DESC
        )
        FROM page_rows b
      ), '[]'::jsonb),
      (
        SELECT CASE v_order_mode
          WHEN 'invoice_date'  THEN jsonb_build_object('k', b.invoice_date::text,  'id', b.id)
          WHEN 'created_at'    THEN jsonb_build_object('k', b.created_at::text,    'id', b.id)
          WHEN 'updated_at'    THEN jsonb_build_object('k', b.updated_at::text,    'id', b.id)
          WHEN 'due_date'      THEN jsonb_build_object('k', b.due_date::text,      'id', b.id)
          WHEN 'total_amount'  THEN jsonb_build_object('k', b.total_amount::text,  'id', b.id)
          WHEN 'due_amount'    THEN jsonb_build_object('k', b.due_amount::text,    'id', b.id)
        END
        FROM page_rows b
        WHERE b._rn = (SELECT max(_rn) FROM page_rows)
      )
    INTO v_has_more, v_rows, v_next;

    IF NOT v_has_more THEN v_next := NULL; END IF;

    v_result := jsonb_build_object(
      'rows',         v_rows,
      'limit',        p_limit,
      'has_more',     v_has_more,
      'next_cursor',  v_next
    );

  -- Group mode: full aggregation (no cursor / no totals envelope)
  ELSE
    WITH filtered AS (
      SELECT b.*
      FROM money_kernel.bills b
      WHERE b.tenant_id = p_tenant_id
        AND (p_kinds IS NULL OR b.kind = ANY(p_kinds))
        AND (p_statuses IS NULL OR b.status = ANY(p_statuses))
        AND (p_include_voided OR b.status <> 'voided')
        AND (p_source_type IS NULL OR b.source_type = p_source_type)
        AND (p_source_id IS NULL OR b.source_id = p_source_id)
        AND (p_source_key IS NULL OR b.source_key = p_source_key)
        AND (p_counterparty_profile_id IS NULL OR b.counterparty_profile_id = p_counterparty_profile_id)
        AND (p_counterparty_tenant_id IS NULL OR b.counterparty_tenant_id = p_counterparty_tenant_id)
        AND (p_parent_bill_id IS NULL OR b.parent_bill_id = p_parent_bill_id)
        AND (p_invoice_no IS NULL
             OR b.invoice_no = p_invoice_no
             OR b.invoice_no ILIKE p_invoice_no || '%')
        AND (p_from_date IS NULL OR b.invoice_date >= p_from_date)
        AND (p_to_date IS NULL OR b.invoice_date <= p_to_date)
        AND (p_due_before IS NULL OR (b.due_amount > 0 AND b.due_date <= p_due_before))
        AND (p_has_due IS NULL OR
             (p_has_due = true  AND b.due_amount > 0) OR
             (p_has_due = false AND b.due_amount = 0))
        AND (p_changed_since IS NULL OR b.updated_at > p_changed_since)
    ),
    grouped AS (
      SELECT
        CASE p_group_by
          WHEN 'kind'         THEN b.kind
          WHEN 'status'       THEN b.status
          WHEN 'counterparty' THEN COALESCE(b.counterparty_profile_id::text,
                                            b.counterparty_tenant_id::text,
                                            '(none)')
          WHEN 'month'        THEN to_char(b.invoice_date, 'YYYY-MM')
        END AS group_key,
        COUNT(*)                                      AS cnt,
        COALESCE(SUM(b.total_amount),       0)::numeric(18,4) AS sum_total,
        COALESCE(SUM(b.paid_amount),        0)::numeric(18,4) AS sum_paid,
        COALESCE(SUM(b.due_amount),         0)::numeric(18,4) AS sum_due,
        COALESCE(SUM(b.written_off_amount), 0)::numeric(18,4) AS sum_written_off
      FROM filtered b
      GROUP BY 1
    )
    SELECT COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'key',              g.group_key,
        'count',            g.cnt,
        'sum_total_amount', g.sum_total,
        'sum_paid_amount',  g.sum_paid,
        'sum_due_amount',   g.sum_due,
        'sum_written_off_amount', g.sum_written_off
      ) ORDER BY g.group_key ASC NULLS LAST)
      FROM grouped g
    ), '[]'::jsonb)
    INTO v_groups;

    v_result := jsonb_build_object(
      'groups',   v_groups,
      'group_by', p_group_by
    );
  END IF;

  v_filters := jsonb_build_object(
    'tenant_id',            p_tenant_id,
    'kinds',                p_kinds,
    'statuses',             p_statuses,
    'source_type',          p_source_type,
    'source_id',            p_source_id,
    'source_key',           p_source_key,
    'counterparty_profile_id', p_counterparty_profile_id,
    'counterparty_tenant_id',  p_counterparty_tenant_id,
    'parent_bill_id',       p_parent_bill_id,
    'invoice_no',           p_invoice_no,
    'from_date',            p_from_date,
    'to_date',              p_to_date,
    'due_before',           p_due_before,
    'has_due',              p_has_due,
    'changed_since',        p_changed_since,
    'include_voided',       p_include_voided,
    'include',              to_jsonb(p_include),
    'group_by',             p_group_by,
    'order_by',             p_order_by,
    'limit',                p_limit,
    'cursor',               p_cursor
  );

  RETURN v_result || jsonb_build_object('echoed_filters', v_filters);
END;
$$;


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
