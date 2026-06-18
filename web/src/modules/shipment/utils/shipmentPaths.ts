export const SHIPMENT_ROUTE_SEGMENT = 'global/shipment'

export const buildShipmentListPath = (tenantSlug?: string | null) =>
  tenantSlug ? `/${tenantSlug}/app/${SHIPMENT_ROUTE_SEGMENT}` : `/app/${SHIPMENT_ROUTE_SEGMENT}`

export const buildShipmentDetailPath = (tenantSlug: string | null | undefined, shipmentId: number | string) =>
  `${buildShipmentListPath(tenantSlug)}/${shipmentId}`

export const buildShipmentBatchCodePath = (
  tenantSlug: string | null | undefined,
  shipmentId: number | string,
) => `${buildShipmentDetailPath(tenantSlug, shipmentId)}/batch-code-pc`
