import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { tasksDashboardRepository } from '../repositories/tasksDashboardRepository';

export const tasksDashboardQueryKeys = {
  metrics: (tenantId: number) => ['tasks', 'dashboard', tenantId] as const,
};

export function useTasksDashboardQuery(tenantId: Ref<number | null | undefined>) {
  return useQuery({
    queryKey: computed(() => tasksDashboardQueryKeys.metrics(Number(tenantId.value) || 0)),
    queryFn: () => tasksDashboardRepository.getMetrics(Number(tenantId.value)),
    enabled: computed(() => !!tenantId.value),
    staleTime: 30 * 1000,
  });
}
