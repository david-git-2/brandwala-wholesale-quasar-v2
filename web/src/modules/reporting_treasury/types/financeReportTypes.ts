export type FinanceReportPagination = {
  page: number;
  page_size: number;
  total_count: number | null;
};

export type CustomerDuesAging = {
  current: number;
  d1_30: number;
  d31_60: number;
  d61_90: number;
  d90_plus: number;
};

export type CustomerDuesRow = {
  billing_profile_id: number;
  name: string;
  phone: string | null;
  credit_limit: number | null;
  billed: number;
  returned: number;
  collected_cash: number;
  wallet_applied: number;
  settlement: number;
  still_due: number;
  oldest_due_date: string | null;
  aging: CustomerDuesAging;
  open_invoice_count: number;
};

export type CustomerDuesTotals = {
  billed: number;
  returned: number;
  collected_cash: number;
  wallet_applied: number;
  settlement: number;
  still_due: number;
  customer_count: number;
};

export type CustomerDuesReportPayload = {
  totals: CustomerDuesTotals;
  rows: CustomerDuesRow[];
  page: number;
  page_size: number;
  total_count: number | null;
};

export type InvoiceBookRow = {
  id: number;
  invoice_no: string;
  invoice_date: string;
  invoice_type: string;
  payment_status: string;
  customer_name: string;
  billing_profile_id: number | null;
  issued_by_name: string | null;
  billed: number;
  returned: number;
  collected_cash: number;
  wallet_applied: number;
  settlement: number;
  still_due: number;
};

export type InvoiceBookTotals = {
  billed: number;
  returned: number;
  collected_cash: number;
  wallet_applied: number;
  settlement: number;
  still_due: number;
  invoice_count: number;
};

export type InvoiceBookReportPayload = {
  totals: InvoiceBookTotals;
  rows: InvoiceBookRow[];
  page: number;
  page_size: number;
  total_count: number | null;
};

export type InvoiceProfitRow = {
  id: number;
  invoice_no: string;
  invoice_date: string;
  customer_name: string;
  net_qty: number;
  net_revenue: number;
  cogs: number;
  realized_gp: number;
  gp_margin_pct: number;
};

export type InvoiceProfitLine = {
  item_id: number;
  name: string;
  barcode: string | null;
  quantity: number;
  return_quantity: number;
  net_qty: number;
  sell_price_amount: number;
  unit_cost_price: number;
  net_revenue: number;
  cogs: number;
  line_gp: number;
};

export type InvoiceProfitTotals = {
  net_sold_qty: number;
  net_revenue: number;
  cogs: number;
  realized_gp: number;
  gp_margin_pct: number;
  invoice_count: number;
};

export type InvoiceProfitReportPayload = {
  totals: InvoiceProfitTotals;
  rows: InvoiceProfitRow[];
  lines?: InvoiceProfitLine[];
  page: number;
  page_size: number;
  total_count: number | null;
};

export type WalletLiabilityRow = {
  billing_profile_id: number;
  name: string;
  phone: string | null;
  credit_issued: number;
  credit_applied: number;
  outstanding: number;
};

export type WalletLiabilityTotals = {
  credit_issued: number;
  credit_applied: number;
  outstanding: number;
  customer_count: number;
};

export type WalletLiabilityReportPayload = {
  totals: WalletLiabilityTotals;
  rows: WalletLiabilityRow[];
  page: number;
  page_size: number;
  total_count: number | null;
};

export type CourierCodOrderRow = {
  order_id: number;
  order_no: string;
  awb: string | null;
  cod_collect_amount: number;
  remittance_ref: string | null;
  delivered_at: string | null;
};

export type CourierCodRow = {
  courier_service_id: string | null;
  courier_name: string;
  delivered_cod: number;
  remitted: number;
  unremitted: number;
  short_over: number;
  order_count: number;
};

export type CourierCodTotals = {
  delivered_cod: number;
  remitted: number;
  unremitted: number;
  short_over: number;
  order_count: number;
};

export type CourierCodReportPayload = {
  totals: CourierCodTotals;
  rows: CourierCodRow[];
  orders?: CourierCodOrderRow[];
  page: number;
  page_size: number;
  total_count: number | null;
};

export type MonthSnapshotKpis = {
  net_sales: number;
  cogs: number;
  gross_profit: number;
  cash_collected: number;
  ar_outstanding: number;
  wallet_liability: number;
  unsold_stock_value: number;
};

export type MonthSnapshotReportPayload = {
  tenant_id: number;
  month: string;
  start_date: string;
  end_date: string;
  kpis: MonthSnapshotKpis;
};
