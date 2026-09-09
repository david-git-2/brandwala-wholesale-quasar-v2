import { useInfiniteQuery, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import {
  PBC_ITEMS_PAGE_SIZE,
  productBasedCostingQueryKeys,
} from '../shared/queryKeys/productBasedCostingQueryKeys';
import { productBasedCostingRepository } from '../repositories/productBasedCostingRepository';
import type { ProductBasedCostingItem } from '../types';

export function useProductBasedCostingItemsInfiniteQuery(
  fileId: Ref<number>,
  pageSize = PBC_ITEMS_PAGE_SIZE,
) {
  const query = useInfiniteQuery({
    queryKey: computed(() => productBasedCostingQueryKeys.itemsInfinite(fileId.value, pageSize)),
    queryFn: async ({ pageParam = 1 }) =>
      productBasedCostingRepository.listProductBasedCostingItemsPaginated(fileId.value, {
        page: pageParam as number,
        page_size: pageSize,
      }),
    getNextPageParam: (lastPage) => {
      const { page, total_pages } = lastPage.meta;
      return page < total_pages ? page + 1 : undefined;
    },
    initialPageParam: 1,
    staleTime: 2 * 60 * 1000,
    placeholderData: keepPreviousData,
    enabled: computed(() => fileId.value > 0),
  });

  const costingItems = computed<ProductBasedCostingItem[]>(() => {
    const pages = query.data.value?.pages ?? [];
    const seen = new Set<number>();
    const items: ProductBasedCostingItem[] = [];
    for (const page of pages) {
      for (const item of page.data) {
        if (!seen.has(item.id)) {
          seen.add(item.id);
          items.push(item);
        }
      }
    }
    return items;
  });

  const totalItemsCount = computed(() => query.data.value?.pages?.[0]?.meta.total ?? 0);

  const hasMoreItems = computed(() => query.hasNextPage.value ?? false);

  return {
    ...query,
    costingItems,
    totalItemsCount,
    hasMoreItems,
  };
}
