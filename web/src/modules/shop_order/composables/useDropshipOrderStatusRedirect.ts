import { type Ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import type { ShopOrderStatus } from '../types';
import {
  DROPSHIP_ORDER_DETAIL_ROUTE,
  DROPSHIP_ORDER_DETAIL_PROCESSING_ROUTE,
  DROPSHIP_ORDER_DETAIL_READY_FOR_PICKUP_ROUTE,
} from './dropshipOrderDetailRoutes';

export type DropshipOrderDetailView = 'confirmed' | 'processing' | 'ready';

const READY_STATUSES = new Set<ShopOrderStatus>([
  'ready_for_pickup',
  'shipped',
  'delivered',
  'payment_received',
]);

export function resolveDropshipOrderDetailRouteName(
  status: ShopOrderStatus | null | undefined,
): string | null {
  if (!status) return null;
  if (status === 'confirmed') return DROPSHIP_ORDER_DETAIL_ROUTE;
  if (status === 'processing') return DROPSHIP_ORDER_DETAIL_PROCESSING_ROUTE;
  if (READY_STATUSES.has(status)) return DROPSHIP_ORDER_DETAIL_READY_FOR_PICKUP_ROUTE;
  return null;
}

export function useDropshipOrderStatusRedirect(options: {
  expectedView: DropshipOrderDetailView;
  status: Ref<ShopOrderStatus | null | undefined>;
  orderId: Ref<number>;
  tenantSlug: Ref<string | null | undefined>;
  enabled?: Ref<boolean>;
}) {
  const router = useRouter();

  watch(
    () => [options.status.value, options.enabled?.value ?? true, options.orderId.value] as const,
    ([status, enabled, orderId]) => {
      if (!enabled || !status || !orderId) return;

      const targetRouteName = resolveDropshipOrderDetailRouteName(status);
      if (!targetRouteName) return;

      const expectedRouteName =
        options.expectedView === 'confirmed'
          ? DROPSHIP_ORDER_DETAIL_ROUTE
          : options.expectedView === 'processing'
            ? DROPSHIP_ORDER_DETAIL_PROCESSING_ROUTE
            : DROPSHIP_ORDER_DETAIL_READY_FOR_PICKUP_ROUTE;

      if (targetRouteName === expectedRouteName) return;

      void router.replace({
        name: targetRouteName,
        params: {
          id: orderId,
          tenantSlug: options.tenantSlug.value ?? undefined,
        },
      });
    },
    { immediate: true },
  );
}
