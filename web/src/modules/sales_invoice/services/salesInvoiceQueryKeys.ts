export const salesInvoiceQueryKeys = {
  root: ['sales_invoice'] as const,
  list: (parentTenantId: number | null, params: Record<string, any>) =>
    [...salesInvoiceQueryKeys.root, 'list', parentTenantId ?? 0, params] as const,
};
