/** Catalog vendor order status helpers — see doc/shop_order/CATALOG_NEGOTIATION.md */

export const CATALOG_NEGOTIATION_PROGRESS_KEYS = [
  'submitted',
  'priced',
  'countered',
  'final_offered',
  'confirmed',
  'fulfillment',
] as const;

export type CatalogProgressKey = (typeof CATALOG_NEGOTIATION_PROGRESS_KEYS)[number];

export type StaffCatalogPrimaryAction =
  | 'send_first_offer'
  | 'send_final_offer'
  | 'start_procurement'
  | 'mark_ordered'
  | 'mark_delivered';

/** Map legacy statuses onto the catalog negotiation model. */
export function normalizeCatalogOrderStatus(status: string | null | undefined): string {
  const st = String(status || 'submitted');
  if (st === 'costing_pending') return 'submitted';
  if (st === 'negotiating') return 'priced';
  return st;
}

export function mapStatusToProgressKey(
  status: string | null | undefined,
  isNegotiable: boolean,
): CatalogProgressKey {
  const st = normalizeCatalogOrderStatus(status);
  if (st === 'procuring' || st === 'ordered' || st === 'delivered') return 'fulfillment';
  if (!isNegotiable && st === 'countered') return 'priced';
  if (!isNegotiable && st === 'final_offered') return 'priced';
  if (CATALOG_NEGOTIATION_PROGRESS_KEYS.includes(st as CatalogProgressKey)) {
    return st as CatalogProgressKey;
  }
  if (st === 'cancelled') return 'submitted';
  return 'submitted';
}

const STAFF_STATUS_LABELS: Record<string, string> = {
  submitted: 'Costing / prepare offer',
  priced: 'Offer sent — awaiting customer',
  countered: 'Customer countered — set final offer',
  final_offered: 'Final offer sent — awaiting confirmation',
  confirmed: 'Confirmed — start procurement',
  procuring: 'Procuring',
  ordered: 'Ordered',
  delivered: 'Delivered',
  cancelled: 'Cancelled',
};

const CUSTOMER_STATUS_LABELS: Record<string, string> = {
  submitted: "We're preparing your quote",
  priced: 'Review your offer',
  countered: "We're reviewing your counter",
  final_offered: 'Confirm price & quantity',
  confirmed: 'Order confirmed',
  procuring: "We're sourcing your items",
  ordered: 'Order placed with supplier',
  delivered: 'Delivered',
  cancelled: 'Cancelled',
};

const PROGRESS_STAFF_LABELS: Record<CatalogProgressKey, string> = {
  submitted: 'Processing',
  priced: 'Offer sent',
  countered: 'Counter review',
  final_offered: 'Final offer',
  confirmed: 'Confirmed',
  fulfillment: 'Fulfilling',
};

const PROGRESS_CUSTOMER_LABELS: Record<CatalogProgressKey, string> = {
  submitted: 'Preparing quote',
  priced: 'Review offer',
  countered: 'Under review',
  final_offered: 'Confirm order',
  confirmed: 'Confirmed',
  fulfillment: 'On the way',
};

export function getStaffCatalogStatusLabel(status: string | null | undefined): string {
  const st = normalizeCatalogOrderStatus(status);
  return STAFF_STATUS_LABELS[st] ?? st.replace(/_/g, ' ');
}

export function getCustomerCatalogStatusLabel(status: string | null | undefined): string {
  const st = normalizeCatalogOrderStatus(status);
  return CUSTOMER_STATUS_LABELS[st] ?? st.replace(/_/g, ' ');
}

export function getCatalogProgressStaffLabel(key: CatalogProgressKey): string {
  return PROGRESS_STAFF_LABELS[key];
}

export function getCatalogProgressCustomerLabel(key: CatalogProgressKey): string {
  return PROGRESS_CUSTOMER_LABELS[key];
}

/** Progress steps shown in the workflow bar (negotiable catalog). */
export function getCatalogProgressSteps(isNegotiable: boolean): CatalogProgressKey[] {
  if (isNegotiable) {
    return [...CATALOG_NEGOTIATION_PROGRESS_KEYS];
  }
  return ['submitted', 'priced', 'confirmed', 'fulfillment'];
}

export function getStaffCatalogPrimaryAction(
  status: string | null | undefined,
): StaffCatalogPrimaryAction | null {
  const st = normalizeCatalogOrderStatus(status);
  switch (st) {
    case 'submitted':
      return 'send_first_offer';
    case 'countered':
      return 'send_final_offer';
    case 'confirmed':
      return 'start_procurement';
    case 'procuring':
      return 'mark_ordered';
    case 'ordered':
      return 'mark_delivered';
    default:
      return null;
  }
}

export function getStaffCatalogPrimaryActionLabel(action: StaffCatalogPrimaryAction): string {
  switch (action) {
    case 'send_first_offer':
      return 'Send first offer';
    case 'send_final_offer':
      return 'Send final offer';
    case 'start_procurement':
      return 'Start procurement';
    case 'mark_ordered':
      return 'Mark ordered';
    case 'mark_delivered':
      return 'Mark delivered';
    default:
      return '';
  }
}

export function getCustomerCatalogStatusSequence(isNegotiable: boolean): string[] {
  if (isNegotiable) {
    return ['submitted', 'priced', 'countered', 'final_offered', 'confirmed', 'procuring', 'ordered', 'delivered'];
  }
  return ['submitted', 'priced', 'confirmed', 'procuring', 'ordered', 'delivered'];
}

export function isCatalogProgressStepComplete(
  stepKey: CatalogProgressKey,
  currentProgressKey: CatalogProgressKey,
): boolean {
  const steps = CATALOG_NEGOTIATION_PROGRESS_KEYS;
  return steps.indexOf(stepKey) < steps.indexOf(currentProgressKey);
}

export function isCatalogProgressStepCurrent(
  stepKey: CatalogProgressKey,
  currentProgressKey: CatalogProgressKey,
): boolean {
  return stepKey === currentProgressKey;
}
