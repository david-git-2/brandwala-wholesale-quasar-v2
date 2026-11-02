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
  profile_id: number;
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
  profile_id: number | null;
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

export type MonthSnapshotKpis = {
  net_sales: number;
  cogs: number;
  gross_profit: number;
  cash_collected: number;
  ar_outstanding: number;
  merchant_payable?: number;
};

export type MonthSnapshotPosition = {
  tenant_cash: number;
  courier_holding: number;
  ar_outstanding: number;
  cod_unremitted: number;
  ap_payable: number;
  merchant_payable: number;
  customer_store_credit: number;
  net_buffer: number;
};

export type MonthSnapshotReportPayload = {
  tenant_id: number;
  month: string;
  start_date: string;
  end_date: string;
  sales_by_invoice_type?: Record<string, number>;
  kpis: MonthSnapshotKpis;
  position?: MonthSnapshotPosition;
};
