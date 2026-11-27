import type { PpOrderLine, PpStaffOrderLineUpdatePayload } from '../types/ppPurchaseRequest';
import { ppPlacementImpliesAddedToCart } from './ppOrderLinePlacement';

export function buildPpStaffOrderLineUpdate(
  line: PpOrderLine,
  patch: Partial<Omit<PpStaffOrderLineUpdatePayload, 'lineId'>> = {},
): PpStaffOrderLineUpdatePayload {
  const placement_status = patch.placement_status ?? line.placement_status;
  return {
    lineId: line.id,
    url: line.url,
    needed_qty: line.needed_qty,
    description: line.description,
    product_name: line.product_name,
    image_url: line.image_url,
    unit_price: line.unit_price,
    pp_supplier_group_id: line.pp_supplier_group_id,
    shipment_id: line.shipment_id,
    placed_qty: line.placed_qty,
    status: line.status,
    ...patch,
    placement_status,
    is_added_to_cart: ppPlacementImpliesAddedToCart(placement_status),
  };
}
