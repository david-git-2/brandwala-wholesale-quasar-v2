export const salesInvoiceQueryKeys = {
  root: ['sales_invoice'] as const,
  list: (parentTenantId: number | null, params: Record<string, any>) =>
    [...salesInvoiceQueryKeys.root, 'list', parentTenantId ?? 0, params] as const,
  walletBalances: (tenantId: number | null) =>
    [...salesInvoiceQueryKeys.root, 'wallet_balances', tenantId ?? 0] as const,
  walletLedger: (tenantId: number | null, billingProfileId: number | null) =>
    [...salesInvoiceQueryKeys.root, 'wallet_ledger', tenantId ?? 0, billingProfileId ?? 0] as const,
  billingProfiles: (tenantId: number | null, params?: Record<string, any>) =>
    [...salesInvoiceQueryKeys.root, 'billing_profiles', tenantId ?? 0, params ?? {}] as const,
  brands: (tenantId: number | null) =>
    [...salesInvoiceQueryKeys.root, 'brands', tenantId ?? 0] as const,
  stockSearch: (tenantId: number | null, search?: string) =>
    [...salesInvoiceQueryKeys.root, 'stock_search', tenantId ?? 0, search ?? ''] as const,
};


