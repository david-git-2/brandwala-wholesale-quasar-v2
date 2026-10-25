import type {
  ActiveStockPick,
  ListStockForOrderItemPickMeta,
  OrderItemPickStockRow,
} from '../repositories/shopOrderRepository';

export function sumDraftPickQty(draftPicks: ActiveStockPick[]): number {
  return draftPicks.reduce((sum, pick) => sum + pick.quantity, 0);
}

export function draftQtyForStock(draftPicks: ActiveStockPick[], globalStockId: number): number {
  return draftPicks
    .filter((pick) => pick.global_stock_id === globalStockId)
    .reduce((sum, pick) => sum + pick.quantity, 0);
}

/** Merge server pick-list rows with in-memory draft picks (no extra API). */
export function overlayPickListWithDraft(
  server: { data: OrderItemPickStockRow[]; meta: ListStockForOrderItemPickMeta },
  draftPicks: ActiveStockPick[],
  orderedQty: number,
): { data: OrderItemPickStockRow[]; meta: ListStockForOrderItemPickMeta } {
  const pickedTotal = sumDraftPickQty(draftPicks);
  const remaining = Math.max(0, orderedQty - pickedTotal);

  const data = server.data.map((row) => {
    const serverPicked = row.already_picked ?? 0;
    const draftPicked = draftQtyForStock(draftPicks, row.global_stock_id);
    const extraHeld = Math.max(0, draftPicked - serverPicked);
    return {
      ...row,
      already_picked: draftPicked,
      available_atp: Math.max(0, row.available_atp - extraHeld),
      pick_id: draftPicks.find((p) => p.global_stock_id === row.global_stock_id)?.id ?? row.pick_id,
    };
  });

  const meta: ListStockForOrderItemPickMeta = {
    ...server.meta,
    active_picks: draftPicks,
    already_picked_total: pickedTotal,
    ordered_quantity: orderedQty,
    remaining_to_pick: remaining,
  };

  return { data, meta };
}
