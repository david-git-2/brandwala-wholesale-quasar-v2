import { useQuery, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { thriftQueryKeys } from '../../shared/queryKeys/thriftQueryKeys';
import {
  thriftSalesRepository,
  type ListSalesInvoicesParams,
  type ListSalesReturnsParams,
} from '../repositories/thriftSalesRepository';

export interface ThriftAvailableStockSearchParams {
  tenantId: number;
  search: string;
  customerPhone?: string | undefined;
}

export type ThriftSalesInvoiceListQueryParams = ListSalesInvoicesParams;

export function useThriftSalesInvoicesQuery(
  params: Ref<ThriftSalesInvoiceListQueryParams>,
) {
  return useQuery({
    queryKey: computed(() => thriftQueryKeys.salesInvoices(params.value)),
    queryFn: () => thriftSalesRepository.listSalesInvoices(params.value),
    staleTime: 30 * 1000,
    placeholderData: keepPreviousData,
    enabled: computed(() => !!params.value.tenantId),
  });
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
        params.value.customerPhone,
      ),
    staleTime: 60 * 1000,
    gcTime: 5 * 60 * 1000,
    placeholderData: keepPreviousData,
    enabled: computed(
      () => !!params.value.tenantId && !!params.value.search.trim(),
    ),
  });
}

export function useThriftSalesReturnsQuery(
  params: Ref<ListSalesReturnsParams>,
) {
  return useQuery({
    queryKey: computed(() => ['thrift', 'sales', 'returns', params.value]),
    queryFn: () => thriftSalesRepository.listSalesReturnsPaginated(params.value),
    staleTime: 30 * 1000,
    placeholderData: keepPreviousData,
    enabled: computed(() => !!params.value.tenantId),
  });
}

export function useThriftSalesReturnDetailQuery(
  tenantId: Ref<number | null | undefined>,
  returnId: Ref<number>,
) {
  return useQuery({
    queryKey: computed(() => ['thrift', 'sales', 'returns', 'detail', tenantId.value, returnId.value]),
    queryFn: () =>
      thriftSalesRepository.getSalesReturn(Number(tenantId.value), returnId.value),
    enabled: computed(() => !!tenantId.value && returnId.value > 0),
  });
}
