import { useQuery, useQueryClient } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { productBasedCostingQueryKeys } from '../shared/queryKeys/productBasedCostingQueryKeys';
import { productBasedCostingRepository } from '../repositories/productBasedCostingRepository';
import type { InfiniteData } from '@tanstack/vue-query';
import type { ProductBasedCostingFile, ProductBasedCostingFileListPage } from '../types';

export function useProductBasedCostingFileDetailQuery(fileId: Ref<number>) {
  const queryClient = useQueryClient();

  return useQuery({
    queryKey: computed(() => productBasedCostingQueryKeys.fileDetail(fileId.value)),
    queryFn: () => productBasedCostingRepository.getProductBasedCostingFileById(fileId.value),
    staleTime: 2 * 60 * 1000,
    enabled: computed(() => fileId.value > 0),
    initialData: () => {
      if (!fileId.value) return undefined;
      const listQueries = queryClient.getQueriesData<
        InfiniteData<ProductBasedCostingFileListPage>
      >({
        queryKey: ['productBasedCosting', 'files', 'list'],
      });
      for (const [, data] of listQueries) {
        const pages = data?.pages ?? [];
        for (const page of pages) {
          const found = page.data.find((file: ProductBasedCostingFile) => file.id === fileId.value);
          if (found) return found;
        }
      }
      return undefined;
    },
  });
}
