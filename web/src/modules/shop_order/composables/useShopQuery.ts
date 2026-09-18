import { useQuery, useInfiniteQuery, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import { vendorRepository } from 'src/modules/vendor/repositories/vendorRepository';

export interface ShopListQueryParams {
  tenantId: number;
  parentTenantId?: number | null;
  search?: string | null;
  active?: boolean | null;
}

export function useShopDetailQuery(tenantId: Ref<number>, shopId: Ref<number>) {
  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.shopDetail(tenantId.value, shopId.value)),
    queryFn: () => shopOrderRepository.getShop(shopId.value, tenantId.value),
    staleTime: 2 * 60 * 1000,
    enabled: computed(() => !!tenantId.value && !!shopId.value),
  });
}

export function useShopListQuery(params: Ref<ShopListQueryParams>, enabled?: Ref<boolean>) {
  const enabledRef = enabled ?? computed(() => true);
  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.shopsList(params.value)),
    queryFn: () =>
      shopOrderRepository.listShops(params.value.tenantId, {
        parentTenantId: params.value.parentTenantId ?? null,
        search: params.value.search ?? null,
        active: params.value.active ?? null,
      }),
    staleTime: 2 * 60 * 1000,
    placeholderData: keepPreviousData,
    enabled: computed(() => enabledRef.value && !!params.value.tenantId),
  });
}

export function useInfiniteShopListQuery(
  params: Ref<ShopListQueryParams>,
  pageSize = 20,
  enabled?: Ref<boolean>,
) {
  const enabledRef = enabled ?? computed(() => true);

  const query = useInfiniteQuery({
    queryKey: computed(() => [
      ...shopOrderQueryKeys.root,
      'shops-infinite',
      params.value.tenantId,
      params.value.parentTenantId ?? null,
      params.value.search ?? null,
      params.value.active ?? null,
      pageSize,
    ]),
    queryFn: async ({ pageParam = 0 }) => {
      if (!params.value.tenantId) {
        return { data: [], total: 0, nextOffset: undefined };
      }
      const data = await shopOrderRepository.listShops(params.value.tenantId, {
        parentTenantId: params.value.parentTenantId ?? null,
        search: params.value.search ?? null,
        active: params.value.active ?? null,
        limit: pageSize,
        offset: pageParam as number,
      });

      const total = data[0]?.total_count ?? data.length;
      const nextOffset = (pageParam as number) + data.length;

      return {
        data,
        total,
        nextOffset: nextOffset < total ? nextOffset : undefined,
      };
    },
    getNextPageParam: (lastPage) => lastPage.nextOffset,
    initialPageParam: 0,
    staleTime: 2 * 60 * 1000,
    placeholderData: keepPreviousData,
    enabled: computed(() => enabledRef.value && !!params.value.tenantId),
  });

  const shops = computed<Shop[]>(() => {
    const pages = query.data.value?.pages ?? [];
    const seen = new Set<number>();
    const items: Shop[] = [];
    for (const p of pages) {
      for (const s of p.data) {
        if (!seen.has(s.id)) {
          seen.add(s.id);
          items.push(s);
        }
      }
    }
    return items;
  });

  const totalShops = computed<number>(() => {
    return query.data.value?.pages[0]?.total ?? shops.value.length;
  });

  return {
    ...query,
    shops,
    totalShops,
  };
}

export function useVendorListQuery(tenantId: Ref<number>) {
  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.vendorsList(tenantId.value)),
    queryFn: () => vendorRepository.listVendors(tenantId.value),
    staleTime: 5 * 60 * 1000,
    enabled: computed(() => !!tenantId.value),
  });
}

export function useCustomerShopsQuery(tenantId: Ref<number | null>) {
  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.customerShops(tenantId.value)),
    queryFn: () => {
      if (!tenantId.value) return Promise.resolve([]);
      return shopOrderRepository.listCustomerShops(tenantId.value);
    },
    staleTime: 2 * 60 * 1000,
    enabled: computed(() => !!tenantId.value),
  });
}
