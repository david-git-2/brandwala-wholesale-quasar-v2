import { useInfiniteQuery, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import {
  billsRepository,
  type BillsListPageCursor,
  type ListBillsDeskPageParams,
} from '../repositories/billsRepository';
import type { BillListRow } from '../types/billList';
import { billsQueryKeys } from '../services/billsQueryKeys';

const BILLS_LIST_PAGE_SIZE = 25;

export type BillsListInfiniteQueryParams = ListBillsDeskPageParams;

export function useBillsListInfiniteQuery(params: Ref<BillsListInfiniteQueryParams>) {
  const query = useInfiniteQuery({
    queryKey: computed(() =>
      billsQueryKeys.list(params.value.parentTenantId, {
        issuedByTenantId: params.value.issuedByTenantId,
        arSide: params.value.arSide,
        invoiceStatus: params.value.invoiceStatus,
        paymentStatus: params.value.paymentStatus,
        quickFilter: params.value.quickFilter,
        search: params.value.search,
      }),
    ),
    queryFn: async ({ pageParam }) => {
      const cursor = (pageParam as BillsListPageCursor | undefined) ?? null;
      return billsRepository.listBillsPage(
        { ...params.value, pageSize: BILLS_LIST_PAGE_SIZE },
        cursor,
      );
    },
    getNextPageParam: (lastPage) =>
      lastPage.meta.has_more && lastPage.meta.next_cursor != null
        ? lastPage.meta.next_cursor
        : undefined,
    initialPageParam: null as BillsListPageCursor,
    staleTime: 30_000,
    placeholderData: keepPreviousData,
    enabled: computed(() => !!params.value.parentTenantId),
    refetchOnWindowFocus: false,
  });

  const rows = computed<BillListRow[]>(() => {
    const pages = query.data.value?.pages ?? [];
    const seen = new Set<number>();
    const items: BillListRow[] = [];
    for (const page of pages) {
      for (const row of page.data) {
        if (seen.has(row.id)) continue;
        seen.add(row.id);
        items.push(row);
      }
    }
    return items;
  });

  return {
    ...query,
    rows,
    hasMore: computed(() => query.hasNextPage.value),
  };
}
