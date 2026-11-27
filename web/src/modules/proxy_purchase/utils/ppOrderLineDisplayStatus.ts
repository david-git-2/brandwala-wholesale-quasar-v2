import type { PpOrderLine } from '../types/ppPurchaseRequest';
import { PP_ORDER_LINE_PLACEMENT_LABELS } from './ppOrderLinePlacement';

export function ppOrderLineDisplayStatus(line: PpOrderLine): string {
  if (line.placement_status === 'cancelled' || line.status === 'cancelled') return 'Cancelled';
  if (line.placement_status === 'delivered' || line.status === 'done') return 'Delivered';

  if (line.placement_status === 'order_placed') {
    const placed = line.placed_qty ?? line.needed_qty;
    if (placed < line.needed_qty) return 'Order placed partially';
  }

  if (line.placement_status !== 'none') {
    return PP_ORDER_LINE_PLACEMENT_LABELS[line.placement_status];
  }

  if (line.status === 'processing') return 'Processing';
  if (line.status === 'requested') return 'Requested';
  if (line.status === 'draft') return 'Draft';

  return line.status;
}