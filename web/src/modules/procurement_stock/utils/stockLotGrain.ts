import type { GlobalStock } from '../repositories/globalStockRepository';

/** Same sellable lot grain across bins (outcome + availability + grade). */
export function stockLotGrainKey(row: GlobalStock): string {
  const outcomePart =
    row.outcome_id != null ? `o:${row.outcome_id}` : `si:${row.shipment_item_id}`;
  return [outcomePart, row.availability ?? '', row.grade_tag_id ?? ''].join('|');
}

export function isSameStockLotGrain(a: GlobalStock, b: GlobalStock): boolean {
  return stockLotGrainKey(a) === stockLotGrainKey(b);
}

/** All loaded rows for this lot grain (may include multiple bins). */
export function findStockLotsInOtherBins(
  allRows: GlobalStock[],
  row: GlobalStock,
): GlobalStock[] {
  const key = stockLotGrainKey(row);
  return allRows
    .filter((r) => stockLotGrainKey(r) === key && (r.quantity ?? 0) > 0)
    .sort((a, b) => {
      if (a.location_id === row.location_id) return -1;
      if (b.location_id === row.location_id) return 1;
      return (a.location_name ?? '').localeCompare(b.location_name ?? '');
    });
}
