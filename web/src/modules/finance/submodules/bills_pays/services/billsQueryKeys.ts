export const billsQueryKeys = {
  root: ['bills_pays'] as const,
  list: (tenantId: number | null, params: Record<string, unknown>) =>
    [...billsQueryKeys.root, 'list', tenantId ?? 0, params] as const,
  detail: (billId: number | null) => [...billsQueryKeys.root, 'detail', billId ?? 0] as const,
  detailBundle: (billId: number | null) =>
    [...billsQueryKeys.detail(billId), 'bundle'] as const,
  items: (billId: number | null) => [...billsQueryKeys.root, 'items', billId ?? 0] as const,
  paymentHistory: (billId: number | null) =>
    [...billsQueryKeys.root, 'paymentHistory', billId ?? 0] as const,
  adjustments: (billId: number | null) =>
    [...billsQueryKeys.root, 'adjustments', billId ?? 0] as const,
  brands: (tenantId: number | null) =>
    [...billsQueryKeys.root, 'brands', tenantId ?? 0] as const,
};
