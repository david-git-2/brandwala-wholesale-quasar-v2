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
  | 'mark_ready_for_shipment'
  | 'mark_delivered';

/** Map legacy statuses onto the catalog negotiation model. */
export function normalizeCatalogOrderStatus(status: string | null | undefined): string {
  const st = String(status || 'submitted');
  if (st === 'costing_pending') return 'submitted';
  if (st === 'negotiating') return 'priced';
  if (st === 'ordered') return 'ready_for_shipment';
  return st;
}

export function mapStatusToProgressKey(
  status: string | null | undefined,
  isNegotiable: boolean,
): CatalogProgressKey {
  const st = normalizeCatalogOrderStatus(status);
  if (st === 'procuring' || st === 'ready_for_shipment' || st === 'delivered') return 'fulfillment';
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
  ready_for_shipment: 'Ready for shipment',
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
  ready_for_shipment: 'Ready to ship',
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
      return 'mark_ready_for_shipment';
    case 'ready_for_shipment':
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
    case 'mark_ready_for_shipment':
      return 'Mark ready for shipment';
    case 'mark_delivered':
      return 'Mark delivered';
    default:
      return '';
  }
}

export function getCustomerCatalogStatusSequence(isNegotiable: boolean): string[] {
  if (isNegotiable) {
    return [
      'submitted',
      'priced',
      'countered',
      'final_offered',
      'confirmed',
      'procuring',
      'ready_for_shipment',
      'delivered',
    ];
  }
  return ['submitted', 'priced', 'confirmed', 'procuring', 'ready_for_shipment', 'delivered'];
}

/** Lock purchase price, rates, and 1st offer once an offer is sent or negotiation advances. */
export function isCatalogFirstOfferLocked(status: string | null | undefined): boolean {
  const st = normalizeCatalogOrderStatus(status);
  return st === 'priced' || st === 'countered' || st === 'final_offered';
}

/** Customer-facing "On the way" step (procuring through delivered). */
export function isCatalogCustomerFulfillmentPhase(status: string | null | undefined): boolean {
  const st = normalizeCatalogOrderStatus(status);
  return st === 'procuring' || st === 'ready_for_shipment' || st === 'delivered';
}

/** Effective qty shown to the customer after confirm (0 = line rejected). */
export function getCustomerCatalogItemDisplayQuantity(item: {
  quantity?: number | null;
  confirmed_quantity?: number | null;
}): number {
  const qty = item.confirmed_quantity ?? item.quantity ?? 0;
  return Math.max(0, Number(qty) || 0);
}

/** Human-readable label for per-line negotiation / decision status in admin tables. */
export function getCatalogItemNegotiationStatusLabel(status: string | null | undefined): string {
  const st = String(status || 'pending').toLowerCase();
  const labels: Record<string, string> = {
    pending: 'Pending',
    submitted: 'Submitted',
    priced: 'Priced',
    countered: 'Countered',
    final_offered: 'Final offer',
    confirmed: 'Confirmed',
    accepted: 'Accepted',
    rejected: 'Rejected',
  };
  return labels[st] ?? st.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
}

/** Staff cannot edit lines or rates while the customer reviews a sent offer. */
export function isCatalogStaffReadOnly(status: string | null | undefined): boolean {
  const st = normalizeCatalogOrderStatus(status);
  return st === 'priced' || st === 'final_offered';
}

/** Staff may edit final-offer prices only after the customer counters. */
export function isCatalogFinalOfferEditable(status: string | null | undefined): boolean {
  return normalizeCatalogOrderStatus(status) === 'countered';
}

/** Procured qty is entered when marking ready for shipment (not stored on the line). */
export function isCatalogProcuredQtyEditable(status: string | null | undefined): boolean {
  const st = normalizeCatalogOrderStatus(status);
  return st === 'confirmed' || st === 'procuring';
}

/** @deprecated use isCatalogProcuredQtyEditable */
export const isCatalogOrderedQtyEditable = isCatalogProcuredQtyEditable;

export function isCatalogDeliveredQtyEditable(_status: string | null | undefined): boolean {
  return false;
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

export function getCatalogProgressStepIndex(
  currentProgressKey: CatalogProgressKey,
  isNegotiable: boolean,
): { current: number; total: number } {
  const steps = getCatalogProgressSteps(isNegotiable);
  const idx = Math.max(0, steps.indexOf(currentProgressKey));
  return { current: idx + 1, total: steps.length };
}

/** Customer has accepted or countered this line during priced negotiation. */
export function isCustomerCatalogItemDecided(item: {
  customer_offer_amount?: number | null;
}): boolean {
  return item.customer_offer_amount != null && Number(item.customer_offer_amount) > 0;
}
