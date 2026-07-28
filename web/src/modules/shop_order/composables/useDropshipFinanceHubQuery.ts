import { computed, type Ref } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { dropshipFinanceRepository } from '../repositories/dropshipFinanceRepository';
import { dropshipFinanceQueryKeys } from '../shared/queryKeys/dropshipFinanceQueryKeys';

export function useDropshipFinanceHubQuery(tenantId: Ref<number | null | undefined>) {
  const hubQuery = useQuery({
    queryKey: computed(() => dropshipFinanceQueryKeys.hubData(tenantId.value ?? 0)),
    queryFn: async () => {
      if (!tenantId.value) throw new Error('Tenant ID is required');
      return await dropshipFinanceRepository.getHubData(tenantId.value);
    },
    enabled: computed(() => Boolean(tenantId.value)),
    staleTime: 1000 * 30, // 30s
  });

  return {
    hubQuery,
    kpis: computed(() => hubQuery.data.value?.kpis ?? { courierOwedTotal: 0, tenantCashTotal: 0, middlemanPayableTotal: 0 }),
    orders: computed(() => hubQuery.data.value?.orders ?? []),
    merchants: computed(() => hubQuery.data.value?.merchants ?? []),
    isLoading: computed(() => hubQuery.isLoading.value),
    isError: computed(() => hubQuery.isError.value),
    error: computed(() => hubQuery.error.value),
    refetch: () => hubQuery.refetch(),
  };
}
