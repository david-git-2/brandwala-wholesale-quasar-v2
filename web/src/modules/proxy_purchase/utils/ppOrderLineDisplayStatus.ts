import type { PpOrderLine } from '../types/ppPurchaseRequest';

const shipmentStatusLabels: Record<string, string> = {
  draft: 'Supplier warehouse',
  in_transit: 'In transit',
  received: 'Delivered',
  cancelled: 'Cancelled',
};

export function ppOrderLineDisplayStatus(line: PpOrderLine): string {
  if (line.status === 'cancelled') return 'Cancelled';
  if (line.status === 'done') return 'Delivered';
  if (line.placement_status === 'not_available') return 'Not available';

  if (line.placement_status === 'order_placed') {
    const placed = line.placed_qty ?? line.needed_qty;
    if (placed < line.needed_qty) return 'Order placed partially';
    return 'Order placed';
  }

  if (line.shipment_id && line.shipment_status) {
    return shipmentStatusLabels[line.shipment_status] ?? line.shipment_status;
  }

  if (line.is_added_to_cart) return 'Added to cart';
  if (line.status === 'processing') return 'Processing';
  if (line.status === 'requested') return 'Requested';
  if (line.status === 'draft') return 'Draft';

  return line.status;
}