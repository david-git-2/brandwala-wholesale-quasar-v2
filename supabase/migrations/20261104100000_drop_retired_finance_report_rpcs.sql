-- Retire finance hub reports: invoice profit, wallet liability, courier COD.
-- Product: REPORTS_PLAN.md (five reports); GP = shipment P&L only.

DROP FUNCTION IF EXISTS public.get_tenant_invoice_profit_report(
  bigint, date, date, text, text, bigint, bigint, integer, integer, boolean
);

DROP FUNCTION IF EXISTS public.get_tenant_wallet_liability_report(
  bigint, date, date, text, integer, integer, boolean
);

DROP FUNCTION IF EXISTS public.get_tenant_courier_cod_report(
  bigint, date, date, uuid, integer, integer, boolean
);
