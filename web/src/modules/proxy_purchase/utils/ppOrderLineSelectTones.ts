import type {
  PpOrderLinePlacementStatus,
  PpOrderLineStatus,
} from '../types/ppPurchaseRequest';

export const ppPlacementCellClass = (value: PpOrderLinePlacementStatus) =>
  `pp-order-line-tone--placement-${value}`;

export const ppStatusCellClass = (value: PpOrderLineStatus) =>
  `pp-order-line-tone--status-${value}`;
