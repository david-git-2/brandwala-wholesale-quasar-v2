import { computed, type Ref } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import type { ShopType } from 'src/modules/shop_order/types';
import { shopOrderRepository } from 'src/modules/shop_order/repositories/shopOrderRepository';
import { shopOrderQueryKeys } from 'src/modules/shop_order/shared/queryKeys/shopOrderQueryKeys';

export function useCustomerShopPortalStatsQuery(
  tenantId: Ref<number | null>,
  shopType: Ref<ShopType | null>,
) {
  return useQuery({
    queryKey: computed(() => [
      ...shopOrderQueryKeys.customerOrders(tenantId.value ?? 0, null, shopType.value),
      'portalStats',
    ]),
    queryFn: () => {
      const type = shopType.value;
      if (!tenantId.value || !type) {
        return Promise.resolve([]);
      }
      return shopOrderRepository.listCustomerShopOrders(Number(tenantId.value), {
        limit: 100,
        shopType: type,
      });
    },
    enabled: computed(() => !!tenantId.value && !!shopType.value),
    staleTime: 60_000,
  });
}
