import { ref, computed } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { financeReportsRepository } from '../repositories/financeReportsRepository';
import { financeReportQueryKeys } from '../shared/queryKeys';
import { formatMonthLabel, monthFirstDay, shiftMonth } from '../utils/datePresets';

export function useMonthSnapshotReport() {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.selectedTenant?.id ?? null);
  const month = ref(monthFirstDay());

  const reportQuery = useQuery({
    queryKey: computed(() =>
      tenantId.value
        ? financeReportQueryKeys.monthSnapshot(tenantId.value, month.value)
        : financeReportQueryKeys.root,
    ),
    queryFn: () =>
      financeReportsRepository.fetchMonthSnapshotReport({
        tenantId: tenantId.value || 0,
        month: month.value,
      }),
    enabled: computed(() => Boolean(tenantId.value && tenantId.value > 0)),
    staleTime: 60_000,
  });

  return {
    kpis: computed(() => reportQuery.data.value?.kpis ?? null),
    month,
    monthLabel: computed(() => formatMonthLabel(month.value)),
    startDate: computed(() => reportQuery.data.value?.start_date ?? null),
    endDate: computed(() => reportQuery.data.value?.end_date ?? null),
    isLoading: reportQuery.isLoading,
    error: computed(() => (reportQuery.error.value as Error | null)?.message ?? null),
    prevMonth: () => {
      month.value = shiftMonth(month.value, -1);
    },
    nextMonth: () => {
      month.value = shiftMonth(month.value, 1);
    },
    thisMonth: () => {
      month.value = monthFirstDay();
    },
    exportCsv: () => {
      if (reportQuery.data.value) financeReportsRepository.exportMonthSnapshotCsv(reportQuery.data.value);
    },
    refetch: () => reportQuery.refetch(),
  };
}
