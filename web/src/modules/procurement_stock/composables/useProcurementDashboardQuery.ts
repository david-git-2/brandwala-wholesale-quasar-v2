import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { procurementStockQueryKeys } from '../shared/queryKeys/procurementStockQueryKeys';
import { procurementDashboardRepository } from '../repositories/procurementDashboardRepository';

export function useProcurementDashboardQuery(tenantId: Ref<number | null | undefined>) {
  return useQuery({
    queryKey: computed(() => procurementStockQueryKeys.dashboard(Number(tenantId.value) || 0)),
    queryFn: () => procurementDashboardRepository.getMetrics(Number(tenantId.value)),
    enabled: computed(() => !!tenantId.value),
    staleTime: 30 * 1000,
  });
}
