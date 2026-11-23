import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import type { ShopType } from 'src/modules/shop_order/types';
import { customerDashboardRepository } from '../repositories/customerDashboardRepository';

export const customerDashboardQueryKeys = {
  summary: (tenantId: number, shopType: ShopType | null) =>
    ['customer', 'dashboard', { tenantId, shopType }] as const,
};

export function useCustomerDashboardQuery(
  tenantId: Ref<number | null>,
  shopType: Ref<ShopType | null>,
) {
  return useQuery({
    queryKey: computed(() =>
      customerDashboardQueryKeys.summary(tenantId.value ?? 0, shopType.value),
    ),
    queryFn: () => {
      const id = tenantId.value;
      const type = shopType.value;
      if (!id || !type) {
        return Promise.resolve(null);
      }
      return customerDashboardRepository.getCustomerDashboardSummary(id, type);
    },
    enabled: computed(() => !!tenantId.value && !!shopType.value),
    staleTime: 60 * 1000,
  });
}
