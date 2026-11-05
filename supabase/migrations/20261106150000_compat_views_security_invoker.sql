-- Bill compat views: enforce caller RLS on bill_lines / sales_return_items (Supabase linter).

CREATE OR REPLACE VIEW public.global_invoice_items
WITH (security_invoker = true) AS
SELECT
  id,
  tenant_id,
  invoice_id,
  ((line_meta -> 'stock_ref'::text) ->> 'global_stock_id'::text)::bigint AS global_stock_id,
  shipment_item_id,
  product_id,
  name_snapshot,
  barcode_snapshot,
  product_code_snapshot,
  quantity,
  sell_price_amount,
  line_discount_amount,
  line_total_amount,
  return_quantity,
  created_at,
  updated_at,
  assigned_child_tenant_id,
  line_meta,
  line_kind,
  currency_code,
  books_amount
FROM public.bill_lines;

CREATE OR REPLACE VIEW public.global_return_items
WITH (security_invoker = true) AS
SELECT
  id,
  tenant_id,
  invoice_id,
  invoice_item_id,
  global_stock_id,
  quantity,
  return_charge_amount,
  note,
  created_at,
  updated_at
FROM public.sales_return_items;
