import { getCustomerCatalogStatusLabel, normalizeCatalogOrderStatus } from './catalogOrderStatus';
import type { ShopType } from '../types';

export function formatCustomerOrderStatusLabel(
  status: string,
  shopType?: ShopType | null,
): string {
  if (shopType === 'vendor_catalog') {
    return getCustomerCatalogStatusLabel(status);
  }
  switch (status) {
    case 'submitted':
      return 'Submitted';
    case 'costing_pending':
      return 'Costing Pending';
    case 'priced':
      return 'Priced';
    case 'countered':
      return 'Countered';
    case 'final_offered':
      return 'Final Offered';
    case 'confirmed':
      return 'Confirmed';
    case 'procuring':
      return 'Procuring';
    case 'ready_for_shipment':
    case 'ordered':
      return 'Ready for shipment';
    case 'negotiating':
      return 'Negotiating';
    case 'placed':
      return 'Placed';
    case 'fulfilled':
      return 'Fulfilled';
    case 'processing':
      return 'Processing';
    case 'ready_for_pickup':
      return 'Ready for Pickup';
    case 'shipped':
      return 'Shipped';
    case 'delivered':
      return 'Delivered';
    case 'returned':
      return 'Returned';
    case 'cancelled':
      return 'Cancelled';
    case 'payment_received':
      return 'Payment Received';
    default:
      return status.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
  }
}

export function getCustomerOrderStatusColor(status: string): string {
  switch (normalizeCatalogOrderStatus(status)) {
    case 'draft':
      return 'grey-7';
    case 'submitted':
      return 'blue-7';
    case 'costing_pending':
      return 'deep-orange-7';
    case 'negotiating':
    case 'countered':
      return 'amber-9';
    case 'priced':
      return 'cyan-8';
    case 'final_offered':
      return 'purple-7';
    case 'confirmed':
      return 'green-7';
    case 'procuring':
      return 'blue-9';
    case 'ready_for_shipment':
    case 'ordered':
      return 'indigo-7';
    case 'placed':
      return 'indigo-7';
    case 'fulfilled':
      return 'teal-7';
    case 'processing':
      return 'purple-7';
    case 'ready_for_pickup':
      return 'indigo-7';
    case 'shipped':
      return 'light-blue-7';
    case 'delivered':
      return 'green-8';
    case 'returned':
      return 'deep-orange-8';
    case 'payment_received':
      return 'emerald-7';
    case 'cancelled':
      return 'red-7';
    default:
      return 'grey-7';
  }
}

export function getCustomerOrderStatusIcon(status: string): string {
  switch (normalizeCatalogOrderStatus(status)) {
    case 'confirmed':
    case 'processing':
      return 'ph ph-check-circle';
    case 'ready_for_pickup':
      return 'ph ph-package';
    case 'shipped':
      return 'ph ph-truck';
    case 'delivered':
    case 'payment_received':
      return 'ph ph-house';
    case 'cancelled':
    case 'returned':
      return 'ph ph-x-circle';
    default:
      return 'ph ph-clock';
  }
}

export function getCustomerOrderFocusedSteps(
  normalizedStatus: string,
  statusSequence: string[],
): { prev: string | null; next: string | null } {
  const lookupStatus = normalizeCatalogOrderStatus(normalizedStatus);
  const idx = statusSequence.indexOf(lookupStatus);
  if (idx === -1) {
    return { prev: null, next: null };
  }
  return {
    prev: idx > 0 ? statusSequence[idx - 1] : null,
    next: idx < statusSequence.length - 1 ? statusSequence[idx + 1] : null,
  };
}
