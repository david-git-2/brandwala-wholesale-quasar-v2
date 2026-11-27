-- Helper RPCs so frontend never queries public.bills or public.bill_lines views directly.

CREATE OR REPLACE FUNCTION public.get_bill_lines_for_bills(p_bill_ids bigint[])
RETURNS TABLE (
  id bigint,
  bill_id bigint,
  line_kind text,
  name_snapshot text,
  currency_code text,
  line_total_amount numeric,
  books_amount numeric,
  quantity numeric,
  sell_price_amount numeric,
  line_discount_amount numeric,
  line_meta jsonb
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
  SELECT
    bl.id,
    bl.bill_id,
    COALESCE(NULLIF(bl.item_kind, ''), 'stock') AS line_kind,
    COALESCE(bl.description, 'Line') AS name_snapshot,
    COALESCE(b.currency_code, 'BDT') AS currency_code,
    COALESCE(bl.line_total, 0) AS line_total_amount,
    COALESCE(
      NULLIF(bl.meta->>'books_amount', '')::numeric,
      bl.line_total,
      0
    ) AS books_amount,
    COALESCE(bl.quantity, 1) AS quantity,
    COALESCE(bl.unit_price, 0) AS sell_price_amount,
    COALESCE(NULLIF(bl.meta->>'line_discount_amount', '')::numeric, 0) AS line_discount_amount,
    bl.meta AS line_meta
  FROM money_kernel.bill_lines bl
  JOIN money_kernel.bills b ON b.id = bl.bill_id
  WHERE bl.bill_id = ANY(COALESCE(p_bill_ids, ARRAY[]::bigint[]))
  ORDER BY bl.id;
$$;

REVOKE ALL ON FUNCTION public.get_bill_lines_for_bills(bigint[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_bill_lines_for_bills(bigint[]) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_bills_source_plugs(p_bill_ids bigint[])
RETURNS TABLE (
  id bigint,
  ap_shipment_id bigint,
  source_type text,
  source_id text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
  SELECT
    b.id,
    NULLIF(b.meta->>'shipment_id', '')::bigint AS ap_shipment_id,
    b.source_type,
    b.source_id
  FROM money_kernel.bills b
  WHERE b.id = ANY(COALESCE(p_bill_ids, ARRAY[]::bigint[]));
$$;

REVOKE ALL ON FUNCTION public.get_bills_source_plugs(bigint[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_bills_source_plugs(bigint[]) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.check_shipment_bill_references(p_shipment_id bigint)
RETURNS text[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
  SELECT COALESCE(array_agg(DISTINCT b.invoice_no ORDER BY b.invoice_no), ARRAY[]::text[])
  FROM money_kernel.bill_lines bl
  JOIN money_kernel.bills b ON b.id = bl.bill_id
  JOIN public.global_shipment_items gsi ON gsi.id = bl.shipment_item_id
  WHERE gsi.shipment_id = p_shipment_id
    AND b.status <> 'voided'
    AND b.invoice_no IS NOT NULL;
$$;

REVOKE ALL ON FUNCTION public.check_shipment_bill_references(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_shipment_bill_references(bigint) TO authenticated, service_role;
