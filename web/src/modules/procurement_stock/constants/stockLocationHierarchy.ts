import type { StockLocationKind } from '../types/stockLocation';

/** Next kind when adding a child under `parentKind`. */
export const STOCK_LOCATION_CHILD_KIND: Partial<
  Record<StockLocationKind, StockLocationKind>
> = {
  warehouse: 'zone',
  returns: 'zone',
  zone: 'shelf',
  shelf: 'level',
  level: 'bin',
};

/** Allowed parent kinds for a given child kind. */
export const STOCK_LOCATION_PARENT_KINDS: Record<StockLocationKind, StockLocationKind[]> = {
  warehouse: [],
  returns: [],
  zone: ['warehouse', 'returns'],
  shelf: ['zone'],
  level: ['shelf'],
  bin: ['level'],
};

export const STOCK_LOCATION_KIND_LABELS: Record<StockLocationKind, string> = {
  warehouse: 'Warehouse',
  zone: 'Zone',
  shelf: 'Shelf',
  level: 'Level',
  bin: 'Bin',
  returns: 'Returns',
};

export const isRootStockLocationKind = (kind: StockLocationKind): boolean =>
  kind === 'warehouse' || kind === 'returns';

/** Order for type dropdowns and hierarchy UI (warehouse + returns are roots). */
export const STOCK_LOCATION_KIND_ORDER: StockLocationKind[] = [
  'warehouse',
  'returns',
  'zone',
  'shelf',
  'level',
  'bin',
];

/** Cascade pick order after site root (warehouse or returns). */
export const STOCK_LOCATION_PICK_CHAIN: StockLocationKind[] = [
  'zone',
  'shelf',
  'level',
  'bin',
];

export const STOCK_LOCATION_KIND_HINTS: Record<StockLocationKind, string> = {
  warehouse: 'Top-level site. Add zones under it.',
  returns: 'Returns area root. Usually not pickable for shop sales.',
  zone: 'Aisle or zone under a warehouse or returns root.',
  shelf: 'Shelf row under a zone.',
  level: 'Shelf level under a shelf.',
  bin: 'Leaf bin — stock is stored here.',
};
