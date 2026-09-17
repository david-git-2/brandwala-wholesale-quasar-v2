/**
 * Reporting & Treasury Stubs & Mock Data Provider
 * Used for isolated financial report rendering and treasury dashboard testing.
 */

export interface MonthSnapshotStub {
  month: string;
  total_revenue_bdt: number;
  total_cogs_bdt: number;
  gross_profit_bdt: number;
  gross_margin_percent: number;
  cash_in_bdt: number;
  outstanding_ar_bdt: number;
  delivered_orders_count: number;
}

export const mockMonthSnapshot: MonthSnapshotStub = {
  month: '2026-09',
  total_revenue_bdt: 4850000.0,
  total_cogs_bdt: 3730000.0,
  gross_profit_bdt: 1120000.0,
  gross_margin_percent: 23.09,
  cash_in_bdt: 3400000.0,
  outstanding_ar_bdt: 890000.0,
  delivered_orders_count: 320,
};

export async function fetchMockMonthSnapshot(): Promise<MonthSnapshotStub> {
  await new Promise((resolve) => setTimeout(resolve, 150));
  return { ...mockMonthSnapshot };
}
