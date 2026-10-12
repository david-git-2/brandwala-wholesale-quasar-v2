import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { invoiceRepository } from 'src/modules/sales_invoice/repositories/invoiceRepository';
import { billsQueryKeys } from '../services/billsQueryKeys';

export function useBillPaymentHistoryQuery(
  billId: Ref<number | null>,
  tenantId: Ref<number | null>,
) {
  return useQuery({
    queryKey: computed(() => billsQueryKeys.paymentHistory(billId.value)),
    queryFn: () =>
      invoiceRepository.listInvoicePaymentHistory({
        tenantId: tenantId.value!,
        invoiceId: billId.value!,
      }),
    enabled: computed(
      () =>
        billId.value != null &&
        billId.value > 0 &&
        tenantId.value != null &&
        tenantId.value > 0,
    ),
    staleTime: 15_000,
  });
}
