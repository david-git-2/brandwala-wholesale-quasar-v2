import { computed, ref } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import { cashInReportRepository } from '../repositories/cashInReportRepository';

export function useCashInReport() {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.selectedTenant?.id ?? null);

  const preset = ref<'today' | 'week' | 'month' | 'custom'>('today');
  const startDate = ref<string | null>(null);
  const endDate = ref<string | null>(null);
  const selectedMethod = ref<string | null>(null);

  const now = new Date();
  const todayStr = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString().slice(0, 10);
  startDate.value = todayStr;
  endDate.value = todayStr;

  const isEnabled = computed(() => Boolean(tenantId.value && tenantId.value > 0));

  const queryParams = computed(() => {
    let startIso: string | null = null;
    let endIso: string | null = null;

    if (startDate.value) {
      const s = new Date(startDate.value);
      s.setHours(0, 0, 0, 0);
      startIso = s.toISOString();
    }
    if (endDate.value) {
      const e = new Date(endDate.value);
      e.setHours(23, 59, 59, 999);
      endIso = e.toISOString();
    }

    return {
      tenantId: tenantId.value || 0,
      startDate: startIso,
      endDate: endIso,
    };
  });

  const query = useQuery({
    queryKey: computed(() => ['reporting_treasury', 'cashIn', queryParams.value] as const),
    queryFn: () => cashInReportRepository.fetchCashInReport(queryParams.value),
    enabled: isEnabled,
    staleTime: 1000 * 30,
  });

  function setPreset(p: 'today' | 'week' | 'month' | 'custom') {
    preset.value = p;
    const current = new Date();
    if (p === 'today') {
      const s = new Date(current.getFullYear(), current.getMonth(), current.getDate());
      startDate.value = s.toISOString().slice(0, 10);
      endDate.value = current.toISOString().slice(0, 10);
    } else if (p === 'week') {
      const s = new Date(current.getTime() - 7 * 24 * 60 * 60 * 1000);
      startDate.value = s.toISOString().slice(0, 10);
      endDate.value = current.toISOString().slice(0, 10);
    } else if (p === 'month') {
      const s = new Date(current.getFullYear(), current.getMonth(), 1);
      startDate.value = s.toISOString().slice(0, 10);
      endDate.value = current.toISOString().slice(0, 10);
    }
  }

  const filteredEntries = computed(() => {
    const all = query.data.value?.entries || [];
    if (!selectedMethod.value) return all;
    return all.filter((e) => e.method === selectedMethod.value);
  });

  function exportCsv() {
    if (query.data.value) {
      cashInReportRepository.exportCashInToCsv(query.data.value);
    }
  }

  return {
    report: computed(() => query.data.value ?? null),
    entries: filteredEntries,
    allEntries: computed(() => query.data.value?.entries || []),
    byMethod: computed(() => query.data.value?.by_method || []),
    cashInTotal: computed(() => query.data.value?.cash_in_total || 0),
    entryCount: computed(() => query.data.value?.entry_count || 0),
    isLoading: query.isLoading,
    isError: query.isError,
    error: query.error,
    preset,
    startDate,
    endDate,
    selectedMethod,
    setPreset,
    exportCsv,
    refetch: query.refetch,
  };
}
