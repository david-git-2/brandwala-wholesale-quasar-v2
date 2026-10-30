import { computed, type Ref } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { shopOrderRepository } from 'src/modules/shop_order/repositories/shopOrderRepository';
import { shopOrderQueryKeys } from 'src/modules/shop_order/shared/queryKeys/shopOrderQueryKeys';

export function useCustomerShopPortalStatsQuery(tenantId: Ref<number | null>) {
  return useQuery({
    queryKey: computed(() => [...shopOrderQueryKeys.customerOrders(tenantId.value ?? 0), 'portalStats']),
    queryFn: () => shopOrderRepository.listCustomerShopOrders(Number(tenantId.value), { limit: 100 }),
    enabled: computed(() => !!tenantId.value),
    staleTime: 60_000,
  });
}
