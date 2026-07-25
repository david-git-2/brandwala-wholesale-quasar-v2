export const shopOrderQueryKeys = {
  categories: (tenantId: number) => ['shopOrder', 'categories', { tenantId }] as const,
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
};


