import { ref, computed, toValue, type MaybeRefOrGetter } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { walletReportsRepository } from '../repositories/walletReportsRepository';
import { walletQueryKeys } from '../shared/queryKeys/walletQueryKeys';
import type { UniversalWalletEntityType, WalletEntityStatement } from '../types';

export function useWalletReports(
  entityTypeInput: MaybeRefOrGetter<UniversalWalletEntityType>,
  entityIdInput: MaybeRefOrGetter<number>,
) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.selectedTenant?.id ?? null);
  const entityType = computed(() => toValue(entityTypeInput));
  const entityId = computed(() => toValue(entityIdInput));

  const startDate = ref<string | null>(null);
  const endDate = ref<string | null>(null);

  const isEnabled = computed(() => {
    return Boolean(
      tenantId.value &&
        tenantId.value > 0 &&
        entityType.value &&
        entityId.value !== undefined &&
        entityId.value !== null &&
        entityId.value > 0,
    );
  });

  const statementParams = computed(() => ({
    tenantId: tenantId.value || 0,
    entityType: entityType.value,
    entityId: entityId.value || 0,
    startDate: startDate.value ? new Date(startDate.value).toISOString() : null,
    endDate: endDate.value ? new Date(endDate.value).toISOString() : null,
  }));

  const statementQuery = useQuery<WalletEntityStatement, Error>({
    queryKey: computed(() => walletQueryKeys.statement(statementParams.value)),
    queryFn: () => walletReportsRepository.fetchEntityStatement(statementParams.value),
    enabled: isEnabled,
    staleTime: 1000 * 60 * 2,
  });

  function exportCsv(entityName: string) {
    if (statementQuery.data.value) {
      walletReportsRepository.exportStatementToCsv(statementQuery.data.value, entityName);
    }
  }

  function setDateRange(preset: 'today' | 'week' | 'month' | 'all') {
    const now = new Date();
    if (preset === 'today') {
      const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      startDate.value = start.toISOString().slice(0, 10);
      endDate.value = now.toISOString().slice(0, 10);
    } else if (preset === 'week') {
      const start = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      startDate.value = start.toISOString().slice(0, 10);
      endDate.value = now.toISOString().slice(0, 10);
    } else if (preset === 'month') {
      const start = new Date(now.getFullYear(), now.getMonth(), 1);
      startDate.value = start.toISOString().slice(0, 10);
      endDate.value = now.toISOString().slice(0, 10);
    } else {
      startDate.value = null;
      endDate.value = null;
    }
  }

  return {
    statement: computed(() => statementQuery.data.value ?? null),
    isLoading: statementQuery.isLoading,
    isError: statementQuery.isError,
    error: statementQuery.error,
    startDate,
    endDate,
    setDateRange,
    exportCsv,
    refetch: statementQuery.refetch,
  };
}

export function useCashInReport() {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.selectedTenant?.id ?? null);

  const preset = ref<'today' | 'week' | 'month' | 'custom'>('today');
  const startDate = ref<string | null>(null);
  const endDate = ref<string | null>(null);
  const selectedMethod = ref<string | null>(null);

  // Initialize today by default
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
    queryKey: computed(() => walletQueryKeys.cashIn(queryParams.value)),
    queryFn: () => walletReportsRepository.fetchCashInReport(queryParams.value),
    enabled: isEnabled,
    staleTime: 1000 * 30, // 30s as per spec
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
      walletReportsRepository.exportCashInToCsv(query.data.value);
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
