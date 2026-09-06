import type { StockAvailability } from 'src/modules/procurement_stock/constants/stockAvailability';
import type { DropshipManagementReturnLine, DropshipReturnItemPayload } from '../types/dropshipManagementOrder';

export type ReturnCondition = 'perfect' | 'open_box' | 'damaged';

type ReturnableLine = Pick<DropshipManagementReturnLine, 'quantity' | 'confirmed_quantity' | 'returned_quantity'>;

export function returnableQty(line: ReturnableLine): number {
  const delivered = Number(line.confirmed_quantity ?? line.quantity ?? 0);
  const returned = Number(line.returned_quantity ?? 0);
  return Math.max(0, delivered - returned);
}

export function totalReturnableQty(lines: ReturnableLine[]): number {
  return lines.reduce((sum, line) => sum + returnableQty(line), 0);
}

export interface ReturnRowInput {
  order_item_id: number;
  selected: boolean;
  quantity: number;
  grade_tag_id: number | null;
  to_availability: StockAvailability;
  note: string;
}

export function buildReturnItemsFromRows(rows: ReturnRowInput[]): DropshipReturnItemPayload[] {
  const items: DropshipReturnItemPayload[] = [];
  for (const row of rows) {
    if (!row.selected || row.quantity <= 0) continue;
    if (row.grade_tag_id == null) {
      throw new Error('Each returned line needs a grade.');
    }
    items.push({
      order_item_id: row.order_item_id,
      returned_qty: row.quantity,
      grade_tag_id: row.grade_tag_id,
      to_availability: row.to_availability,
    });
  }
  if (items.length === 0) {
    throw new Error('Select at least one line with return quantity greater than zero.');
  }
  return items;
}

export function mapConditionQtysToItems(
  items: Array<{ id: number; quantity?: number; confirmed_quantity?: number | null; returned_quantity?: number }>,
  qtyNormal: number,
  qtyOpenBox: number,
  qtyDamaged: number,
): Array<{ order_item_id: number; returned_qty: number; condition: ReturnCondition }> {
  const totalReturnable = items.reduce((sum, item) => sum + returnableQty({
    quantity: item.quantity ?? 0,
    confirmed_quantity: item.confirmed_quantity,
    returned_quantity: item.returned_quantity,
  }), 0);
  const requested = qtyNormal + qtyOpenBox + qtyDamaged;
  if (requested <= 0) {
    throw new Error('Return quantity must be greater than zero');
  }
  if (requested !== totalReturnable) {
    throw new Error(`Return quantities (${requested}) must equal returnable total (${totalReturnable})`);
  }

  const remaining: Record<ReturnCondition, number> = {
    perfect: qtyNormal,
    open_box: qtyOpenBox,
    damaged: qtyDamaged,
  };
  const result: Array<{ order_item_id: number; returned_qty: number; condition: ReturnCondition }> = [];

  for (const item of items) {
    let need = returnableQty({
      quantity: item.quantity ?? 0,
      confirmed_quantity: item.confirmed_quantity,
      returned_quantity: item.returned_quantity,
    });
    for (const condition of ['perfect', 'open_box', 'damaged'] as const) {
      if (need <= 0) break;
      const take = Math.min(need, remaining[condition]);
      if (take > 0) {
        result.push({
          order_item_id: item.id,
          returned_qty: take,
          condition,
        });
        remaining[condition] -= take;
        need -= take;
      }
    }
  }

  return result;
}
