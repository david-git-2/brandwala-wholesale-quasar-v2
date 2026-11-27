import type {
  PpOrderLinePlacementStatus,
  PpOrderLineStatus,
} from '../types/ppPurchaseRequest';

export const PP_ORDER_LINE_PLACEMENT_STATUSES = [
  'none',
  'draft',
  'requested',
  'processing',
  'cancelled',
  'added_to_cart',
  'order_placed',
  'cargo_warehouse',
  'in_flight',
  'local_warehouse',
  'delivered',
  'lost',
] as const satisfies readonly PpOrderLinePlacementStatus[];

/** Staff fulfillment dropdown (`none` omitted; `cancelled` last). */
const PP_ORDER_LINE_STAFF_PLACEMENT_MIDDLE = PP_ORDER_LINE_PLACEMENT_STATUSES.filter(
  (value) => value !== 'none' && value !== 'cancelled',
);
export const PP_ORDER_LINE_STAFF_PLACEMENT_STATUSES = [
  ...PP_ORDER_LINE_STAFF_PLACEMENT_MIDDLE,
  'cancelled',
] as const satisfies readonly PpOrderLinePlacementStatus[];

export const PP_ORDER_LINE_PLACEMENT_LABELS: Record<PpOrderLinePlacementStatus, string> = {
  none: 'None',
  draft: 'Draft',
  requested: 'Requested',
  processing: 'Processing',
  cancelled: 'Cancelled',
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

export const PP_ORDER_LINE_STAFF_PLACEMENT_OPTIONS = PP_ORDER_LINE_STAFF_PLACEMENT_STATUSES.map(
  (value) => ({
    label: PP_ORDER_LINE_PLACEMENT_LABELS[value],
    value,
  }),
);

export function ppSupplierPlacementSelectOptions(current: PpOrderLinePlacementStatus) {
  if (current === 'added_to_cart') {
    return [
      { label: PP_ORDER_LINE_PLACEMENT_LABELS.added_to_cart, value: 'added_to_cart' as const },
      { label: PP_ORDER_LINE_PLACEMENT_LABELS.order_placed, value: 'order_placed' as const },
    ];
  }

  return [
    {
      label: PP_ORDER_LINE_PLACEMENT_LABELS[current] ?? current,
      value: current,
    },
  ];
}

export function canSupplierEditPlacedQty(placement: PpOrderLinePlacementStatus): boolean {
  return placement === 'added_to_cart' || placement === 'order_placed';
}

export function canSupplierChangePlacement(placement: PpOrderLinePlacementStatus): boolean {
  return placement === 'added_to_cart';
}

const PLACEMENT_SET = new Set<string>(PP_ORDER_LINE_PLACEMENT_STATUSES);

const PLACEMENT_NOT_IN_CART = new Set<string>([
  'none',
  'draft',
  'requested',
  'processing',
  'cancelled',
]);

export function normalizePpOrderLinePlacementStatus(value: unknown): PpOrderLinePlacementStatus {
  if (typeof value === 'string' && PLACEMENT_SET.has(value)) {
    return value as PpOrderLinePlacementStatus;
  }
  return 'none';
}

export function ppPlacementImpliesAddedToCart(status: PpOrderLinePlacementStatus): boolean {
  return !PLACEMENT_NOT_IN_CART.has(status);
}

export function derivePpLineStatusFromPlacement(
  placement: PpOrderLinePlacementStatus,
): PpOrderLineStatus {
  switch (placement) {
    case 'draft':
      return 'draft';
    case 'requested':
    case 'none':
      return 'requested';
    case 'processing':
    case 'added_to_cart':
    case 'order_placed':
    case 'cargo_warehouse':
    case 'in_flight':
    case 'local_warehouse':
    case 'lost':
      return 'processing';
    case 'delivered':
      return 'done';
    case 'cancelled':
      return 'cancelled';
    default:
      return 'requested';
  }
}