export const ppPurchaseQueryKeys = {
  customerRequests: (tenantId: number | null | undefined) =>
    ['pp-purchase-customer-requests', tenantId] as const,
  request: (tenantId: number | null | undefined, requestId: number | null | undefined) =>
    ['pp-purchase-request', tenantId, requestId] as const,
  requestLines: (tenantId: number | null | undefined, requestId: number | null | undefined) =>
    ['pp-purchase-request-lines', tenantId, requestId] as const,
};