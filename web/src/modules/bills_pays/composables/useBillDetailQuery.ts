import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { invoiceRepository } from 'src/modules/sales_invoice/repositories/invoiceRepository';
import { billsQueryKeys } from '../services/billsQueryKeys';

export function useBillDetailQuery(billId: Ref<number | null>) {
  const detailQuery = useQuery({
    queryKey: computed(() => billsQueryKeys.detail(billId.value)),
    queryFn: () => invoiceRepository.getGlobalInvoiceById(billId.value!),
    enabled: computed(() => billId.value != null && billId.value > 0),
    staleTime: 30_000,
  });

  const itemsQuery = useQuery({
    queryKey: computed(() => billsQueryKeys.items(billId.value)),
    queryFn: () => invoiceRepository.listGlobalInvoiceItems(billId.value!),
    enabled: computed(() => billId.value != null && billId.value > 0),
    staleTime: 30_000,
  });

  return { detailQuery, itemsQuery };
}
