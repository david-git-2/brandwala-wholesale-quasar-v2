import type { Database } from 'src/types/database.types';

export type StockAvailability = Database['public']['Enums']['stock_availability'];

export const STOCK_AVAILABILITY_OPTIONS: Array<{ label: string; value: StockAvailability }> = [
  { label: 'Sellable', value: 'sellable' },
  { label: 'Held', value: 'held' },
  { label: 'Unsellable', value: 'unsellable' },
];

export const formatStockAvailability = (value: string | null | undefined): string => {
  if (!value) return '—';
  const opt = STOCK_AVAILABILITY_OPTIONS.find((o) => o.value === value);
  return opt?.label ?? value.replace(/_/g, ' ');
};

export const availabilityChipColor = (
  value: string | null | undefined,
): { color: string; textColor: string } => {
  switch (value) {
    case 'sellable':
      return { color: 'green-1', textColor: 'green-9' };
    case 'held':
      return { color: 'orange-1', textColor: 'orange-10' };
    case 'unsellable':
      return { color: 'red-1', textColor: 'red-9' };
    default:
      return { color: 'grey-2', textColor: 'grey-8' };
  }
};
