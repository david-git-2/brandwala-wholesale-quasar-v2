-- Money spine v2 read RPCs + views

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
      'from_lot_id',            p.from_lot_id,
      'to_lot_id',              p.to_lot_id,
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
          'source_entity',           b.source_entity,
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

CREATE OR REPLACE FUNCTION public.rpc_get_pot_balance(
  p_tenant_id    bigint,
  p_pot_id       bigint  DEFAULT NULL,
  p_entity_type  text    DEFAULT NULL,
  p_entity_id    bigint  DEFAULT NULL,
  p_currency     text    DEFAULT 'BDT'
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_pot     money_kernel.cashbook_lots;
  v_account cashbook_accounts;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: tenant_id required';
  END IF;

  IF p_pot_id IS NOT NULL THEN
    -- Lookup by pot id
    SELECT pp.* INTO v_pot
      FROM money_kernel.cashbook_lots pp
      WHERE pp.id = p_pot_id AND pp.tenant_id = p_tenant_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'not_found: pot % in tenant %', p_pot_id, p_tenant_id;
    END IF;

    -- Resolve entity for the response
    SELECT a.* INTO v_account
      FROM money_kernel.cashbook_points pt
      JOIN money_kernel.cashbook_accounts a ON a.id = pt.cashbook_account_id
     WHERE pt.id = v_pot.cashbook_point_id;

  ELSIF p_entity_type IS NOT NULL AND p_entity_id IS NOT NULL THEN
    -- Lookup by entity + currency (uses default pot pointer first)
    SELECT pp.* INTO v_pot
      FROM money_kernel.cashbook_accounts a
      LEFT JOIN money_kernel.cashbook_lots pp_default
        ON pp_default.id = a.default_cashbook_lot_id
      JOIN money_kernel.cashbook_points pt ON pt.cashbook_account_id = a.id
      JOIN money_kernel.cashbook_lots pp ON pp.cashbook_point_id = pt.id
     WHERE a.tenant_id = p_tenant_id
       AND a.entity_type = p_entity_type
       AND a.entity_id = p_entity_id
       AND pp.currency_code = p_currency
     ORDER BY (a.default_cashbook_lot_id = pp.id) DESC, pp.id ASC
     LIMIT 1;

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'not_found: no % pot for entity %/%', p_currency, p_entity_type, p_entity_id;
    END IF;

    SELECT * INTO v_account FROM money_kernel.cashbook_accounts
      WHERE tenant_id = p_tenant_id AND entity_type = p_entity_type
        AND entity_id = p_entity_id;

  ELSE
    RAISE EXCEPTION
      'invalid_arguments: must pass pot_id OR (entity_type AND entity_id)';
  END IF;

  RETURN jsonb_build_object(
    'pot_id',          v_pot.id,
    'tenant_id',       v_pot.tenant_id,
    'cashbook_point_id', v_pot.cashbook_point_id,
    'entity_type',     v_account.entity_type,
    'entity_id',       v_account.entity_id,
    'currency_code',   v_pot.currency_code,
    'amount',          v_pot.amount,
    'updated_at',      v_pot.updated_at,
    'echoed_filters',  jsonb_build_object(
      'pot_id',      p_pot_id,
      'entity_type', p_entity_type,
      'entity_id',   p_entity_id,
      'currency',    p_currency
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_get_pot_balances(
  p_tenant_id    bigint,
  p_entity_type  text    DEFAULT 'profile',
  p_entity_ids   bigint[] DEFAULT NULL,
  p_currencies   text[]  DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_rows jsonb;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: tenant_id required';
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'pot_id',        pp.id,
    'entity_type',   a.entity_type,
    'entity_id',     a.entity_id,
    'currency_code', pp.currency_code,
    'amount',        pp.amount,
    'updated_at',    pp.updated_at
  ) ORDER BY a.entity_id, pp.currency_code), '[]'::jsonb)
  INTO v_rows
  FROM money_kernel.cashbook_lots pp
  JOIN money_kernel.cashbook_points   pt ON pt.id = pp.cashbook_point_id
  JOIN money_kernel.cashbook_accounts a  ON a.id  = pt.cashbook_account_id
  WHERE pp.tenant_id = p_tenant_id
    AND a.entity_type = p_entity_type
    AND (p_entity_ids IS NULL OR a.entity_id = ANY(p_entity_ids))
    AND (p_currencies IS NULL OR pp.currency_code = ANY(p_currencies));

  RETURN jsonb_build_object(
    'rows',           v_rows,
    'count',          jsonb_array_length(v_rows),
    'echoed_filters', jsonb_build_object(
      'tenant_id',   p_tenant_id,
      'entity_type', p_entity_type,
      'entity_ids',  p_entity_ids,
      'currencies',  p_currencies
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_profile_transactions(
  p_tenant_id        bigint,
  p_profile_id       bigint,
  p_from_date        date    DEFAULT NULL,
  p_to_date          date    DEFAULT NULL,
  p_kind             text    DEFAULT NULL,
  p_currency_code    text    DEFAULT NULL,
  p_pot_id           bigint  DEFAULT NULL,
  p_bill_id          bigint  DEFAULT NULL,
  p_include_voided   boolean DEFAULT false,
  p_limit            int     DEFAULT 20,
  p_cursor           jsonb   DEFAULT NULL
    -- {"created_at":"...","pays_id":N,"direction":"in"|"out"}
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_result jsonb;
  v_c_at   timestamptz;
  v_c_pays bigint;
  v_c_dir  text;
BEGIN
  IF p_tenant_id IS NULL OR p_profile_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: tenant_id and profile_id required';
  END IF;
  IF p_limit < 1 OR p_limit > 500 THEN
    RAISE EXCEPTION 'invalid_arguments: limit must be 1..500';
  END IF;
  IF p_from_date IS NOT NULL AND p_to_date IS NOT NULL AND p_from_date > p_to_date THEN
    RAISE EXCEPTION 'invalid_arguments: from_date must be <= to_date';
  END IF;
  IF p_cursor IS NOT NULL THEN
    v_c_at   := (p_cursor->>'created_at')::timestamptz;
    v_c_pays := (p_cursor->>'pays_id')::bigint;
    v_c_dir  := p_cursor->>'direction';
    IF v_c_at IS NULL OR v_c_pays IS NULL OR v_c_dir IS NULL THEN
      RAISE EXCEPTION 'invalid_arguments: cursor requires created_at, pays_id, direction';
    END IF;
  END IF;

  PERFORM public.money_kernel_assert_profile_in_tenant(p_tenant_id, p_profile_id);

  WITH my_pots AS (
    SELECT pp.id AS pot_id, pp.currency_code, pp.amount AS current_balance
      FROM money_kernel.cashbook_lots pp
      JOIN money_kernel.cashbook_points    pt ON pt.id = pp.cashbook_point_id
      JOIN money_kernel.cashbook_accounts  a  ON a.id  = pt.cashbook_account_id
     WHERE a.tenant_id = p_tenant_id
       AND a.entity_type = 'profile'
       AND a.entity_id = p_profile_id
       AND (p_pot_id IS NULL OR pp.id = p_pot_id)
       AND (p_currency_code IS NULL OR pp.currency_code = p_currency_code)
  ),
  legs AS (
    SELECT p.id AS pays_id, p.kind, p.payment_date, p.created_at,
           mp.pot_id, mp.currency_code AS pot_currency, mp.current_balance,
           p.books_amount, p.exchange_rate, p.refs, p.meta, p.status,
           'out'::text AS direction,
           p.amount           AS leg_amount,
           -p.amount          AS signed_amount,
           CASE WHEN p.status = 'posted' THEN -p.amount ELSE 0 END AS signed_for_balance,
           p.to_lot_id        AS other_pot_id
      FROM money_kernel.pays p
      JOIN my_pots mp ON mp.pot_id = p.from_lot_id
     WHERE p.tenant_id = p_tenant_id
       AND p.from_lot_id IS NOT NULL
       AND (p_include_voided OR p.status = 'posted')
       AND (p_from_date IS NULL OR p.payment_date >= p_from_date)
       AND (p_to_date   IS NULL OR p.payment_date <= p_to_date)
       AND (p_kind      IS NULL OR p.kind = p_kind)
       AND (p_bill_id   IS NULL OR EXISTS (
         SELECT 1 FROM money_kernel.bill_settlements bs
          WHERE bs.pays_id = p.id AND bs.bill_id = p_bill_id))

    UNION ALL

    SELECT p.id, p.kind, p.payment_date, p.created_at,
           mp.pot_id, mp.currency_code, mp.current_balance,
           p.books_amount, p.exchange_rate, p.refs, p.meta, p.status,
           'in'::text,
           CASE WHEN p.kind = 'transfer' THEN p.amount * p.exchange_rate ELSE p.amount END,
           CASE WHEN p.kind = 'transfer' THEN p.amount * p.exchange_rate ELSE p.amount END,
           CASE WHEN p.status = 'posted'
                THEN (CASE WHEN p.kind = 'transfer'
                           THEN p.amount * p.exchange_rate ELSE p.amount END)
                ELSE 0 END,
           p.from_lot_id
      FROM money_kernel.pays p
      JOIN my_pots mp ON mp.pot_id = p.to_lot_id
     WHERE p.tenant_id = p_tenant_id
       AND p.to_lot_id IS NOT NULL
       AND (p_include_voided OR p.status = 'posted')
       AND (p_from_date IS NULL OR p.payment_date >= p_from_date)
       AND (p_to_date   IS NULL OR p.payment_date <= p_to_date)
       AND (p_kind      IS NULL OR p.kind = p_kind)
       AND (p_bill_id   IS NULL OR EXISTS (
         SELECT 1 FROM money_kernel.bill_settlements bs
          WHERE bs.pays_id = p.id AND bs.bill_id = p_bill_id))
  ),
  with_balance AS MATERIALIZED (
    SELECT l.*,
           l.current_balance - COALESCE(
             SUM(l.signed_for_balance) OVER (
               PARTITION BY l.pot_id
               ORDER BY l.created_at DESC, l.pays_id DESC, l.direction DESC
               ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
             ), 0
           ) AS balance_after
      FROM legs l
  ),
  filtered AS (
    SELECT *
      FROM with_balance wb
     WHERE p_cursor IS NULL
        OR (wb.created_at, wb.pays_id, wb.direction)
             < (v_c_at, v_c_pays, v_c_dir)
     ORDER BY created_at DESC, pays_id DESC, direction DESC
     LIMIT p_limit + 1
  ),
  page_rows AS (
    SELECT f.*, row_number() OVER () AS _rn
      FROM filtered f
     LIMIT p_limit
  )
  SELECT jsonb_build_object(
    'profile_id',  p_profile_id,
    'limit',       p_limit,
    'has_more',    (SELECT count(*) > p_limit FROM filtered),
    'next_cursor', CASE
      WHEN (SELECT count(*) > p_limit FROM filtered) THEN (
        SELECT jsonb_build_object(
          'created_at', b.created_at,
          'pays_id',    b.pays_id,
          'direction',  b.direction
        )
        FROM page_rows b
        WHERE b._rn = (SELECT max(_rn) FROM page_rows)
      )
      ELSE NULL
    END,
    'balances', jsonb_build_object(
      'by_pot', COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'pot_id', pot_id, 'currency', currency_code, 'balance', current_balance
        ) ORDER BY pot_id)
        FROM my_pots
      ), '[]'::jsonb),
      'by_currency', COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'currency', currency_code, 'balance', SUM(current_balance)
        ) ORDER BY currency_code)
        FROM my_pots GROUP BY currency_code
      ), '[]'::jsonb)
    ),
    'transactions', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'pays_id',       pd.pays_id,
        'kind',          pd.kind,
        'payment_date',  pd.payment_date,
        'created_at',    pd.created_at,
        'status',        pd.status,
        'direction',     pd.direction,
        'signed_amount', pd.signed_amount,
        'leg_amount',    pd.leg_amount,
        'pot_id',        pd.pot_id,
        'pot_currency',  pd.pot_currency,
        'balance_after', pd.balance_after,
        'books_amount',  pd.books_amount,
        'exchange_rate', pd.exchange_rate,
        'other_side', CASE
          WHEN pd.other_pot_id IS NULL
            THEN jsonb_build_object('kind', 'external')
          ELSE (
            SELECT jsonb_build_object(
              'pot_id',   pp.id,
              'currency', pp.currency_code,
              'kind',     a.entity_type,
              'id',       a.entity_id,
              'name',     COALESCE(pr.name, t.name, a.entity_type)
            )
            FROM money_kernel.cashbook_lots pp
            JOIN money_kernel.cashbook_points    pt ON pt.id = pp.cashbook_point_id
            JOIN money_kernel.cashbook_accounts  a  ON a.id  = pt.cashbook_account_id
            LEFT JOIN public.profiles      pr ON pr.id = a.entity_id AND a.entity_type = 'profile' AND pr.tenant_id = a.tenant_id
            LEFT JOIN public.tenants       t  ON t.id  = a.entity_id AND a.entity_type = 'tenant'
            WHERE pp.id = pd.other_pot_id
          )
        END,
        'refs', pd.refs,
        'meta', pd.meta
      ) ORDER BY pd.created_at DESC, pd.pays_id DESC, pd.direction DESC)
      FROM page_rows pd
    ), '[]'::jsonb),
    'echoed_filters', jsonb_build_object(
      'tenant_id',      p_tenant_id,
      'profile_id',     p_profile_id,
      'from_date',      p_from_date,
      'to_date',        p_to_date,
      'kind',           p_kind,
      'currency_code',  p_currency_code,
      'pot_id',         p_pot_id,
      'bill_id',        p_bill_id,
      'include_voided', p_include_voided,
      'limit',          p_limit,
      'cursor',         p_cursor
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_list_bill_kinds()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
BEGIN
  RETURN jsonb_build_object(
    'kinds', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'kind',             r.kind,
        'numbering_prefix', r.numbering_prefix,
        'default_status',   r.default_status,
        'can_be_issued',    r.can_be_issued,
        'can_be_paid',      r.can_be_paid,
        'required_meta',    to_jsonb(r.required_meta),
        'description',      r.description,
        'is_active',        r.is_active
      ) ORDER BY r.kind)
      FROM money_kernel.bill_kind_registry r
      WHERE r.is_active = true
    ), '[]'::jsonb),
    'count', (SELECT COUNT(*) FROM money_kernel.bill_kind_registry WHERE is_active = true)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.list_money_kernel_currencies()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = money_kernel, public, pg_temp
AS $$
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'code',        c.code,
        'minor_units', c.minor_units,
        'name',        c.name
      )
      ORDER BY c.code
    ),
    '[]'::jsonb
  )
  FROM money_kernel.currencies c;
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

CREATE OR REPLACE VIEW public.v_bill_events
  WITH (security_invoker = true)
AS
SELECT
  e.id           AS event_id,
  e.tenant_id,
  e.bill_id,
  b.kind         AS bill_kind,
  b.invoice_no,
  b.status       AS bill_status_current,
  e.event_type,
  e.payload,
  e.actor_id,
  e.created_at
FROM money_kernel.bill_events e
JOIN money_kernel.bills b ON b.id = e.bill_id;

CREATE OR REPLACE VIEW public.v_pot_balances
  WITH (security_invoker = true)
AS
SELECT
  pp.id                AS pot_id,
  pp.tenant_id,
  a.id                 AS cashbook_account_id,
  a.entity_type,
  a.entity_id,
  pt.id                AS cashbook_point_id,
  pt.code              AS point_code,
  pt.name              AS point_name,
  pp.currency_code,
  pp.amount,
  pp.created_at,
  pp.updated_at,
  (a.default_cashbook_lot_id = pp.id) AS is_default_lot,

  -- Entity display resolution
  COALESCE(pr.name, t.name, a.entity_type) AS entity_name,
  pr.profile_type,
  pr.phone,
  pr.email,

  -- Container totals
  (
    SELECT COUNT(*)
    FROM money_kernel.cashbook_lots pp2
    JOIN money_kernel.cashbook_points    pt2 ON pt2.id = pp2.cashbook_point_id
    WHERE pt2.cashbook_account_id = a.id
  )                    AS pots_in_account
FROM money_kernel.cashbook_lots pp
JOIN money_kernel.cashbook_points pt    ON pt.id = pp.cashbook_point_id
JOIN money_kernel.cashbook_accounts a   ON a.id  = pt.cashbook_account_id
LEFT JOIN public.profiles pr      ON pr.id = a.entity_id AND a.entity_type = 'profile' AND pr.tenant_id = a.tenant_id
LEFT JOIN public.tenants  t       ON t.id  = a.entity_id AND a.entity_type = 'tenant';

CREATE OR REPLACE VIEW public.v_pot_balances
  WITH (security_invoker = true)
AS
SELECT
  pp.id                AS pot_id,
  pp.tenant_id,
  a.id                 AS cashbook_account_id,
  a.entity_type,
  a.entity_id,
  pt.id                AS cashbook_point_id,
  pt.code              AS point_code,
  pt.name              AS point_name,
  pp.currency_code,
  pp.amount,
  pp.created_at,
  pp.updated_at,
  (a.default_cashbook_lot_id = pp.id) AS is_default_lot,
  COALESCE(pr.name, t.name, a.entity_type) AS entity_name,
  pr.profile_type,
  pr.phone,
  pr.email,
  COALESCE(cnt.pots_in_account, 0) AS pots_in_account
FROM money_kernel.cashbook_lots pp
JOIN money_kernel.cashbook_points pt    ON pt.id = pp.cashbook_point_id
JOIN money_kernel.cashbook_accounts a   ON a.id  = pt.cashbook_account_id
LEFT JOIN public.profiles pr      ON pr.id = a.entity_id AND a.entity_type = 'profile' AND pr.tenant_id = a.tenant_id
LEFT JOIN public.tenants  t       ON t.id  = a.entity_id AND a.entity_type = 'tenant'
LEFT JOIN (
  SELECT pt2.cashbook_account_id, COUNT(*) AS pots_in_account
  FROM money_kernel.cashbook_points pt2
  JOIN money_kernel.cashbook_lots pp2 ON pp2.cashbook_point_id = pt2.id
  GROUP BY pt2.cashbook_account_id
) cnt ON cnt.cashbook_account_id = a.id;
