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
    statement: computed(() => statementQuery.data.value || null),
    isLoading: statementQuery.isLoading,
    isFetching: statementQuery.isFetching,
    error: statementQuery.error,
    refetch: statementQuery.refetch,

    startDate,
    endDate,
    setDateRange,
    exportCsv,
  };
}
