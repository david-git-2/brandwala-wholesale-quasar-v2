import { computed, ref, watch } from 'vue';
import { useInfiniteQuery, keepPreviousData } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { customersReportRepository } from '../repositories/customersReportRepository';
import type { CustomersReportListRow } from '../types/customersReportTypes';

export const customersReportQueryKeys = {
  all: ['reporting_treasury', 'customers_report'] as const,
  list: (tenantId: number, search: string) =>
    ['reporting_treasury', 'customers_report', 'list', tenantId, search] as const,
  header: (tenantId: number, customerGroupId: number) =>
    ['reporting_treasury', 'customers_report', 'header', tenantId, customerGroupId] as const,
  section: (tenantId: number, customerGroupId: number, kind: string) =>
    ['reporting_treasury', 'customers_report', 'section', tenantId, customerGroupId, kind] as const,
};

const LIST_PAGE_SIZE = 30;

export function useCustomersReportList() {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.selectedTenant?.id ?? null);

  const searchText = ref('');
  const debouncedSearch = ref('');

  let searchTimer: ReturnType<typeof setTimeout> | undefined;
  watch(searchText, (value) => {
    if (searchTimer) clearTimeout(searchTimer);
    searchTimer = setTimeout(() => {
      debouncedSearch.value = value.trim();
    }, 300);
  });

  const isEnabled = computed(() => Boolean(tenantId.value && tenantId.value > 0));

  const listQuery = useInfiniteQuery({
    queryKey: computed(() =>
      customersReportQueryKeys.list(tenantId.value || 0, debouncedSearch.value),
    ),
    queryFn: async ({ pageParam }) => {
      const cursor = (pageParam as string | undefined) ?? null;
      return customersReportRepository.listCustomers({
        tenantId: tenantId.value || 0,
        search: debouncedSearch.value || null,
        limit: LIST_PAGE_SIZE,
        cursor,
      });
    },
    getNextPageParam: (lastPage) => lastPage.next_cursor ?? undefined,
    initialPageParam: null as string | null,
    enabled: isEnabled,
    staleTime: 1000 * 30,
    placeholderData: keepPreviousData,
    refetchOnWindowFocus: false,
  });

  const customers = computed<CustomersReportListRow[]>(() => {
    const pages = listQuery.data.value?.pages ?? [];
    const seen = new Set<number>();
    const rows: CustomersReportListRow[] = [];
    for (const page of pages) {
      for (const row of page.items ?? []) {
        if (seen.has(row.customer_group_id)) continue;
        seen.add(row.customer_group_id);
        rows.push(row);
      }
    }
    return rows;
  });

  return {
    customers,
    isLoading: listQuery.isLoading,
    isFetching: listQuery.isFetching,
    error: listQuery.error,
    searchText,
    hasMore: computed(() => listQuery.hasNextPage.value),
    isLoadingMore: listQuery.isFetchingNextPage,
    fetchNextPage: listQuery.fetchNextPage,
    refetch: listQuery.refetch,
  };
}