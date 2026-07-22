import { useQuery, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { thriftQueryKeys } from '../../shared/queryKeys/thriftQueryKeys';
import { thriftStockRepository } from '../repositories/thriftStockRepository';

export interface ThriftStockQueryParams {
  tenantId: number;
  page?: number;
  pageSize?: number;
  search?: string;
  status?: string | null;
  condition?: string | null;
}

export function useThriftStocksQuery(params: Ref<ThriftStockQueryParams>) {
  return useQuery({
    queryKey: computed(() => thriftQueryKeys.stocks(params.value)),
    queryFn: () => thriftStockRepository.fetchStocksPaginated(params.value),
    staleTime: 2 * 60 * 1000,
    placeholderData: keepPreviousData,
    enabled: computed(() => !!params.value.tenantId),
  });
}

export function useThriftStocksByShipmentQuery(
  tenantId: Ref<number | null | undefined>,
  shipmentId: Ref<number | null | undefined>,
) {
  return useQuery({
    queryKey: computed(() =>
      thriftQueryKeys.stocks({ tenantId: tenantId.value, shipmentId: shipmentId.value }),
    ),
    queryFn: () => thriftStockRepository.fetchStocksByShipment(tenantId.value!, shipmentId.value!),
    staleTime: 2 * 60 * 1000,
    enabled: computed(() => !!tenantId.value && !!shipmentId.value),
  });
}


