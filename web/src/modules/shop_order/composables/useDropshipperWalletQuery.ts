import { computed, type Ref } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { merchantWalletRepository } from '../repositories/merchantWalletRepository';
import { useAuthStore } from 'src/modules/auth/stores/authStore';

export function useMerchantWalletQuery(enabled: Ref<boolean> | boolean = true) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId ?? 0);
  const enabledRef = computed(() => {
    const flag = typeof enabled === 'boolean' ? enabled : enabled.value;
    return flag && tenantId.value > 0;
  });

  const summaryQuery = useQuery({
    queryKey: computed(() => shopOrderQueryKeys.merchantWalletSummary(tenantId.value)),
    queryFn: () => merchantWalletRepository.getMySummary(),
    enabled: enabledRef,
  });

  const ledgerQuery = useQuery({
    queryKey: computed(() => shopOrderQueryKeys.merchantWalletLedger(tenantId.value)),
    queryFn: () => merchantWalletRepository.listMyLedger({ limit: 50, offset: 0 }),
    enabled: enabledRef,
  });

  const isLoading = computed(
    () => summaryQuery.isLoading.value || ledgerQuery.isLoading.value,
  );

  const isError = computed(
    () => summaryQuery.isError.value || ledgerQuery.isError.value,
  );

  const error = computed(
    () => summaryQuery.error.value || ledgerQuery.error.value,
  );

  return {
    summary: computed(() => summaryQuery.data.value ?? null),
    ledger: computed(() => ledgerQuery.data.value ?? []),
    isLoading,
    isError,
    error,
    refetch: async () => {
      await Promise.all([summaryQuery.refetch(), ledgerQuery.refetch()]);
    },
  };
}
