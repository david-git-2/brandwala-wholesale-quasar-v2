type PackagedPickRow = {
  quantity: number;
  initialQuantity?: number;
  initial_quantity?: number | null;
  isCloseSplit?: boolean;
  close_split?: boolean | null;
};

const isCloseSplitRow = (pick: PackagedPickRow) =>
  Boolean(pick.isCloseSplit || pick.close_split);

/** Frozen qty from warehouse pick (initial_quantity), not close-split allocation qty. */
export const warehousePackedQtyForRow = (pick: PackagedPickRow): number => {
  if (isCloseSplitRow(pick)) return 0;
  const initial = pick.initialQuantity ?? pick.initial_quantity;
  if (initial != null && initial > 0) return initial;
  return pick.quantity ?? 0;
};

export const sumWarehousePackagedPickQty = (picks: PackagedPickRow[]): number => {
  if (!picks.length) return 0;
  const basePicks = picks.filter((pick) => !isCloseSplitRow(pick));
  const rows = basePicks.length ? basePicks : picks;
  return rows.reduce((sum, pick) => sum + warehousePackedQtyForRow(pick), 0);
};

type CloseLotPick = PackagedPickRow & {
  clientKey: string;
  globalStockId: number;
};

const lotSplitQty = (lot: CloseLotPick[], exceptClientKey?: string): number =>
  lot
    .filter((pick) => isCloseSplitRow(pick) && pick.clientKey !== exceptClientKey)
    .reduce((sum, pick) => sum + Math.max(0, pick.quantity ?? 0), 0);

/** Split qty comes out of the base pick so the lot still matches warehouse qty. */
export function applyCloseSplitQuantityToLot<T extends CloseLotPick>(
  picks: T[],
  clientKey: string,
  nextQty: number,
): T[] {
  const target = picks.find((pick) => pick.clientKey === clientKey);
  if (!target) return picks;
  const lot = picks.filter((pick) => pick.globalStockId === target.globalStockId);
  const base = lot.find((pick) => !isCloseSplitRow(pick));
  const initial = base ? warehousePackedQtyForRow(base) : 0;
  const requested = Number.isFinite(nextQty) ? Math.trunc(nextQty) : 0;

  if (isCloseSplitRow(target)) {
    const otherSplits = lotSplitQty(lot, clientKey);
    const qty = Math.min(Math.max(0, requested), Math.max(0, initial - otherSplits));
    const baseQty = Math.max(0, initial - otherSplits - qty);
    return picks.map((pick) => {
      if (pick.clientKey === clientKey) return { ...pick, quantity: qty };
      if (base && pick.clientKey === base.clientKey) return { ...pick, quantity: baseQty };
      return pick;
    });
  }

  const splits = lotSplitQty(lot);
  const qty = Math.min(Math.max(0, requested), Math.max(0, initial - splits));
  return picks.map((pick) =>
    pick.clientKey === clientKey ? { ...pick, quantity: qty } : pick,
  );
}

export function restoreBaseQtyAfterRemovingSplit<T extends CloseLotPick>(
  picks: T[],
  removed: T,
): T[] {
  if (!isCloseSplitRow(removed)) return picks;
  const lot = picks.filter((pick) => pick.globalStockId === removed.globalStockId);
  const base = lot.find((pick) => !isCloseSplitRow(pick));
  if (!base) return picks;
  const initial = warehousePackedQtyForRow(base);
  const splits = lotSplitQty(lot);
  const baseQty = Math.max(0, initial - splits);
  return picks.map((pick) =>
    pick.clientKey === base.clientKey ? { ...pick, quantity: baseQty } : pick,
  );
}
