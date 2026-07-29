import { computed, type Ref } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { shopOrderQueryKeys } from '../services/shopOrderQueryKeys';
import { merchantWalletRepository } from '../repositories/merchantWalletRepository';

export function useMerchantWalletQuery(enabled: Ref<boolean> | boolean = true) {
  const enabledRef = computed(() =>
    typeof enabled === 'boolean' ? enabled : enabled.value,
  );

  const summaryQuery = useQuery({
    queryKey: shopOrderQueryKeys.merchantWalletSummary(),
    queryFn: () => merchantWalletRepository.getMySummary(),
    enabled: enabledRef,
  });

  const ledgerQuery = useQuery({
    queryKey: shopOrderQueryKeys.merchantWalletLedger(),
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
