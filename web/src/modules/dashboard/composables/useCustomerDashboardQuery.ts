import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { customerDashboardRepository } from '../repositories/customerDashboardRepository';

export const customerDashboardQueryKeys = {
  summary: (tenantId: number) => ['customer', 'dashboard', { tenantId }] as const,
};

export function useCustomerDashboardQuery(tenantId: Ref<number | null>) {
  return useQuery({
    queryKey: computed(() => customerDashboardQueryKeys.summary(tenantId.value ?? 0)),
    queryFn: () => {
      if (!tenantId.value) {
        return Promise.resolve(null);
      }
      return customerDashboardRepository.getCustomerDashboardSummary(tenantId.value);
    },
    enabled: computed(() => !!tenantId.value),
    staleTime: 60 * 1000,
  });
}
