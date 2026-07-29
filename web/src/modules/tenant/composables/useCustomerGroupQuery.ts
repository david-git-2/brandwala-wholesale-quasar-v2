import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { customerGroupRepository } from '../repositories/customerGroupRepository';
import { tenantQueryKeys } from '../shared/queryKeys/tenantQueryKeys';

export function useCustomerGroupsQuery(tenantId: Ref<number | null | undefined>) {
  return useQuery({
    queryKey: computed(() => tenantQueryKeys.customerGroups(tenantId.value ?? null)),
    queryFn: () => {
      if (!tenantId.value) return [];
      return customerGroupRepository.listCustomerGroupsByTenant(tenantId.value);
    },
    enabled: computed(() => !!tenantId.value),
    staleTime: 2 * 60 * 1000,
  });
}
