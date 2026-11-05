import type { DeliveryPaperStatus } from '../repositories/procurementDemandRepository';

export const DELIVERY_PAPER_STATUS_OPTIONS: Array<{
  label: string;
  value: DeliveryPaperStatus;
}> = [
  { label: 'Draft', value: 'draft' },
  { label: 'Packed', value: 'packed' },
  { label: 'Dispatched', value: 'dispatched' },
  { label: 'Delivered', value: 'delivered' },
  { label: 'Cancelled', value: 'cancelled' },
];

/** Status dropdown options; draft is only available while the paper is still draft. */
export function deliveryPaperStatusOptionsForSelect(
  current: DeliveryPaperStatus | null | undefined,
): typeof DELIVERY_PAPER_STATUS_OPTIONS {
  if (!current || current === 'draft') {
    return DELIVERY_PAPER_STATUS_OPTIONS;
  }
  return DELIVERY_PAPER_STATUS_OPTIONS.filter((opt) => opt.value !== 'draft');
}
