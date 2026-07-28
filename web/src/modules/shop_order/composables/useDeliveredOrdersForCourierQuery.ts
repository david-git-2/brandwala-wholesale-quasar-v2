import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { courierRemittanceRepository } from '../repositories/courierRemittanceRepository';

export function useDeliveredOrdersForCourierQuery(
  tenantId: Ref<number>,
  courierServiceId: Ref<string | null>,
) {
  return useQuery({
    queryKey: computed(() =>
      shopOrderQueryKeys.deliveredOrdersUnremitted(tenantId.value, courierServiceId.value ?? ''),
    ),
    queryFn: () =>
      courierRemittanceRepository.listDeliveredOrdersForCourier(
        tenantId.value,
        courierServiceId.value!,
      ),
    staleTime: 30 * 1000,
    enabled: computed(() => !!tenantId.value && !!courierServiceId.value),
  });
}
