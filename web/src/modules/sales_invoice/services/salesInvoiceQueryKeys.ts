export const salesInvoiceQueryKeys = {
  root: ['sales_invoice'] as const,
  list: (parentTenantId: number | null, params: Record<string, any>) =>
    [...salesInvoiceQueryKeys.root, 'list', parentTenantId ?? 0, params] as const,
  walletBalances: (tenantId: number | null) =>
    [...salesInvoiceQueryKeys.root, 'wallet_balances', tenantId ?? 0] as const,
  walletLedger: (tenantId: number | null, billingProfileId: number | null) =>
    [...salesInvoiceQueryKeys.root, 'wallet_ledger', tenantId ?? 0, billingProfileId ?? 0] as const,
};
