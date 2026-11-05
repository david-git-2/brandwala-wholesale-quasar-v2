-- Default document_number_configs (run once; safe to re-run via NOT EXISTS).

INSERT INTO public.document_number_configs (
  tenant_id, doc_type, prefix, sub_type_mode, period, padding, separator, timezone, is_active
)
SELECT v.*
FROM (
  VALUES
    (NULL::bigint, 'shop_order', 'SO', 'none', 'day', 4::smallint, '-', 'UTC', true),
    (NULL::bigint, 'sales_invoice', 'INV', 'invoice_type', 'month', 4::smallint, '-', 'UTC', true),
    (NULL::bigint, 'credit_note', 'CN', 'invoice_type', 'month', 4::smallint, '-', 'UTC', true),
    (NULL::bigint, 'debit_note', 'DN', 'invoice_type', 'month', 4::smallint, '-', 'UTC', true),
    (NULL::bigint, 'ap_bill', 'AP', 'none', 'month', 4::smallint, '-', 'UTC', true),
    (NULL::bigint, 'dropship_b2b_invoice', 'DS', 'none', 'month', 4::smallint, '-', 'UTC', true),
    (NULL::bigint, 'shipment', 'SHP', 'none', 'none', 4::smallint, '-', 'UTC', true),
    (NULL::bigint, 'stock_movement', 'MOV', 'none', 'day', 4::smallint, '-', 'UTC', true),
    (NULL::bigint, 'stock_movement_manual', 'SM', 'none', 'day', 4::smallint, '-', 'UTC', true),
    (NULL::bigint, 'receive_putaway', 'RP', 'none', 'day', 4::smallint, '-', 'UTC', true),
    (NULL::bigint, 'vendor_return', 'VR', 'none', 'day', 4::smallint, '-', 'UTC', true)
) AS v(tenant_id, doc_type, prefix, sub_type_mode, period, padding, separator, timezone, is_active)
WHERE NOT EXISTS (
  SELECT 1
  FROM public.document_number_configs c
  WHERE c.tenant_id IS NULL AND c.doc_type = v.doc_type
);
