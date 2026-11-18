-- Read-only drift report for local DB (shipment AP vs stamped landed cost)
\set ON_ERROR_STOP on

WITH ap_shipments AS (
  SELECT DISTINCT b.ap_shipment_id AS shipment_id
  FROM money_kernel.bills b
  WHERE b.kind = 'shipment_cost_ap'
    AND b.ap_shipment_id IS NOT NULL
    AND b.status IS DISTINCT FROM 'voided'
),
line_totals AS (
  SELECT gsi.shipment_id,
         round(coalesce(sum(gsi.landed_cost_bdt * gsi.ordered_quantity), 0), 2) AS line_landed_sum
  FROM public.global_shipment_items gsi
  JOIN ap_shipments a ON a.shipment_id = gsi.shipment_id
  GROUP BY gsi.shipment_id
),
pool_totals AS (
  SELECT a.shipment_id,
         round(
           coalesce((public._global_shipment_landed_fx_inputs(a.shipment_id) ->> 'goods_bdt')::numeric, 0)
           + coalesce((public._global_shipment_landed_fx_inputs(a.shipment_id) ->> 'freight_bdt')::numeric, 0),
           2
         ) AS pool_goods_freight_bdt
  FROM ap_shipments a
),
landed_drift AS (
  SELECT l.shipment_id,
         'landed_vs_pool' AS kind,
         l.line_landed_sum,
         p.pool_goods_freight_bdt,
         abs(l.line_landed_sum - p.pool_goods_freight_bdt) AS delta
  FROM line_totals l
  JOIN pool_totals p ON p.shipment_id = l.shipment_id
  WHERE abs(l.line_landed_sum - p.pool_goods_freight_bdt) > 0.05
    AND p.pool_goods_freight_bdt > 0
),
negative_due AS (
  SELECT b.ap_shipment_id AS shipment_id,
         'bill_negative_due' AS kind,
         b.id AS bill_id,
         b.due_amount
  FROM money_kernel.bills b
  WHERE b.kind = 'shipment_cost_ap'
    AND b.ap_shipment_id IS NOT NULL
    AND coalesce(b.due_amount, 0) < -0.01
),
problems AS (
  SELECT shipment_id::text AS shipment_id, kind, delta::text AS detail FROM landed_drift
  UNION ALL
  SELECT shipment_id::text, kind, due_amount::text FROM negative_due
)
SELECT shipment_id, kind, detail FROM problems ORDER BY shipment_id, kind;

DO $$
DECLARE
  v_count bigint;
BEGIN
  WITH ap_shipments AS (
    SELECT DISTINCT b.ap_shipment_id AS shipment_id
    FROM money_kernel.bills b
    WHERE b.kind = 'shipment_cost_ap'
      AND b.ap_shipment_id IS NOT NULL
      AND b.status IS DISTINCT FROM 'voided'
  ),
  line_totals AS (
    SELECT gsi.shipment_id,
           round(coalesce(sum(gsi.landed_cost_bdt * gsi.ordered_quantity), 0), 2) AS line_landed_sum
    FROM public.global_shipment_items gsi
    JOIN ap_shipments a ON a.shipment_id = gsi.shipment_id
    GROUP BY gsi.shipment_id
  ),
  pool_totals AS (
    SELECT a.shipment_id,
           round(
             coalesce((public._global_shipment_landed_fx_inputs(a.shipment_id) ->> 'goods_bdt')::numeric, 0)
             + coalesce((public._global_shipment_landed_fx_inputs(a.shipment_id) ->> 'freight_bdt')::numeric, 0),
             2
           ) AS pool_goods_freight_bdt
    FROM ap_shipments a
  ),
  landed_drift AS (
    SELECT 1
    FROM line_totals l
    JOIN pool_totals p ON p.shipment_id = l.shipment_id
    WHERE abs(l.line_landed_sum - p.pool_goods_freight_bdt) > 0.05
      AND p.pool_goods_freight_bdt > 0
  ),
  negative_due AS (
    SELECT 1
    FROM money_kernel.bills b
    WHERE b.kind = 'shipment_cost_ap'
      AND b.ap_shipment_id IS NOT NULL
      AND coalesce(b.due_amount, 0) < -0.01
  )
  SELECT count(*) INTO v_count
  FROM (
    SELECT * FROM landed_drift
    UNION ALL
    SELECT * FROM negative_due
  ) u;

  IF v_count > 0 THEN
    RAISE EXCEPTION 'VERIFY MONEY DRIFT: % problem row(s) — see query output above', v_count;
  END IF;
END;
$$;