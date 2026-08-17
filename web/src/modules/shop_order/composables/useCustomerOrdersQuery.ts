import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { OrderGlanceBucket } from 'src/modules/dashboard/utils/customerDashboardStatus';

export function useCustomerOrdersQuery(
  statusBucket?: Ref<OrderGlanceBucket | null | undefined>,
) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId ?? 0);
  const bucket = computed(() => statusBucket?.value ?? null);
  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.customerOrders(tenantId.value, bucket.value)),
    queryFn: () =>
      shopOrderRepository.listCustomerShopOrders(tenantId.value, {
        limit: 20,
        statusBucket: bucket.value,
      }),
    enabled: computed(() => tenantId.value > 0),
    staleTime: 60 * 1000,
  });
}

export function useCustomerDashboardOrdersQuery() {
  return useCustomerOrdersQuery();
}
