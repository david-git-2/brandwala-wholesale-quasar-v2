import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { billsRepository } from '../repositories/billsRepository';
import { billsQueryKeys } from '../services/billsQueryKeys';

export function useBillDetailBundleQuery(
  billId: Ref<number | null>,
  tenantId: Ref<number | null>,
) {
  return useQuery({
    queryKey: computed(() => billsQueryKeys.detailBundle(billId.value)),
    queryFn: () =>
      billsRepository.getBillDetailBundle({
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
