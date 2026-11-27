import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { investorCapitalDashboardRepository } from '../repositories/investorCapitalDashboardRepository';

export const investorCapitalDashboardQueryKeys = {
  metrics: (tenantId: number) => ['investorCapital', 'dashboard', tenantId] as const,
};

export function useInvestorCapitalDashboardQuery(tenantId: Ref<number | null | undefined>) {
  return useQuery({
    queryKey: computed(() =>
      investorCapitalDashboardQueryKeys.metrics(Number(tenantId.value) || 0),
    ),
    queryFn: () => investorCapitalDashboardRepository.getMetrics(Number(tenantId.value)),
    enabled: computed(() => !!tenantId.value),
    staleTime: 60 * 1000,
  });
}
