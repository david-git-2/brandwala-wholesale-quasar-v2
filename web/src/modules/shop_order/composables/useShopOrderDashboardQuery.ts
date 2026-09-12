import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopOrderDashboardRepository } from '../repositories/shopOrderDashboardRepository';

export function useShopOrderDashboardQuery(tenantId: Ref<number | null | undefined>) {
  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.dashboard(Number(tenantId.value) || 0)),
    queryFn: () => shopOrderDashboardRepository.getMetrics(Number(tenantId.value)),
    enabled: computed(() => !!tenantId.value),
    staleTime: 30 * 1000,
  });
}
