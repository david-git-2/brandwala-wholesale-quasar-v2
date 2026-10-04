export const cashbookQueryKeys = {
  root: ['bills_pays', 'cashbook'] as const,
  entities: (tenantId: number | null, entityType: string, params: Record<string, unknown>) =>
    [...cashbookQueryKeys.root, 'entities', tenantId ?? 0, entityType, params] as const,
  tenantCash: (tenantId: number | null, booksId: number | null) =>
    [...cashbookQueryKeys.root, 'tenant_cash', tenantId ?? 0, booksId ?? 0] as const,
  detail: (tenantId: number | null, entityType: string, entityId: number | null) =>
    [...cashbookQueryKeys.root, 'detail', tenantId ?? 0, entityType, entityId ?? 0] as const,
  ledger: (tenantId: number | null, entityType: string, entityId: number | null, params: Record<string, unknown>) =>
    [...cashbookQueryKeys.root, 'ledger', tenantId ?? 0, entityType, entityId ?? 0, params] as const,
};
