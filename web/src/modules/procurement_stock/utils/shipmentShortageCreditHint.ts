import type { ShipmentItemOutcome } from '../repositories/globalShipmentRepository';

/** Read-only hint for commercial AP credit note (missing/damaged qty × purchase price). */
export function shipmentShortageCreditHintBdt(
  items: Array<{ id: number; purchase_price?: number | null }>,
  outcomes: ShipmentItemOutcome[],
): number {
  const priceByItem = new Map(
    items.map((i) => [i.id, Number(i.purchase_price) || 0]),
  );
  let sum = 0;
  for (const o of outcomes) {
    if (o.reason !== 'missing' && o.reason !== 'damaged') continue;
    const qty = Number(o.quantity) || 0;
    if (qty <= 0) continue;
    const unit = Number(o.purchase_price) || priceByItem.get(o.shipment_item_id) || 0;
    sum += unit * qty;
  }
  return Math.round(sum * 100) / 100;
}
