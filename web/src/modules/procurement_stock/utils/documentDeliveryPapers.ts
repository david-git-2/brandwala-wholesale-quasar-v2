import type { ProcurementDemandItem } from '../repositories/procurementDemandRepository';
import { getItemNeedQuantity, getItemRemainingToDeliver } from '../repositories/procurementDemandRepository';

/** Normalized catalog / PBC fulfillment statuses where delivery papers belong on the document. */
const DELIVERY_PAPER_VISIBLE_STATUSES = new Set([
  'procuring',
  'dispatch',
  'delivered',
  'closed',
  'packed', // legacy DB / alias → dispatch in UI
]);

const DELIVERY_PAPER_CREATE_STATUSES = new Set(['procuring', 'dispatch', 'packed']);

export function canShowDocumentDeliveryPapers(
  normalizedStatus: string,
  items: Array<Pick<ProcurementDemandItem, 'quantity' | 'delivered_quantity' | 'remaining_to_deliver'>>,
): boolean {
  const st = String(normalizedStatus || '').toLowerCase();
  if (DELIVERY_PAPER_VISIBLE_STATUSES.has(st)) return true;
  return items.some((item) => getItemRemainingToDeliver(item as ProcurementDemandItem) > 0);
}

export function canCreateDocumentDeliveryPaper(normalizedStatus: string): boolean {
  const st = String(normalizedStatus || '').toLowerCase();
  return DELIVERY_PAPER_CREATE_STATUSES.has(st);
}

export function documentDeliveryPaperChipLabel(paperId: number, status: string): string {
  return `DP-${paperId}`;
}

export { getItemNeedQuantity, getItemRemainingToDeliver };
