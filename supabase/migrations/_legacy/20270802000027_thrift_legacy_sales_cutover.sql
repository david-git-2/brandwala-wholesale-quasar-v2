-- Phase 21: Legacy sales cutover (light)
-- Only create_thrift_sales_invoice / revert_thrift_sales_invoice may sell/restore stock.
-- Leaves thrift_invoices / thrift_invoice_items as read-only archive (no row migrate/delete).
--
-- Rollback: re-grant EXECUTE on mark_thrift_items_as_sold; restore write policies +
-- INSERT/UPDATE/DELETE on the two legacy tables from 20260628000000_create_thrift_module.sql.

BEGIN;

-- 1) Revoke legacy sell RPC (keep function body for audit/rollback; no execute for API roles)
REVOKE ALL ON FUNCTION public.mark_thrift_items_as_sold(
  bigint,
  text,
  text,
  text,
  text,
  public.thrift_transaction_method,
  numeric,
  numeric,
  numeric,
  numeric,
  text,
  jsonb
) FROM PUBLIC;

REVOKE ALL ON FUNCTION public.mark_thrift_items_as_sold(
  bigint,
  text,
  text,
  text,
  text,
  public.thrift_transaction_method,
  numeric,
  numeric,
  numeric,
  numeric,
  text,
  jsonb
) FROM authenticated;

REVOKE ALL ON FUNCTION public.mark_thrift_items_as_sold(
  bigint,
  text,
  text,
  text,
  text,
  public.thrift_transaction_method,
  numeric,
  numeric,
  numeric,
  numeric,
  text,
  jsonb
) FROM anon;

COMMENT ON FUNCTION public.mark_thrift_items_as_sold(
  bigint,
  text,
  text,
  text,
  text,
  public.thrift_transaction_method,
  numeric,
  numeric,
  numeric,
  numeric,
  text,
  jsonb
) IS 'LEGACY ARCHIVE — execute revoked (P21). Use create_thrift_sales_invoice.';

-- 2) Freeze legacy invoice tables: select-only for authenticated
DROP POLICY IF EXISTS write_thrift_invoices ON public.thrift_invoices;
DROP POLICY IF EXISTS write_thrift_invoice_items ON public.thrift_invoice_items;

REVOKE INSERT, UPDATE, DELETE ON TABLE public.thrift_invoices FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.thrift_invoice_items FROM authenticated;

COMMENT ON TABLE public.thrift_invoices IS
  'LEGACY ARCHIVE — read-only (P21). Active sales use thrift_sales_invoices.';
COMMENT ON TABLE public.thrift_invoice_items IS
  'LEGACY ARCHIVE — read-only (P21). Active sales use thrift_sales_invoice_items.';

COMMIT;
