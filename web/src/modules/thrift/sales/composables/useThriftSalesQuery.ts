import { useQuery, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { thriftQueryKeys } from '../../shared/queryKeys/thriftQueryKeys';
import {
  thriftSalesRepository,
  type ListSalesInvoicesParams,
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
