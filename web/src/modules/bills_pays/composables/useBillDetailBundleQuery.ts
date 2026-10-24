import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { invoiceRepository } from 'src/modules/sales_invoice/repositories/invoiceRepository';
import { billsQueryKeys } from '../services/billsQueryKeys';

export function useBillDetailBundleQuery(
  billId: Ref<number | null>,
  tenantId: Ref<number | null>,
) {
  return useQuery({
    queryKey: computed(() => billsQueryKeys.detailBundle(billId.value)),
    queryFn: () =>
      invoiceRepository.getBillDetailBundle({
        tenantId: tenantId.value!,
        billId: billId.value!,
      }),
    enabled: computed(
      () =>
        billId.value != null &&
        billId.value > 0 &&
        tenantId.value != null &&
        tenantId.value > 0,
    ),
    staleTime: 30_000,
  });
}
