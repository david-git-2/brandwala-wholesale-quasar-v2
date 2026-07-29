import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { productBasedCostingQueryKeys } from '../shared/queryKeys/productBasedCostingQueryKeys';
import { productBasedCostingRepository } from '../repositories/productBasedCostingRepository';

export function useProductBasedCostingItemsQuery(fileId: Ref<number>) {
  return useQuery({
    queryKey: computed(() => productBasedCostingQueryKeys.itemsList(fileId.value)),
    queryFn: () => productBasedCostingRepository.listProductBasedCostingItems(fileId.value),
    staleTime: 2 * 60 * 1000,
    enabled: computed(() => fileId.value > 0),
  });
}
