export const dropshipFinanceQueryKeys = {
  all: ['dropship-finance-hub'] as const,
  hubData: (tenantId: number) => [...dropshipFinanceQueryKeys.all, 'hub-data', tenantId] as const,
};
