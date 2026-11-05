import type { DeliveryPaperDetailItem } from '../repositories/procurementDemandRepository';
import type { DemandStockPickSelection } from '../components/ProcurementDemandStockPickDialog.vue';
import { mapPaperPicksFromApi } from './demandStockPickMapping';

export type DeliveryPaperStatusQty = {
  packed: number;
  accepted: number;
  conditioned: number;
  rejected: number;
};

export type DeliveryPaperLineDraftState = DeliveryPaperStatusQty & {
  stockPicks: DemandStockPickSelection[];
};

export const emptyDeliveryPaperStatusQty = (): DeliveryPaperStatusQty => ({
  packed: 0,
  accepted: 0,
  conditioned: 0,
  rejected: 0,
});

export const emptyDeliveryPaperLineDraft = (): DeliveryPaperLineDraftState => ({
  ...emptyDeliveryPaperStatusQty(),
  stockPicks: [],
});

export const stockPicksFromPaperPicks = (
  item: Pick<DeliveryPaperDetailItem, 'paper_picks'>,
): DemandStockPickSelection[] => {
  const packedRows = (item.paper_picks ?? []).filter(
    (pick) => (pick.line_status ?? '').toLowerCase() === 'packed',
  );
  if (!packedRows.length) return [];
  return mapPaperPicksFromApi(
    packedRows.map((pick) => ({
      global_stock_id: pick.global_stock_id,
      quantity: pick.quantity,
      shipment_name: pick.shipment_name,
      location_name: pick.location_name,
      close_action: null,
    })),
  );
};

export const lineDraftFromPaperPicks = (
  item: Pick<DeliveryPaperDetailItem, 'paper_picks'>,
): DeliveryPaperLineDraftState => ({
  ...statusQtyFromPaperPicks(item),
  stockPicks: stockPicksFromPaperPicks(item),
});

export const statusQtyFromPaperPicks = (
  item: Pick<DeliveryPaperDetailItem, 'paper_picks'>,
): DeliveryPaperStatusQty => {
  const out = emptyDeliveryPaperStatusQty();
  for (const pick of item.paper_picks ?? []) {
    const qty = Math.max(0, Math.trunc(Number(pick.quantity ?? 0)));
    if (qty <= 0) continue;
    const status = (pick.line_status ?? '').toLowerCase();
    if (status === 'packed') out.packed += qty;
    else if (status === 'accepted') out.accepted += qty;
    else if (status === 'conditioned') out.conditioned += qty;
    else if (status === 'rejected') out.rejected += qty;
  }
  return out;
};

export const deliveryPaperLineTotalQty = (qty: DeliveryPaperStatusQty): number =>
  Math.max(0, Math.trunc(qty.packed)) +
  Math.max(0, Math.trunc(qty.accepted)) +
  Math.max(0, Math.trunc(qty.conditioned)) +
  Math.max(0, Math.trunc(qty.rejected));

export const deliveryPaperLineHasPaperQty = (
  item: Pick<DeliveryPaperDetailItem, 'paper_picks'>,
  draft?: DeliveryPaperStatusQty,
): boolean => {
  if (draft && deliveryPaperLineTotalQty(draft) > 0) return true;
  return deliveryPaperLineTotalQty(statusQtyFromPaperPicks(item)) > 0;
};

export type DeliveryPaperStockLotDisplay = {
  globalStockId: number;
  shipmentName: string | null;
  quantity: number;
};

const stockLotsFromPaperPicksWithStatuses = (
  picks: NonNullable<DeliveryPaperDetailItem['paper_picks']>,
  statuses: ReadonlySet<string>,
): DeliveryPaperStockLotDisplay[] => {
  const byStock = new Map<number, DeliveryPaperStockLotDisplay>();
  for (const pick of picks) {
    const status = (pick.line_status ?? '').toLowerCase();
    if (!statuses.has(status)) continue;
    if (pick.global_stock_id == null) continue;
    const qty = Math.max(0, Math.trunc(Number(pick.quantity ?? 0)));
    if (qty <= 0) continue;
    const id = pick.global_stock_id;
    const existing = byStock.get(id);
    if (existing) {
      existing.quantity += qty;
    } else {
      byStock.set(id, {
        globalStockId: id,
        shipmentName: pick.shipment_name ?? null,
        quantity: qty,
      });
    }
  }
  return [...byStock.values()].sort((a, b) => a.globalStockId - b.globalStockId);
};

/** Stock lots picked on this paper line (still shows lots after outcome splits move off packed). */
export const deliveryPaperStockLotsFromItem = (
  item: Pick<DeliveryPaperDetailItem, 'paper_picks'>,
): DeliveryPaperStockLotDisplay[] => {
  const picks = item.paper_picks ?? [];
  const packed = stockLotsFromPaperPicksWithStatuses(picks, new Set(['packed']));
  if (packed.length) return packed;
  return stockLotsFromPaperPicksWithStatuses(
    picks,
    new Set(['accepted', 'conditioned', 'rejected']),
  );
};

export const deliveryPaperLinePackedDisplayQty = (
  item: Pick<DeliveryPaperDetailItem, 'paper_picks'>,
  draft: DeliveryPaperStatusQty,
): number => {
  const packed = Math.max(0, Math.trunc(draft.packed));
  if (packed > 0) return packed;
  const lots = deliveryPaperStockLotsFromItem(item);
  const lotTotal = lots.reduce((sum, lot) => sum + lot.quantity, 0);
  if (lotTotal > 0) return lotTotal;
  return deliveryPaperLineTotalQty(draft);
};

export const statusQtyToSaveSplits = (qty: DeliveryPaperStatusQty, includePacked = true) =>
  (
    [
      ...(includePacked ? [{ quantity: qty.packed, status: 'packed' as const }] : []),
      { quantity: qty.accepted, status: 'accepted' as const },
      { quantity: qty.conditioned, status: 'conditioned' as const },
      { quantity: qty.rejected, status: 'rejected' as const },
    ] as const
  ).filter((row) => row.quantity > 0);

export const sumPackedStockPickQty = (picks: DemandStockPickSelection[]): number =>
  picks.reduce((sum, pick) => sum + Math.max(0, pick.quantity), 0);

export const mapPackedStockPicksToSave = (picks: DemandStockPickSelection[]) =>
  picks
    .filter((pick) => pick.quantity > 0)
    .map((pick) => ({
      global_stock_id: pick.globalStockId,
      quantity: pick.quantity,
    }));

export const parseStatusQtyInput = (value: string | number | null): number => {
  if (value === '' || value === null) return 0;
  const n = Math.trunc(Number(value));
  return Number.isFinite(n) && n >= 0 ? n : 0;
};

export type DeliveryPaperLockedOutcomeQty = DeliveryPaperStatusQty;

const pickSplitIsApplied = (
  pick: NonNullable<DeliveryPaperDetailItem['paper_picks']>[number],
): boolean => {
  if (pick.is_applied === true) return true;
  if (pick.invoice_id != null && Number(pick.invoice_id) > 0) return true;
  if (pick.returned_at != null && String(pick.returned_at).trim() !== '') return true;
  return false;
};

export const lockedOutcomeQtyFromPaperPicks = (
  item: Pick<DeliveryPaperDetailItem, 'paper_picks'>,
): DeliveryPaperLockedOutcomeQty => {
  const out = emptyDeliveryPaperStatusQty();
  for (const pick of item.paper_picks ?? []) {
    if (!pickSplitIsApplied(pick)) continue;
    const qty = Math.max(0, Math.trunc(Number(pick.quantity ?? 0)));
    if (qty <= 0) continue;
    const status = (pick.line_status ?? '').toLowerCase();
    if (status === 'accepted') out.accepted += qty;
    else if (status === 'conditioned') out.conditioned += qty;
    else if (status === 'rejected') out.rejected += qty;
  }
  return out;
};

export const pendingOutcomeFieldQty = (
  draft: DeliveryPaperStatusQty,
  locked: DeliveryPaperLockedOutcomeQty,
  field: 'accepted' | 'conditioned' | 'rejected',
): number => Math.max(0, draft[field] - locked[field]);

export const plannedOutcomeQtyFromDraft = (
  draft: DeliveryPaperStatusQty,
  locked: DeliveryPaperLockedOutcomeQty,
): DeliveryPaperStatusQty => ({
  packed: draft.packed,
  accepted: pendingOutcomeFieldQty(draft, locked, 'accepted'),
  conditioned: pendingOutcomeFieldQty(draft, locked, 'conditioned'),
  rejected: pendingOutcomeFieldQty(draft, locked, 'rejected'),
});

export const isOutcomeFieldFullyLocked = (
  draft: DeliveryPaperStatusQty,
  locked: DeliveryPaperLockedOutcomeQty,
  field: 'accepted' | 'conditioned' | 'rejected',
): boolean => locked[field] > 0 && pendingOutcomeFieldQty(draft, locked, field) <= 0;

export const outcomeQtyBelowLockedMessage = (
  draft: DeliveryPaperStatusQty,
  locked: DeliveryPaperLockedOutcomeQty,
): string | null => {
  if (draft.accepted < locked.accepted) {
    return `Accepted cannot be below ${locked.accepted} already invoiced.`;
  }
  if (draft.conditioned < locked.conditioned) {
    return `Condition cannot be below ${locked.conditioned} already invoiced.`;
  }
  if (draft.rejected < locked.rejected) {
    return `Rejected cannot be below ${locked.rejected} already returned.`;
  }
  return null;
};

export const outcomeQtyTotal = (qty: DeliveryPaperStatusQty): number =>
  qty.accepted + qty.conditioned + qty.rejected;

export const pendingOutcomeQtyTotal = (
  draft: DeliveryPaperStatusQty,
  locked: DeliveryPaperLockedOutcomeQty,
): number =>
  pendingOutcomeFieldQty(draft, locked, 'accepted') +
  pendingOutcomeFieldQty(draft, locked, 'conditioned') +
  pendingOutcomeFieldQty(draft, locked, 'rejected');

export const pendingOutcomeQtyExceedsPacked = (
  draft: DeliveryPaperStatusQty,
  locked: DeliveryPaperLockedOutcomeQty,
): boolean => pendingOutcomeQtyTotal(draft, locked) > draft.packed;

const pendingOnOtherOutcomeFields = (
  draft: DeliveryPaperStatusQty,
  locked: DeliveryPaperLockedOutcomeQty,
  field: 'accepted' | 'conditioned' | 'rejected',
): number => {
  const fields: Array<'accepted' | 'conditioned' | 'rejected'> = [
    'accepted',
    'conditioned',
    'rejected',
  ];
  return fields
    .filter((f) => f !== field)
    .reduce((sum, f) => sum + pendingOutcomeFieldQty(draft, locked, f), 0);
};

export const capOutcomeFieldQty = (
  draft: DeliveryPaperStatusQty,
  field: 'accepted' | 'conditioned' | 'rejected',
  nextQty: number,
  locked: DeliveryPaperLockedOutcomeQty = emptyDeliveryPaperStatusQty(),
): number => {
  const minAllowed = locked[field];
  const pendingOther = pendingOnOtherOutcomeFields(draft, locked, field);
  const maxAllowed = locked[field] + Math.max(0, draft.packed - pendingOther);
  return Math.min(Math.max(minAllowed, Math.trunc(nextQty)), maxAllowed);
};

export const outcomeQtyValidationMessage = (
  draft: DeliveryPaperStatusQty,
  locked: DeliveryPaperLockedOutcomeQty = emptyDeliveryPaperStatusQty(),
): string | null => {
  if (!pendingOutcomeQtyExceedsPacked(draft, locked)) return null;
  const pending = pendingOutcomeQtyTotal(draft, locked);
  return `Planned Accepted, Condition, and Rejected (${pending}) cannot exceed remaining Packed (${draft.packed}).`;
};
