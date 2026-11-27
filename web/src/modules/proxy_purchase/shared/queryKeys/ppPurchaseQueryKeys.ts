export const ppPurchaseQueryKeys = {
  customerRequests: (tenantId: number | null | undefined) =>
    ['pp-purchase-customer-requests', tenantId] as const,
  request: (tenantId: number | null | undefined, requestId: number | null | undefined) =>
    ['pp-purchase-request', tenantId, requestId] as const,
  requestLines: (tenantId: number | null | undefined, requestId: number | null | undefined) =>
    ['pp-purchase-request-lines', tenantId, requestId] as const,
  customerOrderLines: (tenantId: number | null | undefined) =>
    ['pp-purchase-customer-order-lines', tenantId] as const,
  staffRequests: (tenantId: number | null | undefined) =>
    ['pp-purchase-staff-requests', tenantId] as const,
  staffOrderLines: (tenantId: number | null | undefined) =>
    ['pp-purchase-staff-order-lines', tenantId] as const,
};