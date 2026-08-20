import { computed, toValue, type MaybeRefOrGetter } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { walletRepository } from '../repositories/walletRepository';
import { walletQueryKeys } from '../shared/queryKeys/walletQueryKeys';
import type { UniversalWalletEntityType, UniversalWalletLedgerEntry } from '../types';

export function useWalletQuery(
  entityTypeInput: MaybeRefOrGetter<UniversalWalletEntityType>,
  entityIdInput: MaybeRefOrGetter<number>,
) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.selectedTenant?.parent_id ?? authStore.selectedTenant?.id ?? null);
  const entityType = computed(() => toValue(entityTypeInput));
  const entityId = computed(() => toValue(entityIdInput));

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

  const queryParams = computed(() => ({
    tenantId: tenantId.value || 0,
    entityType: entityType.value,
    entityId: entityId.value || 0,
  }));

  const query = useQuery<UniversalWalletLedgerEntry[], Error>({
    queryKey: computed(() => walletQueryKeys.ledgerList(queryParams.value)),
    queryFn: () => walletRepository.fetchLedgerEntries(queryParams.value),
    enabled: isEnabled,
    staleTime: 1000 * 60 * 2, // 2 minutes
  });

  return {
    ledgerEntries: computed(() => query.data.value || []),
    isLoading: query.isLoading,
    isFetching: query.isFetching,
    error: query.error,
    refetch: query.refetch,
  };
}
