/** Shipment land-split labels (receive). Not warehouse condition / sell status. */

export const OUTCOME_KIND_OPTIONS: Array<{ label: string; value: 'sellable' | 'unsellable' }> = [
  { label: 'Goes to stock', value: 'sellable' },
  { label: 'Loss at receive', value: 'unsellable' },
];

export const OUTCOME_REASON_PICKER_OPTIONS: Array<{ label: string; value: string }> = [
  { label: 'Normal', value: 'general' },
  { label: 'Missing', value: 'missing' },
  { label: 'Damaged', value: 'damaged' },
  { label: 'Other', value: 'other' },
];

const OUTCOME_REASON_LABELS: Record<string, string> = {
  general: 'Normal',
  vendor_discount: 'Vendor discount',
  missing: 'Missing',
  damaged: 'Damaged',
  other: 'Other',
  ordered: 'Ordered',
};

export const formatOutcomeReason = (value: string | null | undefined): string => {
  if (!value) return '—';
  return OUTCOME_REASON_LABELS[value] ?? value.replace(/_/g, ' ');
};

export const formatOutcomeKind = (value: string | null | undefined): string => {
  if (!value) return '—';
  const opt = OUTCOME_KIND_OPTIONS.find((o) => o.value === value);
  return opt?.label ?? value.replace(/_/g, ' ');
};
