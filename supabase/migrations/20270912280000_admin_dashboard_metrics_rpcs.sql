-- Staff app dashboard glance RPCs (one per widget). Do not combine into a mega RPC.

CREATE OR REPLACE FUNCTION public.get_procurement_dashboard_metrics(p_tenant_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_books_id bigint;
  v_sellable bigint := 0;
  v_held bigint := 0;
  v_unsellable bigint := 0;
  v_total bigint := 0;
  v_value numeric := 0;
  v_in_transit bigint := 0;
  v_draft bigint := 0;
  v_grades jsonb := '[]'::jsonb;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'global_stock', 'view') THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  SELECT
    coalesce(sum(gs.quantity) FILTER (WHERE gs.availability = 'sellable'::public.stock_availability), 0),
    coalesce(sum(gs.quantity) FILTER (WHERE gs.availability = 'held'::public.stock_availability), 0),
    coalesce(sum(gs.quantity) FILTER (WHERE gs.availability = 'unsellable'::public.stock_availability), 0),
    coalesce(sum(gs.quantity), 0),
    coalesce(
      sum(gs.quantity * coalesce(gsi.landed_cost_bdt, 0))
        FILTER (WHERE gs.availability = 'sellable'::public.stock_availability),
      0
    )
  INTO v_sellable, v_held, v_unsellable, v_total, v_value
  FROM public.global_stocks gs
  JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
  WHERE gs.parent_tenant_id = v_books_id;

  SELECT
    coalesce(count(*) FILTER (WHERE s.status = 'in_transit'), 0),
    coalesce(count(*) FILTER (WHERE s.status = 'draft'), 0)
  INTO v_in_transit, v_draft
  FROM public.global_shipments s
  WHERE s.parent_tenant_id = v_books_id
    AND s.is_archived = false;

  SELECT coalesce(jsonb_agg(row_to_json(g) ORDER BY g.qty DESC), '[]'::jsonb)
  INTO v_grades
  FROM (
    SELECT coalesce(t.name, 'Ungraded') AS name, sum(gs.quantity)::bigint AS qty
    FROM public.global_stocks gs
    LEFT JOIN public.tags t ON t.id = gs.grade_tag_id
    WHERE gs.parent_tenant_id = v_books_id
      AND gs.quantity > 0
    GROUP BY coalesce(t.name, 'Ungraded')
  ) g;

  RETURN jsonb_build_object(
    'tenant_id', v_books_id,
    'sellable_qty', v_sellable,
    'held_qty', v_held,
    'unsellable_qty', v_unsellable,
    'total_qty', v_total,
    'sellable_pct', CASE WHEN v_total > 0 THEN round((v_sellable::numeric / v_total) * 100, 1) ELSE 0 END,
    'sellable_value_bdt', round(v_value, 2),
    'in_transit_count', v_in_transit,
    'draft_count', v_draft,
    'grades', v_grades
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_procurement_dashboard_metrics(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_procurement_dashboard_metrics(bigint) TO authenticated;


CREATE OR REPLACE FUNCTION public.get_shop_order_dashboard_metrics(p_tenant_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today date;
  v_sales numeric := 0;
  v_invoice_count bigint := 0;
  v_shipped bigint := 0;
  v_ready bigint := 0;
  v_hourly jsonb := '[]'::jsonb;
  v_couriers jsonb := '[]'::jsonb;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'shop_order', 'view') THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  v_today := (timezone('Asia/Dhaka', now()))::date;

  SELECT
    coalesce(sum(si.total_amount), 0),
    count(*)
  INTO v_sales, v_invoice_count
  FROM public.sales_invoices si
  WHERE si.issued_by_tenant_id = p_tenant_id
    AND si.invoice_status = 'issued'::public.global_invoice_status
    AND si.invoice_date = v_today;

  SELECT
    coalesce(count(*) FILTER (WHERE o.status = 'shipped'::public.shop_order_status), 0),
    coalesce(count(*) FILTER (WHERE o.status = 'ready_for_pickup'::public.shop_order_status), 0)
  INTO v_shipped, v_ready
  FROM public.shop_orders o
  WHERE o.tenant_id = p_tenant_id
    AND o.status IN (
      'shipped'::public.shop_order_status,
      'ready_for_pickup'::public.shop_order_status
    );

  SELECT coalesce(jsonb_agg(row_to_json(h) ORDER BY h.hour_at), '[]'::jsonb)
  INTO v_hourly
  FROM (
    SELECT
      date_trunc('hour', timezone('Asia/Dhaka', si.created_at)) AS hour_at,
      to_char(timezone('Asia/Dhaka', si.created_at), 'HH12 AM') AS label,
      round(sum(si.total_amount), 2) AS amount
    FROM public.sales_invoices si
    WHERE si.issued_by_tenant_id = p_tenant_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND si.invoice_date = v_today
    GROUP BY 1, 2
  ) h;

  SELECT coalesce(jsonb_agg(row_to_json(c) ORDER BY c.count DESC), '[]'::jsonb)
  INTO v_couriers
  FROM (
    SELECT
      coalesce(nullif(trim(o.courier_name), ''), 'Store pickup') AS name,
      count(*)::bigint AS count,
      count(*) FILTER (WHERE o.status = 'shipped'::public.shop_order_status)::bigint AS shipped_count,
      count(*) FILTER (WHERE o.status = 'ready_for_pickup'::public.shop_order_status)::bigint AS ready_count
    FROM public.shop_orders o
    WHERE o.tenant_id = p_tenant_id
      AND o.status IN (
        'shipped'::public.shop_order_status,
        'ready_for_pickup'::public.shop_order_status
      )
    GROUP BY 1
  ) c;

  RETURN jsonb_build_object(
    'tenant_id', p_tenant_id,
    'today_sales_amount', round(v_sales, 2),
    'today_invoice_count', v_invoice_count,
    'shipped_count', v_shipped,
    'ready_for_pickup_count', v_ready,
    'hourly', v_hourly,
    'couriers', v_couriers
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_shop_order_dashboard_metrics(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_shop_order_dashboard_metrics(bigint) TO authenticated;


CREATE OR REPLACE FUNCTION public.get_sales_invoice_dashboard_metrics(p_tenant_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today date;
  v_today_billed numeric := 0;
  v_unpaid_count bigint := 0;
  v_overdue_count bigint := 0;
  v_draft_count bigint := 0;
  v_paid numeric := 0;
  v_due numeric := 0;
  v_overdue numeric := 0;
  v_customers jsonb := '[]'::jsonb;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'global_invoice', 'view') THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  v_today := (timezone('Asia/Dhaka', now()))::date;

  SELECT
    coalesce(sum(si.total_amount) FILTER (
      WHERE si.invoice_status = 'issued'::public.global_invoice_status
        AND si.invoice_date = v_today
    ), 0),
    count(*) FILTER (
      WHERE si.invoice_status = 'issued'::public.global_invoice_status
        AND si.due_amount > 0
    ),
    count(*) FILTER (
      WHERE si.invoice_status = 'issued'::public.global_invoice_status
        AND si.due_amount > 0
        AND si.due_date IS NOT NULL
        AND si.due_date < v_today
    ),
    count(*) FILTER (WHERE si.invoice_status = 'draft'::public.global_invoice_status),
    coalesce(sum(si.paid_amount) FILTER (
      WHERE si.invoice_status = 'issued'::public.global_invoice_status
    ), 0),
    coalesce(sum(si.due_amount) FILTER (
      WHERE si.invoice_status = 'issued'::public.global_invoice_status
        AND (si.due_date IS NULL OR si.due_date >= v_today)
        AND si.due_amount > 0
    ), 0),
    coalesce(sum(si.due_amount) FILTER (
      WHERE si.invoice_status = 'issued'::public.global_invoice_status
        AND si.due_amount > 0
        AND si.due_date IS NOT NULL
        AND si.due_date < v_today
    ), 0)
  INTO v_today_billed, v_unpaid_count, v_overdue_count, v_draft_count, v_paid, v_due, v_overdue
  FROM public.sales_invoices si
  WHERE si.issued_by_tenant_id = p_tenant_id;

  SELECT coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  INTO v_customers
  FROM (
    SELECT
      coalesce(nullif(trim(bp.name), ''), nullif(trim(si.recipient_name), ''), 'Unknown') AS name,
      round(sum(si.due_amount), 2) AS due_amount,
      count(*)::bigint AS invoice_count
    FROM public.sales_invoices si
    LEFT JOIN public.billing_profiles bp ON bp.id = si.billing_profile_id
    WHERE si.issued_by_tenant_id = p_tenant_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND si.due_amount > 0
      AND si.due_date IS NOT NULL
      AND si.due_date < v_today
    GROUP BY 1
    ORDER BY sum(si.due_amount) DESC
    LIMIT 5
  ) r;

  RETURN jsonb_build_object(
    'tenant_id', p_tenant_id,
    'today_billed_amount', round(v_today_billed, 2),
    'unpaid_count', v_unpaid_count,
    'overdue_count', v_overdue_count,
    'draft_count', v_draft_count,
    'paid_amount', round(v_paid, 2),
    'due_amount', round(v_due, 2),
    'overdue_amount', round(v_overdue, 2),
    'overdue_customers', v_customers
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_sales_invoice_dashboard_metrics(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_sales_invoice_dashboard_metrics(bigint) TO authenticated;


CREATE OR REPLACE FUNCTION public.get_tasks_dashboard_metrics(p_tenant_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text;
  v_today date;
  v_assigned bigint := 0;
  v_overdue bigint := 0;
  v_due_today bigint := 0;
  v_unassigned bigint := 0;
  v_todo bigint := 0;
  v_doing bigint := 0;
  v_stuck bigint := 0;
  v_done bigint := 0;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'tasks', 'view') THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  v_email := public.current_user_email();
  v_today := (timezone('Asia/Dhaka', now()))::date;

  SELECT
    count(*) FILTER (
      WHERE EXISTS (
        SELECT 1 FROM public.item_assignees ia
        WHERE ia.item_id = i.id AND ia.user_email = v_email
      )
      AND i.status NOT IN ('done', 'archived')
    ),
    count(*) FILTER (
      WHERE i.due_date IS NOT NULL
        AND i.due_date < now()
        AND i.status NOT IN ('done', 'archived')
    ),
    count(*) FILTER (
      WHERE i.due_date IS NOT NULL
        AND (timezone('Asia/Dhaka', i.due_date))::date = v_today
        AND i.status NOT IN ('done', 'archived')
    ),
    count(*) FILTER (
      WHERE NOT EXISTS (SELECT 1 FROM public.item_assignees ia WHERE ia.item_id = i.id)
        AND i.status NOT IN ('done', 'archived')
    ),
    count(*) FILTER (
      WHERE EXISTS (
        SELECT 1 FROM public.item_assignees ia
        WHERE ia.item_id = i.id AND ia.user_email = v_email
      )
      AND i.status = 'todo'
    ),
    count(*) FILTER (
      WHERE EXISTS (
        SELECT 1 FROM public.item_assignees ia
        WHERE ia.item_id = i.id AND ia.user_email = v_email
      )
      AND i.status = 'in_progress'
    ),
    count(*) FILTER (
      WHERE EXISTS (
        SELECT 1 FROM public.item_assignees ia
        WHERE ia.item_id = i.id AND ia.user_email = v_email
      )
      AND i.status IN ('blocked', 'review')
    ),
    count(*) FILTER (
      WHERE EXISTS (
        SELECT 1 FROM public.item_assignees ia
        WHERE ia.item_id = i.id AND ia.user_email = v_email
      )
      AND i.status = 'done'
    )
  INTO v_assigned, v_overdue, v_due_today, v_unassigned, v_todo, v_doing, v_stuck, v_done
  FROM public.items i
  WHERE i.tenant_id = p_tenant_id
    AND i.type = 'task'
    AND i.archived_at IS NULL;

  RETURN jsonb_build_object(
    'tenant_id', p_tenant_id,
    'assigned_to_me', v_assigned,
    'overdue_count', v_overdue,
    'due_today_count', v_due_today,
    'unassigned_count', v_unassigned,
    'my_todo', v_todo,
    'my_doing', v_doing,
    'my_stuck', v_stuck,
    'my_done', v_done
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_tasks_dashboard_metrics(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_tasks_dashboard_metrics(bigint) TO authenticated;


CREATE OR REPLACE FUNCTION public.get_staff_investor_capital_metrics(p_tenant_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_books_id bigint;
  v_month_start timestamptz;
  v_capital_in numeric := 0;
  v_withdrawn numeric := 0;
  v_deployed numeric := 0;
  v_deployed_month numeric := 0;
  v_realized numeric := 0;
  v_open_count bigint := 0;
  v_containers jsonb := '[]'::jsonb;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'investor_capital_ledger', 'view') THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_month_start := date_trunc('month', timezone('Asia/Dhaka', now()));

  SELECT coalesce(sum(tx.amount), 0)
  INTO v_capital_in
  FROM public.investor_transactions tx
  JOIN public.investors i ON i.id = tx.investor_id
  WHERE i.tenant_id = v_books_id
    AND tx.type IN ('deposit', 'capital_in', 'capital_adjustment', 'manual_adjustment');

  SELECT coalesce(sum(tx.amount), 0)
  INTO v_withdrawn
  FROM public.investor_transactions tx
  JOIN public.investors i ON i.id = tx.investor_id
  WHERE i.tenant_id = v_books_id
    AND tx.type IN ('withdrawal', 'withdrawal_paid', 'profit_payout');

  SELECT
    coalesce(sum(si.allocated_cost), 0),
    coalesce(sum(si.allocated_cost) FILTER (WHERE si.created_at >= v_month_start), 0),
    coalesce(sum(si.computed_profit) FILTER (WHERE si.profit_status = 'realized'), 0),
    count(DISTINCT coalesce(si.global_shipment_id, si.shipment_id))
      FILTER (WHERE si.status = 'active'::public.shipment_investment_status)
  INTO v_deployed, v_deployed_month, v_realized, v_open_count
  FROM public.shipment_investments si
  WHERE si.tenant_id = v_books_id
    AND si.status = 'active'::public.shipment_investment_status;

  SELECT coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb)
  INTO v_containers
  FROM (
    SELECT
      coalesce(gs.name, 'Unnamed batch') AS name,
      round(sum(si.allocated_cost), 2) AS allocated_cost
    FROM public.shipment_investments si
    LEFT JOIN public.global_shipments gs ON gs.id = coalesce(si.global_shipment_id, si.shipment_id)
    WHERE si.tenant_id = v_books_id
      AND si.status = 'active'::public.shipment_investment_status
    GROUP BY coalesce(gs.name, 'Unnamed batch')
    ORDER BY sum(si.allocated_cost) DESC
    LIMIT 5
  ) c;

  RETURN jsonb_build_object(
    'tenant_id', v_books_id,
    'active_pool_amount', round(v_capital_in - v_withdrawn, 2),
    'deployed_amount', round(v_deployed, 2),
    'deployed_this_month', round(v_deployed_month, 2),
    'due_to_investors', round(greatest(v_realized - v_withdrawn, 0), 2),
    'returned_amount', round(v_withdrawn, 2),
    'open_container_count', v_open_count,
    'open_containers', v_containers
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_staff_investor_capital_metrics(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_staff_investor_capital_metrics(bigint) TO authenticated;
