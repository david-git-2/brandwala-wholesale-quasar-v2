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
  | 'mark_delivered'
  | 'mark_closed';

/** Map legacy statuses onto the catalog negotiation model. */
export function normalizeCatalogOrderStatus(status: string | null | undefined): string {
  const st = String(status || 'submitted');
  if (st === 'costing_pending') return 'submitted';
  if (st === 'negotiating') return 'priced';
  if (st === 'ordered') return 'dispatch';
  if (st === 'packed') return 'dispatch';
  return st;
}

export function mapStatusToProgressKey(
  status: string | null | undefined,
  isNegotiable: boolean,
): CatalogProgressKey {
  const st = normalizeCatalogOrderStatus(status);
  if (
    st === 'procuring' ||
    st === 'dispatch' ||
    st === 'delivered' ||
    st === 'closed'
  ) {
    return 'fulfillment';
  }
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
  dispatch: 'Dispatch',
  delivered: 'Delivered',
  closed: 'Closed',
  cancelled: 'Cancelled',
};

/** Compact labels for workflow chips and tight order-detail UI. */
const STAFF_STATUS_SHORT_LABELS: Record<string, string> = {
  submitted: 'Costing',
  priced: 'Offer sent',
  countered: 'Countered',
  final_offered: 'Final offer',
  confirmed: 'Confirmed',
  procuring: 'Procuring',
  dispatch: 'Dispatch',
  delivered: 'Delivered',
  closed: 'Closed',
  cancelled: 'Cancelled',
};

const CUSTOMER_STATUS_LABELS: Record<string, string> = {
  submitted: "We're preparing your quote",
  priced: 'Review your offer',
  countered: "We're reviewing your counter",
  final_offered: 'Confirm price & quantity',
  confirmed: 'Order confirmed',
  procuring: "We're sourcing your items",
  dispatch: 'Out for delivery',
  delivered: 'Delivered',
  closed: 'Complete',
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

export function getStaffCatalogStatusShortLabel(status: string | null | undefined): string {
  const st = normalizeCatalogOrderStatus(status);
  return STAFF_STATUS_SHORT_LABELS[st] ?? getStaffCatalogStatusLabel(status);
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
    case 'dispatch':
      return 'mark_delivered';
    case 'delivered':
      return 'mark_closed';
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
    case 'mark_delivered':
      return 'Mark delivered';
    case 'mark_closed':
      return 'Close order';
    default:
      return '';
  }
}

export function getStaffCatalogPrimaryActionTargetStatus(action: StaffCatalogPrimaryAction): string {
  switch (action) {
    case 'send_first_offer':
      return 'priced';
    case 'send_final_offer':
      return 'final_offered';
    case 'start_procurement':
      return 'procuring';
    case 'mark_delivered':
      return 'delivered';
    case 'mark_closed':
      return 'closed';
    default:
      return 'submitted';
  }
}

/** Staff header workflow chips (negotiation + fulfillment), same order as customer sequence. */
export function getCatalogStaffWorkflowStatuses(isNegotiable: boolean): string[] {
  return getCustomerCatalogStatusSequence(isNegotiable);
}

const CATALOG_STAFF_WORKFLOW_CHIP_READ_ONLY = new Set([
  'submitted',
  'priced',
  'countered',
  'final_offered',
  'confirmed',
  'procuring',
]);

/** Through procuring, workflow chips are labels only; dispatch onward (and cancelled) stay clickable. */
export function isCatalogStaffWorkflowStatusChipClickable(statusKey: string): boolean {
  const st = normalizeCatalogOrderStatus(statusKey);
  if (st === 'cancelled') return true;
  return !CATALOG_STAFF_WORKFLOW_CHIP_READ_ONLY.has(st);
}

/** Sticky footer primary action — negotiation steps only; fulfillment uses workflow chips / gear. */
export function showCatalogStaffFooterPrimaryAction(status: string | null | undefined): boolean {
  const st = normalizeCatalogOrderStatus(status);
  if (st === 'cancelled') return false;
  return !isCatalogCustomerFulfillmentPhase(st);
}

export type CatalogWorkflowStatusConfirmation = {
  title: string;
  message: string;
  okLabel: string;
  okColor?: 'primary' | 'negative' | 'warning';
};

function isBackwardCatalogWorkflowStep(
  current: string,
  next: string,
  isNegotiable: boolean,
): boolean {
  const steps = getCatalogStaffWorkflowStatuses(isNegotiable);
  const cur = normalizeCatalogOrderStatus(current);
  const nxt = normalizeCatalogOrderStatus(next);
  const ci = steps.indexOf(cur);
  const ni = steps.indexOf(nxt);
  if (ci < 0 || ni < 0) return false;
  return ni < ci;
}

/** User-facing copy for workflow chip or primary-action status changes. */
export function getCatalogWorkflowStatusConfirmation(
  current: string,
  next: string,
  options?: {
    orderNo?: string | null;
    isNegotiable?: boolean;
    firstOfferConfirmMessage?: string;
  },
): CatalogWorkflowStatusConfirmation {
  const cur = normalizeCatalogOrderStatus(current);
  const nxt = normalizeCatalogOrderStatus(next);
  const isNegotiable = options?.isNegotiable ?? true;
  const orderRef = options?.orderNo ? `Order ${options.orderNo}` : 'This order';
  const targetLabel = getStaffCatalogStatusLabel(nxt);

  if (nxt === 'cancelled') {
    return {
      title: 'Cancel order?',
      message: `${orderRef} will be marked cancelled. The customer will no longer be able to proceed with this order.`,
      okLabel: 'Mark cancelled',
      okColor: 'negative',
    };
  }

  if (isBackwardCatalogWorkflowStep(cur, nxt, isNegotiable)) {
    return {
      title: 'Change order status?',
      message: `${orderRef} will move back to “${targetLabel}”. Use only to fix a mistake. This does not undo stock moves, delivery papers, or bills.`,
      okLabel: `Set to ${targetLabel}`,
      okColor: 'warning',
    };
  }

  switch (nxt) {
    case 'priced':
      return {
        title: 'Send first offer?',
        message:
          options?.firstOfferConfirmMessage ??
          `${orderRef} will move to “Offer sent”. The customer can review prices and quantities.`,
        okLabel: 'Send offer',
      };
    case 'final_offered':
      return {
        title: 'Send final offer?',
        message: `${orderRef} will move to “Final offer sent”. The customer must confirm or counter.`,
        okLabel: 'Send final offer',
      };
    case 'confirmed':
      return {
        title: 'Confirm order?',
        message: `${orderRef} will be marked confirmed and ready for procurement.`,
        okLabel: 'Confirm',
      };
    case 'procuring':
      return {
        title: 'Start procurement?',
        message: `${orderRef} will move to procuring. Demand lines open on the procurement desk for buying and stock picks.`,
        okLabel: 'Start procurement',
      };
    case 'dispatch':
      return {
        title: 'Mark dispatch?',
        message: `${orderRef} will move to dispatch. Create delivery papers from the gear menu when picks are ready.`,
        okLabel: 'Mark dispatch',
      };
    case 'delivered':
      return {
        title: 'Mark delivered?',
        message: `${orderRef} will be marked delivered. Confirm only when fulfillment is complete.`,
        okLabel: 'Mark delivered',
      };
    case 'closed':
      return {
        title: 'Close order?',
        message: `${orderRef} will be closed. Use when billing and delivery are finished.`,
        okLabel: 'Close order',
      };
    default:
      return {
        title: 'Change order status?',
        message: `${orderRef} will move to “${targetLabel}”.`,
        okLabel: 'Confirm',
      };
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
      'dispatch',
      'delivered',
      'closed',
    ];
  }
  return ['submitted', 'priced', 'confirmed', 'procuring', 'dispatch', 'delivered', 'closed'];
}

/** Lock purchase price, rates, and 1st offer once an offer is sent or negotiation advances. */
export function isCatalogFirstOfferLocked(status: string | null | undefined): boolean {
  const st = normalizeCatalogOrderStatus(status);
  return st === 'priced' || st === 'countered' || st === 'final_offered';
}

/** Customer-facing "On the way" step (procuring through closed). */
export function isCatalogCustomerFulfillmentPhase(status: string | null | undefined): boolean {
  const st = normalizeCatalogOrderStatus(status);
  return st === 'procuring' || st === 'dispatch' || st === 'delivered' || st === 'closed';
}

/** Gear drawer Bills tab — same fulfillment window as delivery papers (outcome bills exist before “delivered”). */
export function canShowCatalogOrderBillsTab(status: string | null | undefined): boolean {
  return isCatalogCustomerFulfillmentPhase(status);
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

/** Procured qty is managed on the procurement demand desk, not on the order page. */
export function isCatalogProcuredQtyEditable(status: string | null | undefined): boolean {
  return false;
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
