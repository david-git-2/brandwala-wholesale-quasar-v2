import { ref, computed, watch } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { financeReportsRepository } from '../repositories/financeReportsRepository';
import { financeReportQueryKeys } from '../shared/queryKeys';

export function useCustomerDuesReport() {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.selectedTenant?.id ?? null);
  const searchText = ref('');
  const debouncedSearch = ref('');
  const agingBucket = ref<string | null>(null);
  const minDue = ref(0);
  const overLimitOnly = ref(false);
  const page = ref(1);
  const pageSize = ref(50);

  let searchTimer: ReturnType<typeof setTimeout> | undefined;
  watch(searchText, (val) => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => {
      debouncedSearch.value = val.trim();
      page.value = 1;
    }, 300);
  });

  watch([agingBucket, minDue, overLimitOnly], () => {
    page.value = 1;
  });

  const queryParams = computed(() => ({
    tenantId: tenantId.value || 0,
    search: debouncedSearch.value || null,
    agingBucket: agingBucket.value,
    minDue: minDue.value,
    overLimitOnly: overLimitOnly.value,
    page: page.value,
    pageSize: pageSize.value,
  }));

  const reportQuery = useQuery({
    queryKey: computed(() =>
      tenantId.value
        ? financeReportQueryKeys.customerDues(tenantId.value, queryParams.value)
        : financeReportQueryKeys.root,
    ),
    queryFn: () => financeReportsRepository.fetchCustomerDuesReport(queryParams.value),
    enabled: computed(() => Boolean(tenantId.value && tenantId.value > 0)),
    staleTime: 30_000,
  });

  return {
    totals: computed(() => reportQuery.data.value?.totals ?? null),
    rows: computed(() => reportQuery.data.value?.rows ?? []),
    isLoading: reportQuery.isLoading,
    error: computed(() => (reportQuery.error.value as Error | null)?.message ?? null),
    searchText,
    agingBucket,
    minDue,
    overLimitOnly,
    page,
    pageSize,
    exportCsv: () => {
      if (reportQuery.data.value) financeReportsRepository.exportCustomerDuesCsv(reportQuery.data.value);
    },
    refetch: () => reportQuery.refetch(),
  };
}
