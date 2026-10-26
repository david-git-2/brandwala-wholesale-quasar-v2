-- Allow deleting thrift stock after soft RETURN invoices.
-- ACTIVE invoice lines still block delete via delete_thrift_stocks RPC.
-- Returned / legacy STAFF_MISTAKE lines: stock_id set NULL on stock delete (history keeps prices).

ALTER TABLE public.thrift_sales_invoice_items
  ALTER COLUMN stock_id DROP NOT NULL;

ALTER TABLE public.thrift_sales_invoice_items
  DROP CONSTRAINT IF EXISTS thrift_sales_invoice_items_stock_id_fkey;

ALTER TABLE public.thrift_sales_invoice_items
  ADD CONSTRAINT thrift_sales_invoice_items_stock_id_fkey
  FOREIGN KEY (stock_id)
  REFERENCES public.thrift_stocks(id)
  ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION public.delete_thrift_stocks(
  p_tenant_id BIGINT,
  p_stock_ids BIGINT[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_blocked BIGINT;
  v_deleted INT;
BEGIN
  IF p_stock_ids IS NULL OR cardinality(p_stock_ids) = 0 THEN
    RETURN jsonb_build_object('deleted', 0);
  END IF;

  SELECT si.stock_id
  INTO v_blocked
  FROM public.thrift_sales_invoice_items si
  INNER JOIN public.thrift_sales_invoices inv
    ON inv.id = si.invoice_id
   AND inv.tenant_id = si.tenant_id
  WHERE si.tenant_id = p_tenant_id
    AND si.stock_id = ANY (p_stock_ids)
    AND coalesce(inv.status, 'ACTIVE') = 'ACTIVE'
  LIMIT 1;

  IF v_blocked IS NOT NULL THEN
    RAISE EXCEPTION
      'Cannot delete stock %: it is on an active sales invoice. Return or mark staff mistake first.',
      v_blocked;
  END IF;

  DELETE FROM public.thrift_stocks
  WHERE tenant_id = p_tenant_id
    AND id = ANY (p_stock_ids);

  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  RETURN jsonb_build_object('deleted', v_deleted);
END;
$$;

REVOKE ALL ON FUNCTION public.delete_thrift_stocks(BIGINT, BIGINT[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_thrift_stocks(BIGINT, BIGINT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_thrift_stocks(BIGINT, BIGINT[]) TO service_role;
