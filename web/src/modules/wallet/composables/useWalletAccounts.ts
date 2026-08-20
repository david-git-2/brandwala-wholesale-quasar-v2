import { computed, toValue, type MaybeRefOrGetter } from 'vue';
import { useQuery, useMutation, useQueryClient } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { walletAccountRepository } from '../repositories/walletAccountRepository';
import { walletQueryKeys } from '../shared/queryKeys/walletQueryKeys';
import type {
  UniversalWalletEntityType,
  WalletAccount,
  TransferWalletBalancePayload,
  WalletDashboardSummary,
} from '../types';

export function useWalletAccounts(
  entityTypeInput?: MaybeRefOrGetter<UniversalWalletEntityType>,
  entityIdInput?: MaybeRefOrGetter<number>,
) {
  const authStore = useAuthStore();
  const queryClient = useQueryClient();

  const tenantId = computed(() => authStore.selectedTenant?.parent_id ?? authStore.selectedTenant?.id ?? null);
  const entityType = computed(() => (entityTypeInput ? toValue(entityTypeInput) : undefined));
  const entityId = computed(() => (entityIdInput ? toValue(entityIdInput) : undefined));

  const isAccountQueryEnabled = computed(() => {
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
    entityType: entityType.value || 'tenant',
    entityId: entityId.value || 0,
  }));

  // Query 3-bucket account balances for specific entity
  const accountQuery = useQuery<WalletAccount, Error>({
    queryKey: computed(() => walletQueryKeys.accountBalances(accountQueryParams.value)),
    queryFn: () =>
      walletAccountRepository.fetchAccountBalances(
        accountQueryParams.value.tenantId,
        accountQueryParams.value.entityType,
        accountQueryParams.value.entityId,
      ),
    enabled: isAccountQueryEnabled,
    staleTime: 1000 * 60 * 2, // 2 minutes
  });

  // Query dashboard summary for current tenant
  const dashboardQuery = useQuery<WalletDashboardSummary, Error>({
    queryKey: computed(() => walletQueryKeys.dashboardSummary(tenantId.value || 0)),
    queryFn: () => walletAccountRepository.fetchDashboardSummary(tenantId.value || 0),
    enabled: computed(() => Boolean(tenantId.value && tenantId.value > 0)),
    staleTime: 1000 * 60 * 2,
  });

  // Mutation for transferring balances between buckets
  const transferMutation = useMutation<WalletAccount, Error, TransferWalletBalancePayload>({
    mutationFn: (payload) => walletAccountRepository.transferBalance(payload),
    onSuccess: () => {
      // Invalidate wallet queries to refresh balances and ledger list
      void queryClient.invalidateQueries({ queryKey: walletQueryKeys.all });
    },
  });

  return {
    account: computed(() => accountQuery.data.value || null),
    isAccountLoading: accountQuery.isLoading,
    accountError: accountQuery.error,
    refetchAccount: accountQuery.refetch,

    dashboardSummary: computed(() => dashboardQuery.data.value || null),
    isDashboardLoading: dashboardQuery.isLoading,
    dashboardError: dashboardQuery.error,
    refetchDashboard: dashboardQuery.refetch,

    transferBalance: transferMutation.mutateAsync,
    isTransferring: transferMutation.isPending,
  };
}
