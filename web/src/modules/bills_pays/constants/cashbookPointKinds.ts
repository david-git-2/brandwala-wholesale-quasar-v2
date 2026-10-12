import type { Database } from 'src/types/database.types';

export type CashbookPointKind = Database['public']['Enums']['cashbook_point_kind'];

export const CASHBOOK_POINT_KIND_OPTIONS: { label: string; value: CashbookPointKind }[] = [
  { label: 'Drawer', value: 'drawer' },
  { label: 'Safe', value: 'safe' },
  { label: 'Bank counter', value: 'bank_counter' },
  { label: 'Mobile', value: 'mobile' },
  { label: 'Other', value: 'other' },
];

export const cashbookPointKindLabel = (kind: CashbookPointKind): string =>
  CASHBOOK_POINT_KIND_OPTIONS.find((o) => o.value === kind)?.label ?? kind;
