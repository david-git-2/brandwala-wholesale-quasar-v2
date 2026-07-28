import { useQuery, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { courierRemittanceRepository } from '../repositories/courierRemittanceRepository';

export interface CourierRemittancesQueryParams {
  tenantId: number;
  courierServiceId?: string | null;
  status?: string | null;
}

export function useCourierRemittancesQuery(params: Ref<CourierRemittancesQueryParams>) {
  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.courierRemittances(params.value)),
    queryFn: () =>
      courierRemittanceRepository.listBatches(params.value.tenantId, {
        courierServiceId: params.value.courierServiceId ?? null,
        status: params.value.status ?? null,
      }),
    staleTime: 60 * 1000,
    placeholderData: keepPreviousData,
    enabled: computed(() => !!params.value.tenantId),
  });
}
