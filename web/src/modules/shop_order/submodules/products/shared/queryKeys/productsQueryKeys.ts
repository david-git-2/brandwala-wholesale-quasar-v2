export const productsQueryKeys = {
  all: ['products'] as const,
  lists: () => [...productsQueryKeys.all, 'list'] as const,
  list: (params: object) => [...productsQueryKeys.lists(), params] as const,
  detail: (id: number) => [...productsQueryKeys.all, 'detail', { id }] as const,
  brands: (params: { vendorCode?: string | null; tenantId?: number | null }) =>
    [...productsQueryKeys.all, 'brands', params] as const,
  categories: (params: { vendorCode?: string | null; tenantId?: number | null }) =>
    [...productsQueryKeys.all, 'categories', params] as const,
};
