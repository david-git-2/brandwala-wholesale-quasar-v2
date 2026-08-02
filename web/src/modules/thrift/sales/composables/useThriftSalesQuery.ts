import { useQuery, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { thriftQueryKeys } from '../../shared/queryKeys/thriftQueryKeys';
import { thriftSalesRepository } from '../repositories/thriftSalesRepository';

export interface ThriftAvailableStockSearchParams {
  tenantId: number;
  search: string;
}

export function useThriftAvailableStockSearchQuery(
  params: Ref<ThriftAvailableStockSearchParams>,
) {
  return useQuery({
    queryKey: computed(() => thriftQueryKeys.availableStockSearch(params.value)),
    queryFn: () =>
      thriftSalesRepository.searchAvailableStocks(
        params.value.tenantId,
        params.value.search,
      ),
    staleTime: 30 * 1000,
    placeholderData: keepPreviousData,
    enabled: computed(
      () => !!params.value.tenantId && !!params.value.search.trim(),
    ),
  });
}
