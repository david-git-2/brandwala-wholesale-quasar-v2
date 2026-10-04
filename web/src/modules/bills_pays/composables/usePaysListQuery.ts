import { useQuery, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { paysRepository, type ListPaysParams } from '../repositories/paysRepository';
import { paysQueryKeys } from '../services/paysQueryKeys';

export function usePaysListQuery(params: Ref<ListPaysParams>) {
  return useQuery({
    queryKey: computed(() =>
      paysQueryKeys.list(params.value.tenantId, {
        page: params.value.page,
        pageSize: params.value.pageSize,
        search: params.value.search,
        side: params.value.side,
      }),
    ),
    queryFn: () => paysRepository.listPays(params.value),
    staleTime: 30_000,
    placeholderData: keepPreviousData,
    enabled: computed(() => !!params.value.tenantId),
  });
}
