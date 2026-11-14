-- DP bill stock id without requiring live global_stocks row; backfill bill 24.

CREATE OR REPLACE FUNCTION public.delivery_paper_line_resolvable_bill_stock_id (
  p_line public.delivery_paper_line
)
  RETURNS bigint
  LANGUAGE sql
  STABLE
  AS $function$
  SELECT CASE
    WHEN p_line.global_stock_id IS NOT NULL AND p_line.global_stock_id > 0 THEN
      p_line.global_stock_id
    WHEN p_line.dispatched_global_stock_id IS NOT NULL
      AND p_line.dispatched_global_stock_id > 0 THEN
      p_line.dispatched_global_stock_id
    ELSE NULL::bigint
  END;
$function$;

ALTER TABLE money_kernel.bill_lines DISABLE TRIGGER trg_bill_lines_guard;

UPDATE money_kernel.bill_lines bl
SET
  global_stock_id = 407,
  shipment_id = 52,
  shipment_item_id = 1033,
  product_id = 4343,
  item_kind = 'stock',
  meta = coalesce(bl.meta, '{}'::jsonb)
    || jsonb_build_object(
      'shipment_ref', jsonb_build_object('shipment_id', 52, 'shipment_item_id', 1033),
      'stock_ref', jsonb_build_object('global_stock_id', 407)
    )
WHERE bl.bill_id = 24
  AND bl.line_no = 1;

UPDATE money_kernel.bill_lines bl
SET
  global_stock_id = 406,
  shipment_id = 52,
  shipment_item_id = 1032,
  product_id = 4347,
  item_kind = 'stock',
  meta = coalesce(bl.meta, '{}'::jsonb)
    || jsonb_build_object(
      'shipment_ref', jsonb_build_object('shipment_id', 52, 'shipment_item_id', 1032),
      'stock_ref', jsonb_build_object('global_stock_id', 406)
    )
WHERE bl.bill_id = 24
  AND bl.line_no = 2;

-- Backfill applied via UPDATE above; skip _kernel_backfill when stock rows are gone.

ALTER TABLE money_kernel.bill_lines ENABLE TRIGGER trg_bill_lines_guard;
