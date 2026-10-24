import { useInfiniteQuery, keepPreviousData, useQueryClient } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import type { ShopOrder, StaffOrdersPageCursor, StaffOrdersPageShop } from '../types';

const STAFF_ORDERS_PAGE_SIZE = 30;

export interface ShopOrdersStaffPageQueryParams {
  tenantId: number;
  parentTenantId?: number | null;
  search?: string | null;
  status?: string | null;
  shopId?: number | null;
  shopType?: string | null;
}

export function useShopOrdersStaffPageQuery(params: Ref<ShopOrdersStaffPageQueryParams>) {
  const queryClient = useQueryClient();

  const query = useInfiniteQuery({
    queryKey: computed(() => shopOrderQueryKeys.staffOrdersPage(params.value)),
    queryFn: async ({ pageParam }) => {
      const cursor = (pageParam as StaffOrdersPageCursor | null) ?? null;
      return shopOrderRepository.listShopOrdersStaffPage(params.value.tenantId, {
        parentTenantId: params.value.parentTenantId ?? null,
        search: params.value.search ?? null,
        status: params.value.status ?? null,
        shopId: params.value.shopId ?? null,
        shopType: params.value.shopType ?? null,
        limit: STAFF_ORDERS_PAGE_SIZE,
        cursor,
      });
    },
    getNextPageParam: (lastPage) =>
      lastPage.meta.has_more && lastPage.meta.next_cursor ? lastPage.meta.next_cursor : undefined,
    initialPageParam: null as StaffOrdersPageCursor | null,
    staleTime: 60 * 1000,
    placeholderData: keepPreviousData,
    enabled: computed(() => !!params.value.tenantId),
    refetchOnWindowFocus: false,
  });

  const shops = computed<StaffOrdersPageShop[]>(() => {
    const first = query.data.value?.pages[0];
    return first?.shops ?? [];
  });

  const orders = computed<ShopOrder[]>(() => {
    const pages = query.data.value?.pages ?? [];
    const seen = new Set<number>();
    const items: ShopOrder[] = [];
    for (const page of pages) {
      for (const order of page.orders) {
        if (seen.has(order.id)) continue;
        seen.add(order.id);
        items.push(order);
      }
    }
    return items;
  });

  const isLoading = computed(
    () => query.isLoading.value || (query.isFetching.value && !query.data.value?.pages.length),
  );

  const isRefreshing = computed(
    () => query.isFetching.value && !query.isFetchingNextPage.value && !!query.data.value?.pages.length,
  );

  const refresh = async () => {
    await queryClient.resetQueries({
      queryKey: shopOrderQueryKeys.staffOrdersPage(params.value),
      exact: true,
    });
  };

  return {
    ...query,
    shops,
    orders,
    isLoading,
    isLoadingShops: isLoading,
    isLoadingOrders: isLoading,
    isRefreshing,
    refresh,
  };
}
