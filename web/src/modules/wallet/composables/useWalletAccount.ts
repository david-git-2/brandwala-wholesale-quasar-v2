import { computed, toValue, type MaybeRefOrGetter } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { walletAccountRepository } from '../repositories/walletAccountRepository';
import { walletQueryKeys } from '../shared/queryKeys/walletQueryKeys';
import type { UniversalWalletEntityType, WalletAccount } from '../types';

export function useWalletAccount(
  entityTypeInput: MaybeRefOrGetter<UniversalWalletEntityType>,
  entityIdInput: MaybeRefOrGetter<number>,
) {
  const authStore = useAuthStore();

  const tenantId = computed(() => authStore.selectedTenant?.id ?? null);
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

  const accountQueryParams = computed(() => ({
    tenantId: tenantId.value || 0,
    entityType: entityType.value,
    entityId: entityId.value || 0,
  }));

  const accountQuery = useQuery<WalletAccount, Error>({
    queryKey: computed(() => walletQueryKeys.accountBalances(accountQueryParams.value)),
    queryFn: () =>
      walletAccountRepository.fetchAccountBalances(
        accountQueryParams.value.tenantId,
        accountQueryParams.value.entityType,
        accountQueryParams.value.entityId,
      ),
    enabled: isEnabled,
    staleTime: 1000 * 60 * 2,
  });

  return {
    account: computed(() => accountQuery.data.value || null),
    isAccountLoading: accountQuery.isLoading,
    accountError: accountQuery.error,
    refetchAccount: accountQuery.refetch,
  };
}
