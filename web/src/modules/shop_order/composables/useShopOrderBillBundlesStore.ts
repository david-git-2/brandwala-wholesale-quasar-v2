import { computed, unref, watch, type MaybeRef } from 'vue';
import { storeToRefs } from 'pinia';
import { useShopOrderStore } from '../stores/shopOrderStore';

/** Load full desk bundles for all order bills into Pinia when the Bills tab is active. */
export function useShopOrderBillBundlesStore(options: {
  tenantId: MaybeRef<number | null>;
  orderId: MaybeRef<number | null>;
  enabled: MaybeRef<boolean>;
}) {
  const shopOrderStore = useShopOrderStore();
  const { orderBillBundles, orderBillBundlesMissingIds, loadingOrderBillBundles, orderBillBundlesOrderId } =
    storeToRefs(shopOrderStore);

  watch(
    () =>
      [
        unref(options.enabled),
        unref(options.tenantId),
        unref(options.orderId),
      ] as const,
    ([active, tenantId, orderId]) => {
      if (active && tenantId != null && tenantId > 0 && orderId != null && orderId > 0) {
        void shopOrderStore.fetchOrderBillDetailBundles(tenantId, orderId);
        return;
      }
      shopOrderStore.clearOrderBillDetailBundles();
    },
    { immediate: true },
  );

  const bundlesForOrder = computed(() => {
    const oid = unref(options.orderId);
    if (oid == null || orderBillBundlesOrderId.value !== oid) return [];
    return orderBillBundles.value;
  });

  return {
    bundles: bundlesForOrder,
    missingIds: orderBillBundlesMissingIds,
    isLoading: loadingOrderBillBundles,
    bundleById: (billId: number) => shopOrderStore.orderBillBundleById(billId),
    refetch: () => {
      const tenantId = unref(options.tenantId);
      const orderId = unref(options.orderId);
      if (tenantId != null && tenantId > 0 && orderId != null && orderId > 0) {
        return shopOrderStore.fetchOrderBillDetailBundles(tenantId, orderId);
      }
      return Promise.resolve();
    },
  };
}