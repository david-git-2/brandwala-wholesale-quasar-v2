import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { useRoute } from 'vue-router';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import { useAuthStore } from 'src/modules/workspace/submodules/auth/stores/authStore';
import type { OrderGlanceBucket } from 'src/modules/workspace/submodules/dashboard/utils/customerDashboardStatus';
import { resolveCustomerShopTypePath, shopTypeEnumFromCustomerRoute } from '../utils/catalogShop';

export function useCustomerOrdersQuery(
  statusBucket?: Ref<OrderGlanceBucket | null | undefined>,
) {
  const authStore = useAuthStore();
  const route = useRoute();
  const tenantId = computed(() => authStore.tenantId ?? 0);
  const bucket = computed(() => statusBucket?.value ?? null);
  const shopTypePath = computed(() => resolveCustomerShopTypePath(route, authStore.tenantId));
  const shopType = computed(() => shopTypeEnumFromCustomerRoute(route, authStore.tenantId));
  return useQuery({
    queryKey: computed(() =>
      shopOrderQueryKeys.customerOrders(tenantId.value, bucket.value, shopTypePath.value),
    ),
    queryFn: () => {
      const type = shopType.value;
      if (!type) {
        return Promise.resolve([]);
      }
      return shopOrderRepository.listCustomerShopOrders(tenantId.value, {
        limit: 20,
        statusBucket: bucket.value,
        shopType: type,
      });
    },
    enabled: computed(() => tenantId.value > 0 && shopType.value != null),
    staleTime: 60 * 1000,
  });
}

export function useCustomerDashboardOrdersQuery() {
  return useCustomerOrdersQuery();
}
