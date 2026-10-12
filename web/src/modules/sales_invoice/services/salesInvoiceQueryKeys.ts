export const salesInvoiceQueryKeys = {
  root: ['sales_invoice'] as const,
  list: (parentTenantId: number | null, params: Record<string, unknown>) =>
    [...salesInvoiceQueryKeys.root, 'list', parentTenantId ?? 0, params] as const,
  walletBalances: (tenantId: number | null) =>
    [...salesInvoiceQueryKeys.root, 'wallet_balances', tenantId ?? 0] as const,
  walletLedger: (tenantId: number | null, profileId: number | null) =>
    [...salesInvoiceQueryKeys.root, 'wallet_ledger', tenantId ?? 0, profileId ?? 0] as const,
  customerProfiles: (tenantId: number | null, params?: Record<string, unknown>) =>
    [...salesInvoiceQueryKeys.root, 'profiles', tenantId ?? 0, params ?? {}] as const,
  brands: (tenantId: number | null, params?: Record<string, unknown>) =>
    [...salesInvoiceQueryKeys.root, 'brands', tenantId ?? 0, params ?? {}] as const,
  stockSearch: (tenantId: number | null, search?: string) =>
    [...salesInvoiceQueryKeys.root, 'stock_search', tenantId ?? 0, search ?? ''] as const,
  dashboard: (tenantId: number) => [...salesInvoiceQueryKeys.root, 'dashboard', tenantId] as const,
};
