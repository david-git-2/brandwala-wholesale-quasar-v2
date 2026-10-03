export type WarehouseStockGroupBy =
  | 'shipment'
  | 'product'
  | 'location'
  | 'grade'
  | 'availability';

export const WAREHOUSE_STOCK_GROUP_BY_OPTIONS: {
  label: string;
  value: WarehouseStockGroupBy | null;
}[] = [
  { label: 'None', value: null },
  { label: 'Shipment', value: 'shipment' },
  { label: 'Product', value: 'product' },
  { label: 'Bin', value: 'location' },
  { label: 'Condition', value: 'grade' },
  { label: 'Sell status', value: 'availability' },
];

export const WAREHOUSE_AVAILABILITY_QUICK_FILTERS: {
  label: string;
  value: 'all' | 'sellable' | 'held' | 'unsellable';
}[] = [
  { label: 'All', value: 'all' },
  { label: 'Sellable', value: 'sellable' },
  { label: 'Held', value: 'held' },
  { label: 'Unsellable', value: 'unsellable' },
];
