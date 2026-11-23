export interface CashInReportParams {
  tenantId: number;
  startDate?: string | null;
  endDate?: string | null;
}

export interface CashInByMethodSummary {
  method: string;
  amount: number;
  count: number;
}

export interface CashInReportEntry {
  id: string;
  amount: number;
  method: string;
  source_type: string;
  source_id: string | null;
  label: string | null;
  invoice_id: number | null;
  created_at: string;
}

export interface TenantCashInReport {
  tenant_id: number;
  start_date: string | null;
  end_date: string | null;
  cash_in_total: number;
  entry_count: number;
  by_method: CashInByMethodSummary[];
  entries: CashInReportEntry[];
}
