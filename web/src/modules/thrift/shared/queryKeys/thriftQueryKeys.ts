export const thriftQueryKeys = {
  categories: (tenantId: number) => ['thrift', 'categories', { tenantId }] as const,
  types: (tenantId: number) => ['thrift', 'types', { tenantId }] as const,
  boxes: (tenantId: number) => ['thrift', 'boxes', { tenantId }] as const,
  shelves: (tenantId: number) => ['thrift', 'shelves', { tenantId }] as const,
  currencies: () => ['thrift', 'currencies'] as const,
  settings: (tenantId: number) => ['thrift', 'settings', { tenantId }] as const,
  stocks: (params: object) => ['thrift', 'stocks', params] as const,
  barcodes: (params: object) => ['thrift', 'barcodes', params] as const,
  shipments: (tenantId: number) => ['thrift', 'shipments', { tenantId }] as const,
  shipmentDetail: (id: string) => ['thrift', 'shipment-detail', { id }] as const,
};
