import type { AfterSalesCaseListFilters } from '../types/afterSales.types';

export const afterSalesQueryKeys = {
  hub: (tenantId: number) => ['after_sales', 'hub', tenantId] as const,
  cases: (tenantId: number, params: AfterSalesCaseListFilters) =>
    ['after_sales', 'cases', tenantId, params] as const,
  case: (caseId: string) => ['after_sales', 'case', caseId] as const,
  policies: (tenantId: number) => ['after_sales', 'policies', tenantId] as const,
  policy: (policyId: string) => ['after_sales', 'policy', policyId] as const,
  caseByInvoice: (invoiceId: number) => ['after_sales', 'case-by-invoice', invoiceId] as const,
};
