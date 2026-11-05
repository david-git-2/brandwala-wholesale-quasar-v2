import type {
  DeliveryPaperDetailItem,
  DeliveryPaperStatus,
} from '../repositories/procurementDemandRepository';
import type { DeliveryPaperLineDraftState } from './deliveryPaperStatusQty';

export type DeliveryPaperOutcomeQtyField = 'accepted' | 'conditioned' | 'rejected';

/** Outcome header actions (Accept / Condition / Reject) only when column total > 0. */
export const deliveryPaperOutcomeFieldsWithNonZeroQty = (
  items: ReadonlyArray<DeliveryPaperDetailItem>,
  getDraft: (
    item: DeliveryPaperDetailItem,
  ) => Pick<DeliveryPaperLineDraftState, 'accepted' | 'conditioned' | 'rejected'>,
): DeliveryPaperOutcomeQtyField[] => {
  let accepted = 0;
  let conditioned = 0;
  let rejected = 0;
  for (const item of items) {
    const draft = getDraft(item);
    accepted += Math.max(0, Math.trunc(draft.accepted));
    conditioned += Math.max(0, Math.trunc(draft.conditioned));
    rejected += Math.max(0, Math.trunc(draft.rejected));
  }
  const fields: DeliveryPaperOutcomeQtyField[] = [];
  if (accepted > 0) fields.push('accepted');
  if (conditioned > 0) fields.push('conditioned');
  if (rejected > 0) fields.push('rejected');
  return fields;
};

/** Outcome qty columns on the lines table (hidden on draft/packed). */
export const deliveryPaperVisibleOutcomeFields = (
  status: DeliveryPaperStatus | null | undefined,
): DeliveryPaperOutcomeQtyField[] => {
  if (status === 'draft' || status === 'packed') {
    return [];
  }
  return ['accepted', 'conditioned', 'rejected'];
};

export const deliveryPaperCanPickStock = (status: DeliveryPaperStatus | null | undefined): boolean =>
  status === 'draft';

export const deliveryPaperCanEditOutcomeQty = (
  status: DeliveryPaperStatus | null | undefined,
): boolean => status === 'packed' || status === 'dispatched';

/** Accept / Condition / Reject — only after status is Delivered (not on Packed/Dispatched). */
export const deliveryPaperCanApplyOutcome = (
  status: DeliveryPaperStatus | null | undefined,
): boolean => status === 'delivered';

export const deliveryPaperIsReadOnly = (status: DeliveryPaperStatus | null | undefined): boolean =>
  status === 'delivered' || status === 'cancelled';

export const deliveryPaperCanSaveLines = (status: DeliveryPaperStatus | null | undefined): boolean =>
  deliveryPaperCanPickStock(status) || deliveryPaperCanEditOutcomeQty(status);

export const deliveryPaperCanDelete = (status: DeliveryPaperStatus | null | undefined): boolean =>
  status === 'draft';

/** Header status dropdown; lines/outcomes stay read-only on delivered. */
export const deliveryPaperCanChangeStatus = (
  status: DeliveryPaperStatus | null | undefined,
): boolean => status != null && status !== 'cancelled';

/** From packed onward, list only lines that have packed qty on the paper. */
export const deliveryPaperHidesUnpickedLines = (
  status: DeliveryPaperStatus | null | undefined,
): boolean => status != null && status !== 'draft';
