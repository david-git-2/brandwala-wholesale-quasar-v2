import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { courierRemittanceRepository } from '../repositories/courierRemittanceRepository';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import type { MerchantPayoutSummary } from '../types';

export function useMerchantPayoutQuery(tenantId: Ref<number | null | undefined>) {
  const enabled = computed(() => !!tenantId.value);

  const query = useQuery({
    queryKey: computed(() => shopOrderQueryKeys.merchantPayouts(tenantId.value ?? 0)),
    queryFn: async (): Promise<MerchantPayoutSummary[]> => {
      if (!tenantId.value) return [];
      return courierRemittanceRepository.fetchMerchantPayoutSummaries(tenantId.value);
    },
    enabled,
    staleTime: 1000 * 60 * 2, // 2 minutes
  });

  return {
    merchants: computed(() => query.data.value ?? []),
    isLoading: query.isLoading,
    isFetching: query.isFetching,
    error: query.error,
    refetch: query.refetch,
  };
}
