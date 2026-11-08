-- Backfill bill_lines.shipment_item_id and line_meta.shipment_ref

UPDATE public.bill_lines bl
SET shipment_item_id = gs.shipment_item_id
FROM public.global_stocks gs
WHERE bl.shipment_item_id IS NULL
  AND nullif(bl.line_meta->'stock_ref'->>'global_stock_id', '')::bigint = gs.id
  AND gs.shipment_item_id IS NOT NULL;

UPDATE public.bill_lines bl
SET shipment_item_id = src.shipment_item_id
FROM (
  SELECT DISTINCT ON (bl2.id)
    bl2.id AS bill_line_id,
    sp.shipment_item_id
  FROM public.bill_lines bl2
  INNER JOIN public.bills b ON b.id = bl2.invoice_id
  INNER JOIN public.shop_order_item_stock_picks sp ON sp.order_id = b.shop_order_id
  INNER JOIN public.shop_order_items oi ON oi.id = sp.order_item_id
    AND oi.product_id = bl2.product_id
  WHERE bl2.shipment_item_id IS NULL
    AND bl2.product_id IS NOT NULL
    AND sp.shipment_item_id IS NOT NULL
  ORDER BY bl2.id, sp.quantity DESC, sp.id DESC
) src
WHERE bl.id = src.bill_line_id;

UPDATE public.bill_lines bl
SET shipment_item_id = src.shipment_item_id
FROM (
  SELECT DISTINCT ON (bl2.id)
    bl2.id AS bill_line_id,
    gsi.id AS shipment_item_id
  FROM public.bill_lines bl2
  INNER JOIN public.bills b ON b.id = bl2.invoice_id
  INNER JOIN public.delivery_paper dp
    ON dp.source_type = 'shop_order'::public.delivery_paper_source_type
   AND dp.source_id = b.shop_order_id
  INNER JOIN public.delivery_paper_line dpl ON dpl.delivery_paper_id = dp.id
  INNER JOIN public.preorder_demand pd ON pd.id = dpl.preorder_demand_id
  INNER JOIN public.shop_order_items oi ON oi.id = pd.source_id
    AND oi.product_id = bl2.product_id
  INNER JOIN public.global_shipment_items gsi ON gsi.product_id = bl2.product_id
  INNER JOIN public.global_shipments s ON s.id = gsi.shipment_id
  WHERE bl2.shipment_item_id IS NULL
    AND bl2.product_id IS NOT NULL
    AND b.shop_order_id IS NOT NULL
    AND s.tenant_id = bl2.tenant_id
    AND EXISTS (
      SELECT 1
      FROM jsonb_array_elements(dpl.splits) elem
      WHERE nullif(elem->>'invoice_id', '')::bigint = b.id
    )
  ORDER BY bl2.id, gsi.id DESC
) src
WHERE bl.id = src.bill_line_id;

UPDATE public.bill_lines bl
SET line_meta = jsonb_set(
  coalesce(bl.line_meta, '{}'::jsonb),
  '{shipment_ref}',
  jsonb_build_object(
    'shipment_item_id', bl.shipment_item_id,
    'shipment_id', gsi.shipment_id
  ),
  true
)
FROM public.global_shipment_items gsi
WHERE bl.shipment_item_id = gsi.id
  AND gsi.shipment_id IS NOT NULL
  AND coalesce(bl.line_meta->'shipment_ref'->>'shipment_item_id', '') = '';
