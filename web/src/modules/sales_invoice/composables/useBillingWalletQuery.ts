import { keepPreviousData, useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { billingWalletRepository } from '../repositories/billingWalletRepository';
import { salesInvoiceQueryKeys } from '../services/salesInvoiceQueryKeys';

export function useBillingWalletBalancesQuery(tenantId: Ref<number | null>) {
  return useQuery({
    queryKey: computed(() => salesInvoiceQueryKeys.walletBalances(tenantId.value)),
    queryFn: () => {
      if (!tenantId.value) return Promise.resolve([]);
      return billingWalletRepository.fetchWalletBalances(tenantId.value);
    },
    staleTime: 2 * 60 * 1000,
    placeholderData: keepPreviousData,
    enabled: computed(() => !!tenantId.value),
  });
}

export function useBillingWalletLedgerQuery(
  tenantId: Ref<number | null>,
  billingProfileId: Ref<number | null>,
) {
  return useQuery({
    queryKey: computed(() =>
      salesInvoiceQueryKeys.walletLedger(tenantId.value, billingProfileId.value),
    ),
    queryFn: () => {
      if (!tenantId.value || !billingProfileId.value) return Promise.resolve([]);
      return billingWalletRepository.fetchWalletLedger(tenantId.value, billingProfileId.value);
    },
    staleTime: 60 * 1000,
    placeholderData: keepPreviousData,
    enabled: computed(() => !!tenantId.value && !!billingProfileId.value),
  });
}
