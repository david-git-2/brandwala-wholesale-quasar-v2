import { computed, toValue, type MaybeRefOrGetter } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { walletRepository } from '../repositories/walletRepository';
import { walletQueryKeys } from '../shared/queryKeys/walletQueryKeys';
import { walletBooksTenantId } from '../utils/walletBooksTenantId';
import type { UniversalWalletEntityType, UniversalWalletLedgerEntry } from '../types';

export function useWalletQuery(
  entityTypeInput: MaybeRefOrGetter<UniversalWalletEntityType>,
  entityIdInput: MaybeRefOrGetter<number>,
  searchInput?: MaybeRefOrGetter<string | null>,
) {
  const authStore = useAuthStore();
  const booksTenantId = computed(() => walletBooksTenantId(authStore.selectedTenant));
  const entityType = computed(() => toValue(entityTypeInput));
  const entityId = computed(() => toValue(entityIdInput));
  const search = computed(() => (searchInput ? toValue(searchInput) : null));

  const isEnabled = computed(() => {
    return Boolean(
      booksTenantId.value > 0 &&
        entityType.value &&
        entityId.value !== undefined &&
        entityId.value !== null &&
        entityId.value > 0,
    );
  });

  const queryParams = computed(() => ({
    booksTenantId: booksTenantId.value,
    entityType: entityType.value,
    entityId: entityId.value || 0,
    search: search.value,
    offset: 0,
  }));

  const query = useQuery<UniversalWalletLedgerEntry[], Error>({
    queryKey: computed(() => walletQueryKeys.ledger(queryParams.value)),
    queryFn: () =>
      walletRepository.listLedgerForStaff({
        tenantId: authStore.selectedTenant?.id || booksTenantId.value,
        entityType: entityType.value,
        entityId: entityId.value || 0,
        search: search.value,
        limit: 50,
        offset: 0,
      }),
    enabled: isEnabled,
    staleTime: 1000 * 60 * 2,
  });

  return {
    ledgerEntries: computed(() => query.data.value || []),
    isLoading: query.isLoading,
    isFetching: query.isFetching,
    error: query.error,
    refetch: query.refetch,
  };
}
