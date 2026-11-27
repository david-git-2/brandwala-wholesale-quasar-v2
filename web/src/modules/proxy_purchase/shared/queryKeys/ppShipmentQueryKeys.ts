export const ppShipmentQueryKeys = {
  all: ['pp-shipment'] as const,
  list: (tenantId: number | null) => [...ppShipmentQueryKeys.all, 'list', tenantId] as const,
};