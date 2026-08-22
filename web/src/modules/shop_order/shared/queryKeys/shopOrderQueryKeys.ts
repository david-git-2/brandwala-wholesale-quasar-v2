export const shopOrderQueryKeys = {
  categories: (tenantId: number) => ['shopOrder', 'categories', { tenantId }] as const,
  staffOrders: (params: { tenantId: number; search?: string | null; status?: string | null; shopId?: number | null }) =>
    ['shopOrder', 'staffOrders', params] as const,
  shopsList: (params: { tenantId: number; search?: string | null; active?: boolean | null }) =>
    ['shopOrder', 'shops', params] as const,
  shopDetail: (tenantId: number, shopId: number) =>
    ['shopOrder', 'shop', { tenantId, shopId }] as const,
  customerShops: (tenantId: number | null) => ['shopOrder', 'customerShops', { tenantId }] as const,
  customerShopPermissions: (shopId: number) =>
    [...shopOrderQueryKeys.root, 'customerShopPermissions', shopId] as const,
  vendorsList: (tenantId: number) => ['vendor', 'list', { tenantId }] as const,
  activeCarts: (tenantId: number) => ['shopOrder', 'activeCarts', { tenantId }] as const,
  cart: (tenantId: number, shopId: number) => ['shopOrder', 'cart', { tenantId, shopId }] as const,
  storefrontCatalog: (
    tenantId: number,
    shopSlug: string,
    filters: {
      search?: string | null;
      category?: string | null;
      brand?: string | null;
      limit?: number;
      offset?: number;
    },
  ) => ['shopOrder', 'storefrontCatalog', { tenantId, shopSlug, ...filters }] as const,
  storefrontProduct: (tenantId: number, shopSlug: string, productId: number) =>
    ['shopOrder', 'storefrontProduct', { tenantId, shopSlug, productId }] as const,
  brandOptions: (params: { vendorCode?: string | null; tenantId?: number | null }) =>
    ['shopOrder', 'brandOptions', params] as const,
  categoryOptions: (params: { vendorCode?: string | null; tenantId?: number | null }) =>
    ['shopOrder', 'categoryOptions', params] as const,
  pricingListings: (shopId: number) => ['shopOrder', 'pricingListings', { shopId }] as const,
  pricingCandidates: (tenantId: number, shopId: number) =>
    ['shopOrder', 'pricingCandidates', { tenantId, shopId }] as const,
  currencies: () => ['shopOrder', 'currencies'] as const,
  pricingRule: (shopId: number) => ['shopOrder', 'pricingRule', { shopId }] as const,
  customerOrders: (tenantId: number, statusBucket?: string | null) =>
    ['shopOrder', 'customerOrders', { tenantId, statusBucket: statusBucket ?? null }] as const,
  customerDashboardOrders: (tenantId: number) =>
    ['shopOrder', 'customerDashboardOrders', { tenantId }] as const,
  orderDetailRoot: () => ['shopOrder', 'orderDetail'] as const,
  orderDetail: (tenantId: number | null, orderId: number) =>
    ['shopOrder', 'orderDetail', { tenantId, orderId }] as const,
  courierRemittances: (params: { tenantId: number; courierServiceId?: string | null; status?: string | null }) =>
    ['courier-remittances', params.tenantId, { courierServiceId: params.courierServiceId ?? null, status: params.status ?? null }] as const,
  courierRemittanceDetail: (tenantId: number, batchId: number) =>
    ['courier-remittance-detail', tenantId, batchId] as const,
  deliveredOrdersUnremitted: (tenantId: number, courierServiceId: string) =>
    ['delivered-orders-unremitted', tenantId, courierServiceId] as const,
  courierHoldingSummary: (tenantId: number) => ['courier-holding-summary', { tenantId }] as const,
  merchantPayouts: (tenantId: number) => ['merchant-payouts', { tenantId }] as const,
  root: ['shop_order'] as const,
  detail: (tenantSlug: string | null, orderId: number) =>
    [...shopOrderQueryKeys.root, 'detail', tenantSlug ?? 'no-tenant', orderId] as const,
  couriers: (tenantSlug: string | null) =>
    [...shopOrderQueryKeys.root, 'couriers', tenantSlug ?? 'no-tenant'] as const,
  merchants: (tenantSlug: string | null) =>
    [...shopOrderQueryKeys.root, 'merchants', tenantSlug ?? 'no-tenant'] as const,
  ledger: (
    tenantSlug: string | null,
    filters: { memberId?: number | null; from?: string | null; to?: string | null } = {},
  ) =>
    [
      ...shopOrderQueryKeys.root,
      'ledger',
      tenantSlug ?? 'no-tenant',
      {
        memberId: filters.memberId ?? null,
        from: filters.from ?? null,
        to: filters.to ?? null,
      },
    ] as const,
  ledgerPendingCod: (tenantSlug: string | null) =>
    [...shopOrderQueryKeys.root, 'ledger_pending_cod', tenantSlug ?? 'no-tenant'] as const,
  ledgerRemittanceOrders: (tenantSlug: string | null) =>
    [...shopOrderQueryKeys.root, 'ledger_remittance_orders', tenantSlug ?? 'no-tenant'] as const,
  financeHub: (tenantSlug: string | null) =>
    [...shopOrderQueryKeys.root, 'finance_hub', tenantSlug ?? 'no-tenant'] as const,
  readiness: (shopId: number) => [...shopOrderQueryKeys.root, 'readiness', shopId] as const,
  merchantWalletSummary: (tenantId: number) =>
    [...shopOrderQueryKeys.root, 'merchant_wallet_summary', tenantId] as const,
  merchantWalletLedger: (tenantId: number) =>
    [...shopOrderQueryKeys.root, 'merchant_wallet_ledger', tenantId] as const,
};
