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
  'reseller_paid',
]);

export function resolveDropshipOrderDetailView(
  status: ShopOrderStatus | null | undefined,
): DropshipOrderDetailView | null {
  if (!status) return null;
  if (status === 'confirmed') return 'confirmed';
  if (status === 'processing') return 'processing';
  if (READY_STATUSES.has(status)) return 'ready';
  return null;
}

export function resolveDropshipOrderDetailRouteName(
  status: ShopOrderStatus | null | undefined,
): string | null {
  if (!resolveDropshipOrderDetailView(status)) return null;
  return DROPSHIP_ORDER_DETAIL_ROUTE;
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
