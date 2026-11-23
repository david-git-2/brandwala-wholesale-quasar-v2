import { computed, reactive, type MaybeRefOrGetter, toValue } from 'vue';
import { useInfiniteQuery, useQuery, keepPreviousData } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { customersReportRepository } from '../repositories/customersReportRepository';
import { customersReportQueryKeys } from './useCustomersReportList';
import type {
  CustomerReportBillRow,
  CustomerReportLedgerRow,
  CustomerReportOrderRow,
  CustomerReportPaymentRow,
  CustomerReportSectionKind,
} from '../types/customersReportTypes';

const SECTION_PAGE_SIZE = 30;

export function useCustomerReportHeader(customerGroupId: MaybeRefOrGetter<number | null>) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.selectedTenant?.id ?? null);
  const groupId = computed(() => toValue(customerGroupId));

  const isEnabled = computed(
    () => Boolean(tenantId.value && tenantId.value > 0 && groupId.value && groupId.value > 0),
  );

  const headerQuery = useQuery({
    queryKey: computed(() =>
      customersReportQueryKeys.header(tenantId.value || 0, groupId.value || 0),
    ),
    queryFn: () =>
      customersReportRepository.fetchHeader(tenantId.value || 0, groupId.value || 0),
    enabled: isEnabled,
    staleTime: 1000 * 30,
  });

  return {
    header: computed(() => headerQuery.data.value ?? null),
    isLoading: headerQuery.isLoading,
    isFetching: headerQuery.isFetching,
    error: headerQuery.error,
    refetch: headerQuery.refetch,
  };
}

export function useCustomerReportSection(
  customerGroupId: MaybeRefOrGetter<number | null>,
  kind: CustomerReportSectionKind,
) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.selectedTenant?.id ?? null);
  const groupId = computed(() => toValue(customerGroupId));

  const isEnabled = computed(
    () => Boolean(tenantId.value && tenantId.value > 0 && groupId.value && groupId.value > 0),
  );

  const sectionQuery = useInfiniteQuery({
    queryKey: computed(() =>
      customersReportQueryKeys.section(tenantId.value || 0, groupId.value || 0, kind),
    ),
    queryFn: async ({ pageParam }) => {
      const cursor = (pageParam as string | undefined) ?? null;
      return customersReportRepository.fetchSection({
        tenantId: tenantId.value || 0,
        customerGroupId: groupId.value || 0,
        kind,
        limit: SECTION_PAGE_SIZE,
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

  const rows = computed(() => {
    const pages = sectionQuery.data.value?.pages ?? [];
    const out: unknown[] = [];
    const seen = new Set<string>();
    for (const page of pages) {
      for (const item of page.items ?? []) {
        const key = JSON.stringify(item);
        if (seen.has(key)) continue;
        seen.add(key);
        out.push(item);
      }
    }
    return out;
  });

  return reactive({
    rows: computed(() => {
      if (kind === 'payments') return rows.value as CustomerReportPaymentRow[];
      if (kind === 'orders') return rows.value as CustomerReportOrderRow[];
      if (kind === 'bills') return rows.value as CustomerReportBillRow[];
      return rows.value as CustomerReportLedgerRow[];
    }),
    isLoading: sectionQuery.isLoading,
    isFetching: sectionQuery.isFetching,
    error: sectionQuery.error,
    hasMore: computed(() => sectionQuery.hasNextPage.value),
    isLoadingMore: sectionQuery.isFetchingNextPage,
    fetchNextPage: sectionQuery.fetchNextPage,
    refetch: sectionQuery.refetch,
  });
}