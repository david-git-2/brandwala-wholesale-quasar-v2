import { useQuery } from '@tanstack/vue-query';
import { computed, unref, type MaybeRef } from 'vue';
import { billsRepository } from 'src/modules/finance/submodules/bills_pays/repositories/billsRepository';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import type { ShopOrderBillListItem } from '../types/shopOrderBillList';

export function parseShopOrderBills(raw: unknown): ShopOrderBillListItem[] {
  if (!Array.isArray(raw)) return [];
  return raw as ShopOrderBillListItem[];
}

export function useShopOrderBills(options: {
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
      orderId.value != null,
  );

  const listQuery = useQuery({
    queryKey: computed(() =>
      shopOrderQueryKeys.billsForShopOrder(tenantId.value ?? 0, orderId.value ?? 0),
    ),
    queryFn: async () => {
      const raw = await billsRepository.listBillsForSource({
        tenantId: tenantId.value!,
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
