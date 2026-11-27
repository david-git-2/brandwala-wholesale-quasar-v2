import type { PpOrderLinePlacementStatus } from '../types/ppPurchaseRequest';

export const PP_ORDER_LINE_PLACEMENT_STATUSES = [
  'none',
  'added_to_cart',
  'order_placed',
  'cargo_warehouse',
  'in_flight',
  'local_warehouse',
  'delivered',
  'lost',
] as const satisfies readonly PpOrderLinePlacementStatus[];

export const PP_ORDER_LINE_PLACEMENT_LABELS: Record<PpOrderLinePlacementStatus, string> = {
  none: 'None',
  added_to_cart: 'Added to cart',
  order_placed: 'Order placed',
  cargo_warehouse: 'Cargo warehouse',
  in_flight: 'In flight',
  local_warehouse: 'Local warehouse',
  delivered: 'Delivered',
  lost: 'Lost',
};

export const PP_ORDER_LINE_PLACEMENT_OPTIONS = PP_ORDER_LINE_PLACEMENT_STATUSES.map((value) => ({
  label: PP_ORDER_LINE_PLACEMENT_LABELS[value],
  value,
}));

const PLACEMENT_SET = new Set<string>(PP_ORDER_LINE_PLACEMENT_STATUSES);

export function normalizePpOrderLinePlacementStatus(value: unknown): PpOrderLinePlacementStatus {
  if (typeof value === 'string' && PLACEMENT_SET.has(value)) {
    return value as PpOrderLinePlacementStatus;
  }
  return 'none';
}

export function ppPlacementImpliesAddedToCart(status: PpOrderLinePlacementStatus): boolean {
  return status !== 'none';
}