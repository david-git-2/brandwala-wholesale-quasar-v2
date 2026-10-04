import { useQuery, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { invoiceRepository, type ListGlobalInvoicesParams } from 'src/modules/sales_invoice/repositories/invoiceRepository';
import { billsQueryKeys } from '../services/billsQueryKeys';

export type BillsListQueryParams = ListGlobalInvoicesParams & {
  parentTenantId: number | null;
};

export function useBillsListQuery(params: Ref<BillsListQueryParams>) {
  return useQuery({
    queryKey: computed(() =>
      billsQueryKeys.list(params.value.parentTenantId, {
        page: params.value.page,
        pageSize: params.value.pageSize,
        search: params.value.search,
        quickFilter: params.value.quickFilter,
        invoiceStatus: params.value.invoiceStatus,
        paymentStatus: params.value.paymentStatus,
        issuedByTenantId: params.value.issuedByTenantId,
        arSide: params.value.arSide,
      }),
    ),
    queryFn: () => invoiceRepository.listGlobalInvoices(params.value),
    staleTime: 30_000,
    placeholderData: keepPreviousData,
    enabled: computed(() => !!params.value.parentTenantId || !!params.value.issuedByTenantId),
  });
}
