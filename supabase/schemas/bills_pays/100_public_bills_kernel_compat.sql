-- public.bills / bill_lines read compat: kernel-only projections (apply after DROP legacy tables).

CREATE OR REPLACE FUNCTION public._kernel_bill_invoice_type_enum(p_kind text)
RETURNS public.global_invoice_type
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE public._desk_kernel_kind_invoice_type(p_kind)
    WHEN 'ap' THEN 'ap'::public.global_invoice_type
    WHEN 'retail' THEN 'retail'::public.global_invoice_type
    WHEN 'dropship' THEN 'dropship'::public.global_invoice_type
    ELSE 'wholesale'::public.global_invoice_type
  END;
$$;

CREATE OR REPLACE FUNCTION public._kernel_bill_invoice_status_enum(p_status text)
RETURNS public.global_invoice_status
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE p_status
    WHEN 'voided' THEN 'voided'::public.global_invoice_status
    WHEN 'draft' THEN 'draft'::public.global_invoice_status
  WHEN 'proforma_generated' THEN 'proforma_generated'::public.global_invoice_status
    ELSE 'issued'::public.global_invoice_status
  END;
$$;

CREATE OR REPLACE FUNCTION public._kernel_bill_document_kind_enum(p_kind text)
RETURNS public.bill_document_kind
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE p_kind
    WHEN 'credit_note' THEN 'credit_note'::public.bill_document_kind
    WHEN 'debit_note' THEN 'debit_note'::public.bill_document_kind
    ELSE 'standard'::public.bill_document_kind
  END;
$$;

CREATE OR REPLACE VIEW public.bills
WITH (security_invoker = true)
AS
SELECT
  kb.id,
  kb.tenant_id,
  COALESCE(kb.invoice_no, 'DRAFT-' || kb.id::text) AS invoice_no,
  public._kernel_bill_invoice_type_enum(kb.kind) AS invoice_type,
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
  kb.counterparty_profile_id AS profile_id,
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
FROM money_kernel.bills kb;

CREATE OR REPLACE VIEW public.bill_lines
WITH (security_invoker = true)
AS
SELECT
  bl.id,
  b.tenant_id,
  bl.bill_id AS invoice_id,
  bl.shipment_item_id,
  bl.product_id,
  COALESCE(bl.description, 'Line') AS name_snapshot,
  bl.meta->>'barcode' AS barcode_snapshot,
  bl.meta->>'product_code' AS product_code_snapshot,
  bl.quantity,
  bl.unit_price AS sell_price_amount,
  COALESCE((bl.meta->>'line_discount_amount')::numeric(12, 2), 0) AS line_discount_amount,
  bl.line_total AS line_total_amount,
  COALESCE((bl.meta->>'return_quantity')::numeric(12, 3), 0) AS return_quantity,
  bl.created_at,
  bl.created_at AS updated_at,
  CASE WHEN (bl.meta ? 'assigned_child_tenant_id')
    THEN (bl.meta->>'assigned_child_tenant_id')::bigint ELSE NULL END AS assigned_child_tenant_id,
  COALESCE(bl.meta, '{}'::jsonb) AS line_meta,
  CASE bl.item_kind
    WHEN 'stock' THEN 'stock'
    WHEN 'charge' THEN 'charge'
    ELSE 'description'
  END::text AS line_kind,
  upper(COALESCE(b.currency_code, 'BDT')) AS currency_code,
  bl.line_total AS books_amount,
  bl.global_stock_id
FROM money_kernel.bill_lines bl
JOIN money_kernel.bills b ON b.id = bl.bill_id;

CREATE OR REPLACE VIEW public.global_invoice_items
WITH (security_invoker = true)
AS
SELECT
  id,
  tenant_id,
  invoice_id,
  COALESCE(
    global_stock_id,
    ((line_meta -> 'stock_ref') ->> 'global_stock_id')::bigint
  ) AS global_stock_id,
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

CREATE OR REPLACE FUNCTION public.get_bill_desk_row(p_bill_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_tenant_id bigint;
BEGIN
  SELECT tenant_id INTO v_tenant_id FROM money_kernel.bills WHERE id = p_bill_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'bill not found';
  END IF;
  RETURN public._get_bill_detail_bundle_from_kernel(v_tenant_id, p_bill_id)->'bill';
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_draft_bill_from_desk(p_bill_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_b money_kernel.bills;
BEGIN
  SELECT * INTO v_b FROM money_kernel.bills WHERE id = p_bill_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'bill not found';
  END IF;
  IF NOT public.user_can_manage_books_tenant(v_b.tenant_id) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;
  IF v_b.status IS DISTINCT FROM 'draft' THEN
    RAISE EXCEPTION 'Only draft bills can be deleted';
  END IF;
  DELETE FROM money_kernel.bill_lines WHERE bill_id = p_bill_id;
  DELETE FROM money_kernel.bills WHERE id = p_bill_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_open_ap_bills_for_profile(
  p_tenant_id bigint,
  p_profile_id bigint
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', kb.id,
    'invoice_no', kb.invoice_no,
    'due_amount', kb.due_amount,
    'total_amount', kb.total_amount,
    'ap_kind', COALESCE(kb.meta->>'ap_kind', NULL),
    'ap_shipment_id', CASE
      WHEN kb.source_type = 'shipment_cost' THEN NULLIF(BTRIM(kb.source_id), '')::bigint
      ELSE NULLIF(kb.meta->>'shipment_id', '')::bigint
    END,
    'note', kb.note,
    'channel_meta', COALESCE(kb.meta, '{}'::jsonb)
  ) ORDER BY kb.invoice_date, kb.id), '[]'::jsonb)
  FROM money_kernel.bills kb
  WHERE kb.tenant_id = public.resolve_books_tenant_id(p_tenant_id)
    AND public._desk_kernel_kind_invoice_type(kb.kind) = 'ap'
    AND kb.counterparty_profile_id = p_profile_id
    AND kb.status = 'issued'
    AND COALESCE(kb.due_amount, 0) > 0;
$$;

CREATE OR REPLACE FUNCTION public.list_ap_pay_profile_summaries(
  p_tenant_id bigint,
  p_search text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'profile_id', x.profile_id,
    'name', x.name,
    'profile_type', x.profile_type,
    'total_due', x.total_due
  ) ORDER BY x.total_due DESC), '[]'::jsonb)
  FROM (
    SELECT
      kb.counterparty_profile_id AS profile_id,
      pr.name,
      pr.profile_type,
      SUM(kb.due_amount) AS total_due
    FROM money_kernel.bills kb
    JOIN public.profiles pr ON pr.id = kb.counterparty_profile_id
    WHERE kb.tenant_id = public.resolve_books_tenant_id(p_tenant_id)
      AND public._desk_kernel_kind_invoice_type(kb.kind) = 'ap'
      AND kb.status = 'issued'
      AND COALESCE(kb.due_amount, 0) > 0
    GROUP BY kb.counterparty_profile_id, pr.name, pr.profile_type
    HAVING (
      p_search IS NULL OR BTRIM(p_search) = ''
      OR pr.name ILIKE '%' || BTRIM(p_search) || '%'
    )
  ) x;
$$;

GRANT SELECT ON public.bills TO authenticated, service_role;
GRANT SELECT ON public.bill_lines TO authenticated, service_role;
GRANT SELECT ON public.global_invoice_items TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_bill_desk_row(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.delete_draft_bill_from_desk(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.list_open_ap_bills_for_profile(bigint, bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.list_ap_pay_profile_summaries(bigint, text) TO authenticated, service_role;