import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { afterSalesRepositoryStub } from '../repositories/afterSalesRepository.stub';
import { afterSalesQueryKeys } from '../services/afterSalesQueryKeys';

export function useAfterSalesHubQuery(tenantId: Ref<number | null | undefined>) {
  return useQuery({
    queryKey: computed(() => afterSalesQueryKeys.hub(tenantId.value ?? 0)),
    queryFn: () => afterSalesRepositoryStub.getHubSummary(tenantId.value!),
    enabled: computed(() => Boolean(tenantId.value)),
    staleTime: 30_000,
  });
}
