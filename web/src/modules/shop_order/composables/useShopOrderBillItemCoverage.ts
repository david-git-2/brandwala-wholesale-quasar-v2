import { useQuery } from '@tanstack/vue-query';
import { computed, unref, type MaybeRef } from 'vue';
import {
  shopOrderRepository,
  type ShopOrderBillItemCoverageRow,
} from '../repositories/shopOrderRepository';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';

export function useShopOrderBillItemCoverage(options: {
  tenantId: MaybeRef<number | null>;
  orderId: MaybeRef<number | null>;
  enabled?: MaybeRef<boolean>;
}) {
  const tenantId = computed(() => unref(options.tenantId));
  const orderId = computed(() => unref(options.orderId));
  const enabled = computed(
    () =>
      (unref(options.enabled) ?? true) &&
      tenantId.value != null &&
      orderId.value != null &&
      orderId.value > 0,
  );

  const query = useQuery({
    queryKey: computed(() =>
      shopOrderQueryKeys.billItemCoverage(tenantId.value ?? 0, orderId.value ?? 0),
    ),
    queryFn: () => shopOrderRepository.getShopOrderBillItemCoverage(tenantId.value!, orderId.value!),
    enabled,
  });

  const coverageByItemId = computed(() => {
    const map = new Map<number, ShopOrderBillItemCoverageRow>();
    for (const row of query.data.value?.items ?? []) {
      map.set(row.order_item_id, row);
    }
    return map;
  });

  return {
    data: query.data,
    coverageByItemId,
    isLoading: computed(() => query.isLoading.value),
    isError: computed(() => query.isError.value),
    refetch: query.refetch,
  };
}