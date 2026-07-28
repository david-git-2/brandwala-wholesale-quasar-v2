export const shopOrderQueryKeys = {
  categories: (tenantId: number) => ['shopOrder', 'categories', { tenantId }] as const,
  staffOrders: (params: { tenantId: number; search?: string | null; status?: string | null; shopId?: number | null }) =>
    ['shopOrder', 'staffOrders', params] as const,
  shopsList: (params: { tenantId: number; search?: string | null; active?: boolean | null }) =>
    ['shopOrder', 'shops', params] as const,
  customerShops: (tenantId: number | null) => ['shopOrder', 'customerShops', { tenantId }] as const,
  vendorsList: (tenantId: number) => ['vendor', 'list', { tenantId }] as const,
  activeCarts: (tenantId: number) => ['shopOrder', 'activeCarts', { tenantId }] as const,
  cart: (tenantId: number, shopId: number) => ['shopOrder', 'cart', { tenantId, shopId }] as const,
  storefrontCatalog: (shopSlug: string, filters: { search?: string | null; category?: string | null; brand?: string | null; limit?: number; offset?: number }) =>
    ['shopOrder', 'storefrontCatalog', { shopSlug, ...filters }] as const,
  brandOptions: (params: { vendorCode?: string | null; tenantId?: number | null }) =>
    ['shopOrder', 'brandOptions', params] as const,
  categoryOptions: (params: { vendorCode?: string | null; tenantId?: number | null }) =>
    ['shopOrder', 'categoryOptions', params] as const,
  pricingListings: (shopId: number) => ['shopOrder', 'pricingListings', { shopId }] as const,
  pricingCandidates: (tenantId: number, shopId: number) => ['shopOrder', 'pricingCandidates', { tenantId, shopId }] as const,
  currencies: () => ['shopOrder', 'currencies'] as const,
  pricingRule: (shopId: number) => ['shopOrder', 'pricingRule', { shopId }] as const,
  customerOrders: (shopId: number) => ['shopOrder', 'customerOrders', { shopId }] as const,
  customerDashboardOrders: (shopIds: number[]) =>
    ['shopOrder', 'customerDashboardOrders', { shopIds: [...shopIds].sort((a, b) => a - b) }] as const,
  orderDetail: (orderId: number) => ['shopOrder', 'orderDetail', { orderId }] as const,
  shopCurrenciesMap: (shopIds: number[]) =>
    ['shopOrder', 'shopCurrenciesMap', { shopIds: [...shopIds].sort((a, b) => a - b) }] as const,
  courierRemittances: (params: { tenantId: number; courierServiceId?: string | null; status?: string | null }) =>
    ['courier-remittances', params.tenantId, { courierServiceId: params.courierServiceId ?? null, status: params.status ?? null }] as const,
  courierRemittanceDetail: (tenantId: number, batchId: number) =>
    ['courier-remittance-detail', tenantId, batchId] as const,
  deliveredOrdersUnremitted: (tenantId: number, courierServiceId: string) =>
    ['delivered-orders-unremitted', tenantId, courierServiceId] as const,
  courierHoldingSummary: (tenantId: number) => ['courier-holding-summary', { tenantId }] as const,
  merchantPayouts: (tenantId: number) => ['merchant-payouts', { tenantId }] as const,
};




