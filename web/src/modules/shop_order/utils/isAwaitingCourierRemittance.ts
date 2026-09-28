import type { FinanceHubOrderQueueItem } from '../repositories/dropshipFinanceRepository';
import { isDropshipRecipientCodRemittancePending } from './dropshipRecipientCodRemittance';

/** Delivered recipient-COD dropship orders still needing courier bank-in on Payments desk. */
export function isAwaitingCourierRemittance(order: FinanceHubOrderQueueItem): boolean {
  if (!isDropshipRecipientCodRemittancePending(order)) return false;
  if (order.status === 'delivered') return true;
  return order.nextStep === 'courier_remittance';
}
