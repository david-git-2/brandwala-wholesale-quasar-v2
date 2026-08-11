-- Allow correcting Online parcel: DELIVERED → IN_TRANSIT.
-- Deletes DELIVERED PnL rows and clears economics_closed_at so a later
-- DELIVERED can rewrite PnL. Blocked after any return/RTO PnL.

BEGIN;

CREATE OR REPLACE FUNCTION public.update_thrift_sales_delivery_status(
  p_tenant_id BIGINT,
  p_invoice_id BIGINT,
  p_delivery_status TEXT,
  p_actor TEXT DEFAULT 'cashier'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invoice public.thrift_sales_invoices%ROWTYPE;
  v_target TEXT;
  v_current TEXT;
  v_event_at TIMESTAMPTZ := NOW();
  v_pool_delivery NUMERIC(12,2) := 0.00;
  v_pool_cod NUMERIC(12,2) := 0.00;
  v_pool_packing NUMERIC(12,2) := 0.00;
  v_total_value NUMERIC(12,2) := 0.00;
  v_line_count INT := 0;
  v_idx INT := 0;
  v_cum_delivery NUMERIC(12,2) := 0.00;
  v_cum_cod NUMERIC(12,2) := 0.00;
  v_cum_packing NUMERIC(12,2) := 0.00;
  v_line RECORD;
  v_line_value NUMERIC(12,2);
  v_share NUMERIC;
  v_alloc_delivery NUMERIC(12,2);
  v_alloc_cod NUMERIC(12,2);
  v_alloc_packing NUMERIC(12,2);
  v_inbound_shipment_id BIGINT;
  v_pnl_exists BOOLEAN := FALSE;
  v_non_delivered_pnl INT := 0;
  v_deleted_pnl INT := 0;
  v_economics_closed_at TIMESTAMPTZ;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'create')
     AND NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'return')
  THEN
    RAISE EXCEPTION 'Updating delivery status requires thrift_sales create or return permission';
  END IF;

  v_target := upper(trim(COALESCE(p_delivery_status, '')));
  IF v_target NOT IN ('PENDING', 'READY', 'IN_TRANSIT', 'DELIVERED', 'RETURNED') THEN
    RAISE EXCEPTION 'Invalid delivery_status: %', p_delivery_status;
  END IF;

  SELECT * INTO v_invoice
  FROM public.thrift_sales_invoices
  WHERE id = p_invoice_id
    AND tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invoice % not found for tenant %', p_invoice_id, p_tenant_id;
  END IF;

  IF COALESCE(v_invoice.sale_channel, 'IN_STORE') <> 'ONLINE' THEN
    RAISE EXCEPTION 'delivery_status applies to Online invoices only';
  END IF;

  IF v_invoice.status IS DISTINCT FROM 'ACTIVE' THEN
    RAISE EXCEPTION 'Cannot update delivery on invoice status %', v_invoice.status;
  END IF;

  IF v_target = 'RETURNED' THEN
    RAISE EXCEPTION
      'Set delivery RETURNED via revert_thrift_sales_invoice (RTO), not delivery advance';
  END IF;

  v_current := COALESCE(v_invoice.delivery_status, 'PENDING');
  v_economics_closed_at := v_invoice.economics_closed_at;

  IF v_current = v_target THEN
    RETURN jsonb_build_object(
      'id', v_invoice.id,
      'delivery_status', v_current,
      'unchanged', true,
      'economics_closed_at', v_invoice.economics_closed_at
    );
  END IF;

  -- Correction: undo mistaken deliver (only to IN_TRANSIT; reopen economics).
  IF v_current = 'DELIVERED' AND v_target = 'IN_TRANSIT' THEN
    SELECT COUNT(*)::INT
    INTO v_non_delivered_pnl
    FROM public.thrift_sales_pnl_lines p
    WHERE p.tenant_id = p_tenant_id
      AND p.invoice_id = p_invoice_id
      AND p.outcome IS DISTINCT FROM 'DELIVERED';

    IF v_non_delivered_pnl > 0 THEN
      RAISE EXCEPTION
        'Cannot move delivery from DELIVERED to IN_TRANSIT after return/RTO PnL exists';
    END IF;

    DELETE FROM public.thrift_sales_pnl_lines p
    WHERE p.tenant_id = p_tenant_id
      AND p.invoice_id = p_invoice_id
      AND p.outcome = 'DELIVERED';

    GET DIAGNOSTICS v_deleted_pnl = ROW_COUNT;

    UPDATE public.thrift_sales_invoices
    SET
      delivery_status = 'IN_TRANSIT',
      economics_closed_at = NULL,
      updated_at = NOW()
    WHERE id = p_invoice_id
      AND tenant_id = p_tenant_id;

    RETURN jsonb_build_object(
      'id', p_invoice_id,
      'delivery_status', 'IN_TRANSIT',
      'previous_delivery_status', v_current,
      'actor', COALESCE(NULLIF(trim(p_actor), ''), 'cashier'),
      'unchanged', false,
      'pnl_lines_deleted', v_deleted_pnl,
      'economics_closed_at', NULL
    );
  END IF;

  IF v_current = 'DELIVERED' AND v_target <> 'DELIVERED' THEN
    RAISE EXCEPTION 'Cannot move delivery from DELIVERED to %', v_target;
  END IF;

  UPDATE public.thrift_sales_invoices
  SET
    delivery_status = v_target,
    updated_at = NOW()
  WHERE id = p_invoice_id
    AND tenant_id = p_tenant_id;

  -- First DELIVERED: write PnL (shop-paid fee pools only). Never flip payment_status.
  IF v_target = 'DELIVERED' THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.thrift_sales_pnl_lines p
      WHERE p.tenant_id = p_tenant_id
        AND p.invoice_id = p_invoice_id
    )
    INTO v_pnl_exists;

    IF NOT v_pnl_exists THEN
      v_pool_delivery := CASE
        WHEN upper(COALESCE(v_invoice.courier_paid_by, '')) = 'SHOP'
        THEN ROUND(COALESCE(v_invoice.courier_amount, 0), 2)
        ELSE 0.00
      END;
      v_pool_cod := CASE
        WHEN upper(COALESCE(v_invoice.cod_fee_paid_by, '')) = 'SHOP'
        THEN ROUND(COALESCE(v_invoice.cod_fee_amount, 0), 2)
        ELSE 0.00
      END;
      v_pool_packing := CASE
        WHEN upper(COALESCE(v_invoice.packing_paid_by, '')) = 'SHOP'
        THEN ROUND(COALESCE(v_invoice.packing_amount, 0), 2)
        ELSE 0.00
      END;

      SELECT
        COALESCE(SUM(ROUND(i.final_price * i.quantity, 2)), 0),
        COUNT(*)::INT
      INTO v_total_value, v_line_count
      FROM public.thrift_sales_invoice_items i
      WHERE i.tenant_id = p_tenant_id
        AND i.invoice_id = p_invoice_id;

      IF v_line_count = 0 THEN
        RAISE EXCEPTION 'Invoice % has no lines; cannot close economics', p_invoice_id;
      END IF;

      FOR v_line IN
        SELECT
          i.id AS invoice_item_id,
          i.stock_id,
          i.quantity,
          ROUND(i.final_price * i.quantity, 2) AS sell_amount,
          s.shipment_id
        FROM public.thrift_sales_invoice_items i
        JOIN public.thrift_stocks s
          ON s.id = i.stock_id
         AND s.tenant_id = i.tenant_id
        WHERE i.tenant_id = p_tenant_id
          AND i.invoice_id = p_invoice_id
        ORDER BY i.id
      LOOP
        v_idx := v_idx + 1;
        v_inbound_shipment_id := v_line.shipment_id;
        IF v_inbound_shipment_id IS NULL THEN
          RAISE EXCEPTION
            'Stock item % has no inbound shipment; cannot write PnL',
            v_line.stock_id;
        END IF;

        v_line_value := v_line.sell_amount;
        IF v_total_value > 0 THEN
          v_share := v_line_value / v_total_value;
        ELSE
          v_share := 1.0 / v_line_count;
        END IF;

        IF v_idx = v_line_count THEN
          v_alloc_delivery := ROUND(v_pool_delivery - v_cum_delivery, 2);
          v_alloc_cod := ROUND(v_pool_cod - v_cum_cod, 2);
          v_alloc_packing := ROUND(v_pool_packing - v_cum_packing, 2);
        ELSE
          v_alloc_delivery := ROUND(v_pool_delivery * v_share, 2);
          v_alloc_cod := ROUND(v_pool_cod * v_share, 2);
          v_alloc_packing := ROUND(v_pool_packing * v_share, 2);
          v_cum_delivery := v_cum_delivery + v_alloc_delivery;
          v_cum_cod := v_cum_cod + v_alloc_cod;
          v_cum_packing := v_cum_packing + v_alloc_packing;
        END IF;

        INSERT INTO public.thrift_sales_pnl_lines (
          tenant_id,
          invoice_id,
          invoice_item_id,
          stock_id,
          inbound_shipment_id,
          outcome,
          return_id,
          quantity,
          sell_amount,
          allocated_shop_delivery,
          allocated_shop_cod_fee,
          allocated_shop_packing,
          allocated_return_courier,
          allocated_fees_total,
          cogs_is_loss,
          event_at,
          event_date
        ) VALUES (
          p_tenant_id,
          p_invoice_id,
          v_line.invoice_item_id,
          v_line.stock_id,
          v_inbound_shipment_id,
          'DELIVERED',
          NULL,
          v_line.quantity,
          v_line_value,
          v_alloc_delivery,
          v_alloc_cod,
          v_alloc_packing,
          0.00,
          ROUND(v_alloc_delivery + v_alloc_cod + v_alloc_packing, 2),
          FALSE,
          v_event_at,
          (v_event_at AT TIME ZONE 'UTC')::DATE
        );
      END LOOP;

      UPDATE public.thrift_sales_invoices
      SET
        economics_closed_at = v_event_at,
        updated_at = NOW()
      WHERE id = p_invoice_id
        AND tenant_id = p_tenant_id;

      v_economics_closed_at := v_event_at;
    ELSIF v_invoice.economics_closed_at IS NULL THEN
      UPDATE public.thrift_sales_invoices
      SET
        economics_closed_at = v_event_at,
        updated_at = NOW()
      WHERE id = p_invoice_id
        AND tenant_id = p_tenant_id;

      v_economics_closed_at := v_event_at;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'id', p_invoice_id,
    'delivery_status', v_target,
    'previous_delivery_status', v_current,
    'actor', COALESCE(NULLIF(trim(p_actor), ''), 'cashier'),
    'unchanged', false,
    'economics_closed_at', CASE
      WHEN v_target = 'DELIVERED' THEN COALESCE(v_economics_closed_at, v_event_at)
      ELSE v_economics_closed_at
    END
  );
END;
$$;

COMMENT ON FUNCTION public.update_thrift_sales_delivery_status(BIGINT, BIGINT, TEXT, TEXT) IS
  'Advance Online parcel status. First DELIVERED inserts thrift_sales_pnl_lines (shop-paid fees) and sets economics_closed_at. DELIVERED→IN_TRANSIT deletes DELIVERED PnL and clears economics_closed_at. Never changes payment_status. RETURNED requires revert RTO.';

COMMIT;
