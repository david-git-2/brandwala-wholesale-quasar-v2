-- Read-only sanity checks after backfill (expect zero rows with gap = true).

SELECT 'missing_default_configs' AS check_name, c.doc_type
FROM (
  VALUES
    ('shop_order'),
    ('sales_invoice'),
    ('credit_note'),
    ('debit_note'),
    ('ap_bill'),
    ('dropship_b2b_invoice'),
    ('shipment'),
    ('stock_movement'),
    ('stock_movement_manual'),
    ('receive_putaway'),
    ('vendor_return')
) AS expected(doc_type)
LEFT JOIN public.document_number_configs c
  ON c.tenant_id IS NULL AND c.doc_type = expected.doc_type AND c.is_active
WHERE c.id IS NULL;

SELECT 'shipment_counter_below_max_tenant_shipment_id' AS check_name,
  dnc.tenant_id,
  dnc.last_value,
  mx.max_shipment_id
FROM public.document_number_counters dnc
JOIN (
  SELECT u.tenant_id, max(u.max_shipment_id) AS max_shipment_id
  FROM (
    SELECT gs.parent_tenant_id AS tenant_id, max(gs.tenant_shipment_id)::bigint AS max_shipment_id
    FROM public.global_shipments gs
    WHERE gs.parent_tenant_id IS NOT NULL
      AND gs.tenant_shipment_id IS NOT NULL
    GROUP BY gs.parent_tenant_id
    UNION ALL
    SELECT s.tenant_id, max(s.tenant_shipment_id)::bigint AS max_shipment_id
    FROM public.shipments s
    GROUP BY s.tenant_id
  ) u
  GROUP BY u.tenant_id
) mx ON mx.tenant_id = dnc.tenant_id
WHERE dnc.doc_type = 'shipment'
  AND dnc.sub_type = ''
  AND dnc.period_key = ''
  AND dnc.last_value < mx.max_shipment_id;
