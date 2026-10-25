import { useQuery, useQueryClient } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { productBasedCostingQueryKeys } from '../shared/queryKeys/productBasedCostingQueryKeys';
import { productBasedCostingRepository } from '../repositories/productBasedCostingRepository';
import {
  isPbcDetailsBundleQueryPending,
  readPbcFileFromDetailsBundleCache,
  readPbcFileFromListCache,
} from '../utils/pbcDetailsBundleCache';

export function useProductBasedCostingFileDetailQuery(fileId: Ref<number>) {
  const queryClient = useQueryClient();

  const cachedFile = computed(() => {
    if (!fileId.value) {
      return undefined;
    }
    return (
      readPbcFileFromDetailsBundleCache(queryClient, fileId.value)
      ?? readPbcFileFromListCache(queryClient, fileId.value)
    );
  });

  return useQuery({
    queryKey: computed(() => productBasedCostingQueryKeys.fileDetail(fileId.value)),
    queryFn: () => productBasedCostingRepository.getProductBasedCostingFileById(fileId.value),
    staleTime: 2 * 60 * 1000,
    enabled: computed(() => {
      if (fileId.value <= 0) {
        return false;
      }
      if (cachedFile.value) {
        return false;
      }
      if (isPbcDetailsBundleQueryPending(queryClient, fileId.value)) {
        return false;
      }
      return true;
    }),
    placeholderData: () => cachedFile.value,
  });
}
