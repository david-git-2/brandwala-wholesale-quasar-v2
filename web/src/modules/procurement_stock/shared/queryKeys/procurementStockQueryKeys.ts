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

  stockLocations: (tenantId: number, includeInactive?: boolean) =>
    ['procurementStock', 'stockLocations', { tenantId, includeInactive }] as const,

  cargoCompanies: (tenantId: number, includeInactive?: boolean) =>
    ['procurementStock', 'cargoCompanies', { tenantId, includeInactive }] as const,

  shipmentCostEntries: (shipmentId: number) =>
    ['procurementStock', 'shipmentCostEntries', { shipmentId }] as const,

  progressFlows: (tenantId: number, includeArchived?: boolean) =>
    ['procurementStock', 'progressFlows', { tenantId, includeArchived }] as const,

  progressStages: (flowId: number, includeArchived?: boolean) =>
    ['procurementStock', 'progressStages', { flowId, includeArchived }] as const,

  shipmentOverview: (shipmentId: number) =>
    ['procurementStock', 'shipmentOverview', { shipmentId }] as const,

  childStockAtp: (params: {
    childTenantId: number;
    search?: string | null;
    limit?: number;
    offset?: number;
  }) => ['procurementStock', 'childStockAtp', params] as const,
};