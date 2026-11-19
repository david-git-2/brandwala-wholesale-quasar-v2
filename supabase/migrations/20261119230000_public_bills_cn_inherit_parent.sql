-- Credit/debit notes: inherit invoice_type and profile_id from parent (vendor refund RPC).

CREATE OR REPLACE VIEW public.bills
WITH (security_invoker = true)
AS
SELECT
  kb.id,
  kb.tenant_id,
  COALESCE(kb.invoice_no, 'DRAFT-' || kb.id::text) AS invoice_no,
  CASE
    WHEN kb.kind IN ('credit_note', 'debit_note') AND parent_kb.id IS NOT NULL
    THEN public._kernel_bill_invoice_type_enum(parent_kb.kind)
    ELSE public._kernel_bill_invoice_type_enum(kb.kind)
  END AS invoice_type,
  COALESCE(kb.invoice_date, CURRENT_DATE) AS invoice_date,
  NULLIF(kb.meta->>'retail_billing_mode', '')::public.retail_billing_mode AS retail_billing_mode,
  public._kernel_bill_invoice_status_enum(kb.status) AS invoice_status,
  NULL::bigint AS recipient_profile_id,
  NULLIF(kb.meta->>'recipient_name', '') AS recipient_name,
  NULLIF(kb.meta->>'recipient_phone', '') AS recipient_phone,
  NULLIF(kb.meta->>'recipient_address', '') AS recipient_address,
  'billing_profile'::public.collection_source_type AS collection_source,
  kb.due_date,
  public._desk_kernel_status_payment(kb.status, kb.due_amount) AS payment_status,
  kb.total_amount,
  kb.due_amount,
  COALESCE(kb.paid_amount, 0) AS paid_amount,
  COALESCE((kb.meta->>'subtotal_amount')::numeric(12, 2), kb.total_amount) AS subtotal_amount,
  COALESCE((kb.meta->>'discount_amount')::numeric(12, 2), 0) AS discount_amount,
  COALESCE((kb.meta->>'shipping_charge')::numeric(12, 2), 0) AS shipping_charge,
  COALESCE((kb.meta->>'wrapping_charge')::numeric(12, 2), 0) AS wrapping_charge,
  COALESCE((kb.meta->>'print_charge')::numeric(12, 2), 0) AS print_charge,
  kb.note,
  kb.created_by,
  kb.created_at,
  kb.updated_at,
  kb.tenant_id AS issued_by_tenant_id,
  COALESCE(kb.written_off_amount, 0) AS written_off_amount,
  NULLIF(kb.meta->>'shop_order_id', '')::bigint AS shop_order_id,
  COALESCE((kb.meta->>'charges_amount')::numeric(12, 2), 0) AS charges_amount,
  COALESCE(kb.meta, '{}'::jsonb) AS channel_meta,
  COALESCE(
    kb.counterparty_profile_id,
    parent_kb.counterparty_profile_id,
    parent_kb.to_profile_id,
    kb.to_profile_id
  ) AS profile_id,
  CASE
    WHEN kb.source_type = 'shipment_cost' THEN NULLIF(BTRIM(kb.source_id), '')::bigint
    ELSE NULLIF(kb.meta->>'shipment_id', '')::bigint
  END AS ap_shipment_id,
  COALESCE(NULLIF(kb.meta->>'ap_kind', ''), NULLIF(split_part(COALESCE(kb.source_key, ''), ':', 1), '')) AS ap_kind,
  public._kernel_bill_document_kind_enum(kb.kind) AS document_kind,
  kb.parent_bill_id,
  kb.from_profile_id,
  kb.to_profile_id,
  NULLIF(kb.meta->>'delivery_kind', '')::public.bill_settlement_kind AS settlement_kind,
  kb.source_type,
  kb.source_id,
  kb.source_key,
  upper(COALESCE(kb.currency_code, 'BDT')) AS currency_code,
  NULLIF(kb.meta->>'txn_currency_code', '') AS txn_currency_code,
  COALESCE((kb.meta->>'txn_total_amount')::numeric(12, 2), kb.total_amount) AS txn_total_amount,
  COALESCE((kb.meta->>'books_exchange_rate')::numeric(15, 6), 1::numeric(15, 6)) AS books_exchange_rate
FROM money_kernel.bills kb
LEFT JOIN money_kernel.bills parent_kb
  ON parent_kb.id = kb.parent_bill_id
 AND kb.kind IN ('credit_note', 'debit_note');