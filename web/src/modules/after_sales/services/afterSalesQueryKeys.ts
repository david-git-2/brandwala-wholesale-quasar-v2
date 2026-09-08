import type { AfterSalesCaseListFilters } from '../types/afterSales.types';

export const afterSalesQueryKeys = {
  hub: (parentTenantId: number) => ['after_sales', 'hub', parentTenantId] as const,
  cases: (parentTenantId: number, params: AfterSalesCaseListFilters) =>
    ['after_sales', 'cases', parentTenantId, params] as const,
  case: (caseId: string) => ['after_sales', 'case', caseId] as const,
  policies: (parentTenantId: number) => ['after_sales', 'policies', parentTenantId] as const,
  policy: (policyId: string) => ['after_sales', 'policy', policyId] as const,
  caseByInvoice: (invoiceId: number) => ['after_sales', 'case-by-invoice', invoiceId] as const,
};
