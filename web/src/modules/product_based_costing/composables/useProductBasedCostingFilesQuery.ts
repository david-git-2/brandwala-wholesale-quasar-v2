import { useQuery, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { productBasedCostingQueryKeys } from '../shared/queryKeys/productBasedCostingQueryKeys';
import { productBasedCostingRepository } from '../repositories/productBasedCostingRepository';
import type { ProductBasedCostingFileListInput } from '../types';

export function useProductBasedCostingFilesQuery(
  params: Ref<ProductBasedCostingFileListInput>,
) {
  return useQuery({
    queryKey: computed(() => productBasedCostingQueryKeys.filesList(params.value)),
    queryFn: () => productBasedCostingRepository.listProductBasedCostingFiles(params.value),
    staleTime: 2 * 60 * 1000,
    placeholderData: keepPreviousData,
  });
}
