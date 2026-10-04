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
