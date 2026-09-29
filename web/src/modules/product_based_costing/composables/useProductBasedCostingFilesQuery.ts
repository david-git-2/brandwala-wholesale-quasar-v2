import { useInfiniteQuery, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { productBasedCostingQueryKeys } from '../shared/queryKeys/productBasedCostingQueryKeys';
import { productBasedCostingRepository } from '../repositories/productBasedCostingRepository';
import type {
  ProductBasedCostingFile,
  ProductBasedCostingFileListInput,
  ProductBasedCostingFilesListCursor,
} from '../types';

const PBC_FILES_PAGE_SIZE = 20;

export function useProductBasedCostingFilesQuery(
  params: Ref<ProductBasedCostingFileListInput>,
) {
  const query = useInfiniteQuery({
    queryKey: computed(() => productBasedCostingQueryKeys.filesList(params.value)),
    queryFn: async ({ pageParam }) =>
      productBasedCostingRepository.listProductBasedCostingFiles({
        ...params.value,
        limit: params.value.limit ?? PBC_FILES_PAGE_SIZE,
        cursor: (pageParam as ProductBasedCostingFilesListCursor | null) ?? null,
      }),
    getNextPageParam: (lastPage) =>
      lastPage.meta.has_more && lastPage.meta.next_cursor
        ? lastPage.meta.next_cursor
        : undefined,
    initialPageParam: null as ProductBasedCostingFilesListCursor,
    staleTime: 2 * 60 * 1000,
    placeholderData: keepPreviousData,
  });

  const files = computed<ProductBasedCostingFile[]>(() => {
    const pages = query.data.value?.pages ?? [];
    const seen = new Set<number>();
    const rows: ProductBasedCostingFile[] = [];
    for (const page of pages) {
      for (const file of page.data) {
        if (!seen.has(file.id)) {
          seen.add(file.id);
          rows.push(file);
        }
      }
    }
    return rows;
  });

  const hasMoreFiles = computed(() => query.hasNextPage.value ?? false);

  return {
    ...query,
    data: files,
    files,
    hasMoreFiles,
    isLoading: query.isLoading,
    isFetching: query.isFetching,
    isError: query.isError,
    error: query.error,
    fetchNextPage: query.fetchNextPage,
    isFetchingNextPage: query.isFetchingNextPage,
  };
}
