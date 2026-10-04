export const billsQueryKeys = {
  root: ['bills_pays'] as const,
  list: (parentTenantId: number | null, params: Record<string, unknown>) =>
    [...billsQueryKeys.root, 'list', parentTenantId ?? 0, params] as const,
  detail: (billId: number | null) => [...billsQueryKeys.root, 'detail', billId ?? 0] as const,
  items: (billId: number | null) => [...billsQueryKeys.root, 'items', billId ?? 0] as const,
};
