export const procurementStockQueryKeys = {
  all: ['procurementStock'] as const,
  allocatableStockList: (params: {
    tenantId: number;
    page: number;
    pageSize: number;
    search?: string | null;
    shipmentId?: number | null;
    stockTypeId?: number | null;
  }) => ['procurementStock', 'allocatableStockList', params] as const,

  stockAllocations: (stockId: number) =>
    ['procurementStock', 'stockAllocations', { stockId }] as const,

  childTenants: (parentTenantId: number) =>
    ['procurementStock', 'childTenants', { parentTenantId }] as const,

  shipments: (tenantId: number) =>
    ['procurementStock', 'shipments', { tenantId }] as const,

  stockTypes: (tenantId: number) =>
    ['procurementStock', 'stockTypes', { tenantId }] as const,
};
