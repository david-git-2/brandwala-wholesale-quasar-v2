import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';

export const DROPSHIP_ORDER_DETAIL_V2_ROUTE = 'app-shop-dropship-order-detail-v2-page';
export const DROPSHIP_ORDER_DETAIL_V2_PROCESSING_ROUTE =
  'app-shop-dropship-order-detail-v2-processing-page';
export const DROPSHIP_ORDER_DETAIL_V2_READY_FOR_PICKUP_ROUTE =
  'app-shop-dropship-order-detail-v2-ready-for-pickup-page';
export const DROPSHIP_ORDER_DETAIL_V2_CUSTOMER_INVOICE_PREVIEW_ROUTE =
  'app-shop-dropship-order-v2-customer-invoice-preview';
export const DROPSHIP_ORDER_DETAIL_CLASSIC_ROUTE = 'app-shop-dropship-order-detail-page';

const V2_ROUTE_NAMES = new Set([
  DROPSHIP_ORDER_DETAIL_V2_ROUTE,
  DROPSHIP_ORDER_DETAIL_V2_PROCESSING_ROUTE,
  DROPSHIP_ORDER_DETAIL_V2_READY_FOR_PICKUP_ROUTE,
]);

export function useDropshipOrderDetailUiToggle() {
  const route = useRoute();
  const router = useRouter();

  const orderId = computed(() => String(route.params.id ?? ''));
  const isV2 = computed(() => V2_ROUTE_NAMES.has(String(route.name ?? '')));

  const toggleUi = () => {
    if (!orderId.value) return;

    void router.push({
      name: isV2.value ? DROPSHIP_ORDER_DETAIL_CLASSIC_ROUTE : DROPSHIP_ORDER_DETAIL_V2_ROUTE,
      params: {
        id: orderId.value,
        tenantSlug: route.params.tenantSlug,
      },
    });
  };

  return {
    orderId,
    isV2,
    toggleUi,
  };
}
