import { useQuery } from '@tanstack/vue-query';
import { computed, unref, type MaybeRef } from 'vue';
import { billsRepository } from 'src/modules/bills_pays/repositories/billsRepository';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import type { ShopOrderBillListItem } from '../types/shopOrderBillList';

function parseShopOrderBills(raw: unknown): ShopOrderBillListItem[] {
  if (!Array.isArray(raw)) return [];
  return raw as ShopOrderBillListItem[];
}

export function useShopOrderBills(options: {
  parentTenantId: MaybeRef<number | null>;
  orderId: MaybeRef<number | null>;
  enabled?: MaybeRef<boolean>;
}) {
  const parentTenantId = computed(() => unref(options.parentTenantId));
  const orderId = computed(() => unref(options.orderId));
  const enabled = computed(
    () =>
      (unref(options.enabled) ?? true) &&
      parentTenantId.value != null &&
      orderId.value != null,
  );

  const listQuery = useQuery({
    queryKey: computed(() =>
      shopOrderQueryKeys.billsForShopOrder(parentTenantId.value ?? 0, orderId.value ?? 0),
    ),
    queryFn: async () => {
      const raw = await billsRepository.listBillsForSource({
        parentTenantId: parentTenantId.value!,
        sourceType: 'shop_order',
        sourceId: String(orderId.value!),
      });
      return parseShopOrderBills(raw);
    },
    enabled,
  });

  const bills = computed(() => listQuery.data.value ?? []);

  return {
    bills,
    isLoading: computed(() => listQuery.isLoading.value),
    isError: computed(() => listQuery.isError.value),
    refetch: listQuery.refetch,
  };
}
