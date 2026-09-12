import { ref, computed, watch } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { financeReportsRepository } from '../repositories/financeReportsRepository';
import { financeReportQueryKeys } from '../shared/queryKeys';
import { applyDatePreset, type DatePreset } from '../utils/datePresets';

export function useWalletLiabilityReport() {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.selectedTenant?.id ?? null);
  const preset = ref<DatePreset>('month');
  const startDate = ref<string | null>(null);
  const endDate = ref<string | null>(null);
  const searchText = ref('');
  const debouncedSearch = ref('');
  const page = ref(1);
  const pageSize = ref(50);

  const applyPreset = (val: DatePreset) => {
    preset.value = val;
    if (val === 'custom') return;
    const range = applyDatePreset(val);
    startDate.value = range.startDate;
    endDate.value = range.endDate;
    page.value = 1;
  };
  applyPreset('month');

  let searchTimer: ReturnType<typeof setTimeout> | undefined;
  watch(searchText, (val) => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => {
      debouncedSearch.value = val.trim();
      page.value = 1;
    }, 300);
  });

  const queryParams = computed(() => ({
    tenantId: tenantId.value || 0,
    startDate: startDate.value,
    endDate: endDate.value,
    search: debouncedSearch.value || null,
    page: page.value,
    pageSize: pageSize.value,
  }));

  const reportQuery = useQuery({
    queryKey: computed(() =>
      tenantId.value
        ? financeReportQueryKeys.walletLiability(tenantId.value, queryParams.value)
        : financeReportQueryKeys.root,
    ),
    queryFn: () => financeReportsRepository.fetchWalletLiabilityReport(queryParams.value),
    enabled: computed(() => Boolean(tenantId.value && tenantId.value > 0)),
    staleTime: 30_000,
  });

  return {
    totals: computed(() => reportQuery.data.value?.totals ?? null),
    rows: computed(() => reportQuery.data.value?.rows ?? []),
    isLoading: reportQuery.isLoading,
    error: computed(() => (reportQuery.error.value as Error | null)?.message ?? null),
    preset,
    startDate,
    endDate,
    searchText,
    setPreset: applyPreset,
    exportCsv: () => {
      if (reportQuery.data.value) financeReportsRepository.exportWalletLiabilityCsv(reportQuery.data.value);
    },
    refetch: () => reportQuery.refetch(),
  };
}
