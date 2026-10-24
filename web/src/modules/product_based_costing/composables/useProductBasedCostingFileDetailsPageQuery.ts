import { useInfiniteQuery, keepPreviousData, useQueryClient } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import {
  PBC_ITEMS_PAGE_SIZE,
  productBasedCostingQueryKeys,
} from '../shared/queryKeys/productBasedCostingQueryKeys';
import { productBasedCostingRepository } from '../repositories/productBasedCostingRepository';
import type {
  PbcFileDetailsBundleCustomer,
  PbcItemProductCatalog,
  ProductBasedCostingFile,
  ProductBasedCostingItem,
  ProductBasedCostingItemsListCursor,
} from '../types';
import {
  emptyPbcFileSummaryMetrics,
  mapPbcFileSummaryFromRpc,
} from './usePbcFileSummaryMetrics';

export function useProductBasedCostingFileDetailsPageQuery(
  fileId: Ref<number>,
  pageSize = PBC_ITEMS_PAGE_SIZE,
) {
  const queryClient = useQueryClient();

  const query = useInfiniteQuery({
    queryKey: computed(() =>
      productBasedCostingQueryKeys.fileDetailsPage(fileId.value, pageSize),
    ),
    queryFn: async ({ pageParam }) =>
      productBasedCostingRepository.getProductBasedCostingFileDetailsBundle(fileId.value, {
        limit: pageSize,
        cursor: (pageParam as ProductBasedCostingItemsListCursor | null) ?? null,
      }),
    getNextPageParam: (lastPage) =>
      lastPage.items.meta.has_more && lastPage.items.meta.next_cursor
        ? lastPage.items.meta.next_cursor
        : undefined,
    initialPageParam: null as ProductBasedCostingItemsListCursor | null,
    staleTime: 2 * 60 * 1000,
    placeholderData: keepPreviousData,
    enabled: computed(() => fileId.value > 0),
    refetchOnWindowFocus: false,
  });

  const file = computed<ProductBasedCostingFile | null | undefined>(() => {
    const first = query.data.value?.pages[0];
    return first?.file ?? undefined;
  });

  const customerAccounts = computed<PbcFileDetailsBundleCustomer[]>(() => {
    return query.data.value?.pages[0]?.customers ?? [];
  });

  const summaryMetrics = computed(() => {
    const summary = query.data.value?.pages[0]?.summary;
    if (!summary) return emptyPbcFileSummaryMetrics();
    return mapPbcFileSummaryFromRpc(summary);
  });

  const costingItems = computed<ProductBasedCostingItem[]>(() => {
    const pages = query.data.value?.pages ?? [];
    const seen = new Set<number>();
    const items: ProductBasedCostingItem[] = [];
    for (const page of pages) {
      for (const item of page.items.data) {
        if (!seen.has(item.id)) {
          seen.add(item.id);
          items.push(item);
        }
      }
    }
    return items;
  });

  const catalogByProductId = computed(() => {
    const map = new Map<number, PbcItemProductCatalog>();
    for (const page of query.data.value?.pages ?? []) {
      for (const row of page.productCatalog) {
        const id = Number(row.product_id);
        if (!Number.isFinite(id) || id <= 0) continue;
        map.set(id, {
          languages: row.languages ?? null,
          country_of_origin: row.country_of_origin ?? null,
          available_units: row.available_units ?? null,
          batch_code_manufacture_date: row.batch_code_manufacture_date ?? null,
          expire_date: row.expire_date ?? null,
        });
      }
    }
    return map;
  });

  const hasMoreItems = computed(() => query.hasNextPage.value ?? false);

  const isLoadingFile = computed(
    () => query.isLoading.value || (query.isFetching.value && !query.data.value?.pages.length),
  );
  const isLoadingItems = isLoadingFile;

  const isRefreshing = computed(
    () => query.isFetching.value && !query.isFetchingNextPage.value && !!query.data.value?.pages.length,
  );

  const refresh = async () => {
    await queryClient.resetQueries({
      queryKey: productBasedCostingQueryKeys.fileDetailsPage(fileId.value, pageSize),
      exact: true,
    });
  };

  return {
    ...query,
    file,
    customerAccounts,
    summaryMetrics,
    costingItems,
    catalogByProductId,
    hasMoreItems,
    isLoadingFile,
    isLoadingItems,
    isFetchingMoreItems: query.isFetchingNextPage,
    fetchNextPage: query.fetchNextPage,
    isRefreshing,
    refresh,
  };
}
