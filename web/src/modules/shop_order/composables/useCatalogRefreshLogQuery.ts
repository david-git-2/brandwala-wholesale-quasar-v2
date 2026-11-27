import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { listCatalogRefreshLog } from '../repositories/catalogRefreshRepository';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';

export function useCatalogRefreshLogQuery(tenantId: Ref<number | null | undefined>) {
  const parentId = computed(() => Number(tenantId.value ?? 0));

  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.catalogRefreshLog(parentId.value)),
    queryFn: () => listCatalogRefreshLog(parentId.value, 200),
    enabled: computed(() => parentId.value > 0),
    staleTime: 60 * 1000,
  });
}
