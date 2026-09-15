import { useQuery, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopOrderRepository } from '../repositories/shopOrderRepository';

export interface StaffOrdersQueryParams {
  tenantId: number;
  parentTenantId?: number | null;
  search?: string | null;
  status?: string | null;
  shopId?: number | null;
}

export function useStaffOrdersQuery(params: Ref<StaffOrdersQueryParams>) {
  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.staffOrders(params.value)),
    queryFn: () =>
      shopOrderRepository.listShopOrdersForStaff(params.value.tenantId, {
        parentTenantId: params.value.parentTenantId ?? null,
        search: params.value.search ?? null,
        status: params.value.status ?? null,
        shopId: params.value.shopId ?? null,
      }),
    staleTime: 60 * 1000,
    placeholderData: keepPreviousData,
    enabled: computed(() => !!params.value.tenantId),
  });
}
