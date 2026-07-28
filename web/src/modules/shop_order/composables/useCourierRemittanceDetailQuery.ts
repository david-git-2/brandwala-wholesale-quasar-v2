import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { courierRemittanceRepository } from '../repositories/courierRemittanceRepository';

export function useCourierRemittanceDetailQuery(
  tenantId: Ref<number>,
  batchId: Ref<number | null>,
) {
  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.courierRemittanceDetail(tenantId.value, batchId.value ?? 0)),
    queryFn: () => courierRemittanceRepository.getBatchById(tenantId.value, batchId.value!),
    staleTime: 30 * 1000,
    enabled: computed(() => !!tenantId.value && !!batchId.value && batchId.value > 0),
  });
}
