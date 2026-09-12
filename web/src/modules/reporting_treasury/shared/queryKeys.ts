export const financeReportQueryKeys = {
  root: ['finance'] as const,
  customerDues: (tenantId: number, filters: Record<string, unknown>) =>
    ['finance', 'customerDues', tenantId, filters] as const,
  invoiceBook: (tenantId: number, filters: Record<string, unknown>) =>
    ['finance', 'invoiceBook', tenantId, filters] as const,
  invoiceProfit: (tenantId: number, filters: Record<string, unknown>) =>
    ['finance', 'invoiceProfit', tenantId, filters] as const,
  walletLiability: (tenantId: number, filters: Record<string, unknown>) =>
    ['finance', 'walletLiability', tenantId, filters] as const,
  courierCod: (tenantId: number, filters: Record<string, unknown>) =>
    ['finance', 'courierCod', tenantId, filters] as const,
  monthSnapshot: (tenantId: number, month: string) =>
    ['finance', 'monthSnapshot', tenantId, month] as const,
};
