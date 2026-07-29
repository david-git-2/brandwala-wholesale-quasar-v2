import { useQuery, useQueryClient } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { productBasedCostingQueryKeys } from '../shared/queryKeys/productBasedCostingQueryKeys';
import { productBasedCostingRepository } from '../repositories/productBasedCostingRepository';
import type { ProductBasedCostingFileListPage } from '../types';

export function useProductBasedCostingFileDetailQuery(fileId: Ref<number>) {
  const queryClient = useQueryClient();

  return useQuery({
    queryKey: computed(() => productBasedCostingQueryKeys.fileDetail(fileId.value)),
    queryFn: () => productBasedCostingRepository.getProductBasedCostingFileById(fileId.value),
    staleTime: 2 * 60 * 1000,
    enabled: computed(() => fileId.value > 0),
    initialData: () => {
      if (!fileId.value) return undefined;
      const listQueries = queryClient.getQueriesData<ProductBasedCostingFileListPage>({
        queryKey: ['productBasedCosting', 'files', 'list'],
      });
      for (const [, data] of listQueries) {
        const found = data?.data?.find((file) => file.id === fileId.value);
        if (found) return found;
      }
      return undefined;
    },
  });
}
