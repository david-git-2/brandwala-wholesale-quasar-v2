import type { DeliveryPaperDetailItem } from '../repositories/procurementDemandRepository';
import type { DeliveryPaperLineDraft } from '../composables/useDeliveryPaperDetail';
import type { DeliveryPaperStatusQty } from './deliveryPaperStatusQty';
import {
  lockedOutcomeQtyFromPaperPicks,
  pendingOutcomeFieldQty,
} from './deliveryPaperStatusQty';

export type DeliveryPaperOutcomeField = 'accepted' | 'conditioned' | 'rejected';

export type DeliveryPaperOutcomeAllocation = {
  preorder_demand_id: number;
  global_stock_id: number;
  quantity: number;
  grade_tag_id?: number | null;
  /** UI display */
  product_name?: string;
  shipment_name?: string | null;
  line_id?: number;
  unit_sell_price_amount?: number | null;
};

export type DeliveryPaperOutcomeAllocationRow = DeliveryPaperOutcomeAllocation & {
  clientKey: string;
};

const outcomeFieldToCloseAction = (
  field: DeliveryPaperOutcomeField,
): 'take' | 'condition' | 'return' => {
  if (field === 'accepted') return 'take';
  if (field === 'conditioned') return 'condition';
  return 'return';
};

export const deliveryPaperOutcomeCloseAction = outcomeFieldToCloseAction;

export type PackedLotRow = {
  line_id: number;
  global_stock_id: number;
  quantity: number;
  shipment_name: string | null;
};

export const packedLotsFromItem = (item: DeliveryPaperDetailItem): PackedLotRow[] => {
  const rows: PackedLotRow[] = [];
  for (const pick of item.paper_picks ?? []) {
    if ((pick.line_status ?? '').toLowerCase() !== 'packed') continue;
    if (pick.global_stock_id == null) continue;
    const qty = Math.max(0, Math.trunc(Number(pick.quantity ?? 0)));
    if (qty <= 0) continue;
    rows.push({
      line_id: pick.line_id ?? pick.global_stock_id,
      global_stock_id: pick.global_stock_id,
      quantity: qty,
      shipment_name: pick.shipment_name ?? null,
    });
  }
  rows.sort((a, b) => a.line_id - b.line_id || a.global_stock_id - b.global_stock_id);
  return rows;
};

/** FIFO allocate column qty across packed lots (uses saved paper_picks for lot sizes). */
export const buildOutcomeAllocations = (params: {
  items: DeliveryPaperDetailItem[];
  getDraft: (item: DeliveryPaperDetailItem) => DeliveryPaperLineDraft;
  field: DeliveryPaperOutcomeField;
}): DeliveryPaperOutcomeAllocationRow[] => {
  const out: DeliveryPaperOutcomeAllocationRow[] = [];

  for (const item of params.items) {
    if (item.preorder_demand_id == null) continue;
    const locked = lockedOutcomeQtyFromPaperPicks(item);
    let remaining = pendingOutcomeFieldQty(params.getDraft(item), locked, params.field);
    if (remaining <= 0) continue;

    for (const lot of packedLotsFromItem(item)) {
      if (remaining <= 0) break;
      const take = Math.min(remaining, lot.quantity);
      if (take <= 0) continue;
      remaining -= take;
      out.push({
        clientKey: `${item.preorder_demand_id}-${lot.global_stock_id}-${lot.line_id}`,
        preorder_demand_id: item.preorder_demand_id,
        global_stock_id: lot.global_stock_id,
        quantity: take,
        product_name: item.name,
        shipment_name: lot.shipment_name,
        line_id: lot.line_id,
        unit_sell_price_amount: item.unit_sell_price_amount ?? null,
      });
    }
  }

  return out;
};

export const totalAllocationQty = (rows: DeliveryPaperOutcomeAllocation[]): number =>
  rows.reduce((sum, row) => sum + Math.max(0, row.quantity), 0);

export const outcomeFieldLabel = (field: DeliveryPaperOutcomeField): string => {
  if (field === 'accepted') return 'Accepted';
  if (field === 'conditioned') return 'Condition';
  return 'Rejected';
};

/** Header actions on delivery paper detail (apply column qty). */
export const deliveryPaperOutcomeActionButtonLabel = (field: DeliveryPaperOutcomeField): string => {
  if (field === 'accepted') return 'Create draft bill';
  if (field === 'conditioned') return 'Create condition bill';
  return 'Return to warehouse';
};

export const deliveryPaperOutcomeActionCompletedLabel = (field: DeliveryPaperOutcomeField): string => {
  if (field === 'accepted') return 'Draft bill created';
  if (field === 'conditioned') return 'Condition bill created';
  return 'Returned to warehouse';
};

export type DeliveryPaperOutcomeFieldTotals = {
  planned: number;
  locked: number;
  pending: number;
};

export const deliveryPaperOutcomeFieldTotals = (
  items: ReadonlyArray<DeliveryPaperDetailItem>,
  getDraft: (item: DeliveryPaperDetailItem) => DeliveryPaperLineDraft,
  field: DeliveryPaperOutcomeField,
): DeliveryPaperOutcomeFieldTotals => {
  let planned = 0;
  let locked = 0;
  for (const item of items) {
    const draft = getDraft(item);
    const lockedQty = lockedOutcomeQtyFromPaperPicks(item);
    planned += Math.max(0, Math.trunc(draft[field]));
    locked += Math.max(0, Math.trunc(lockedQty[field]));
  }
  const pending = Math.max(0, planned - locked);
  return { planned, locked, pending };
};

/** Show header action when column has planned or already-applied qty. */
export const deliveryPaperOutcomeFieldsForHeaderActions = (
  items: ReadonlyArray<DeliveryPaperDetailItem>,
  getDraft: (item: DeliveryPaperDetailItem) => DeliveryPaperLineDraft,
): DeliveryPaperOutcomeField[] => {
  const fields: DeliveryPaperOutcomeField[] = ['accepted', 'conditioned', 'rejected'];
  return fields.filter((field) => {
    const { planned, locked } = deliveryPaperOutcomeFieldTotals(items, getDraft, field);
    return planned > 0 || locked > 0;
  });
};

export type DeliveryPaperOutcomeActionButtonState = {
  label: string;
  disabled: boolean;
  completed: boolean;
};

export const deliveryPaperOutcomeActionButtonState = (
  items: ReadonlyArray<DeliveryPaperDetailItem>,
  getDraft: (item: DeliveryPaperDetailItem) => DeliveryPaperLineDraft,
  field: DeliveryPaperOutcomeField,
): DeliveryPaperOutcomeActionButtonState => {
  const { planned, locked, pending } = deliveryPaperOutcomeFieldTotals(items, getDraft, field);
  const completed = planned > 0 && pending <= 0 && locked > 0;
  if (completed) {
    return {
      label: `${deliveryPaperOutcomeActionCompletedLabel(field)} · ${locked}`,
      disabled: true,
      completed: true,
    };
  }
  return {
    label: deliveryPaperOutcomeActionButtonLabel(field),
    disabled: pending <= 0,
    completed: false,
  };
};
