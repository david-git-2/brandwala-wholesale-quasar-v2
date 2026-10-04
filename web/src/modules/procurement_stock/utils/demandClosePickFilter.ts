import type { DemandStockPickSelection } from '../components/ProcurementDemandStockPickDialog.vue';
import type { PreorderDemandCloseAction, PreorderDemandStockPick } from '../repositories/procurementDemandRepository';

export function isDemandPickAlreadyClosed(
  pick: Pick<DemandStockPickSelection | PreorderDemandStockPick, 'invoice_id' | 'invoiceId' | 'returned_at' | 'returnedAt'>,
): boolean {
  const invoiceId =
    'invoiceId' in pick && pick.invoiceId != null
      ? pick.invoiceId
      : 'invoice_id' in pick
        ? pick.invoice_id
        : null;
  const returnedAt =
    'returnedAt' in pick && pick.returnedAt
      ? pick.returnedAt
      : 'returned_at' in pick
        ? pick.returned_at
        : null;
  return invoiceId != null || Boolean(returnedAt);
}

export function demandPickCloseAction(
  pick: Pick<DemandStockPickSelection | PreorderDemandStockPick, 'close_action' | 'closeAction'>,
): PreorderDemandCloseAction {
  const raw =
    'closeAction' in pick && pick.closeAction
      ? pick.closeAction
      : 'close_action' in pick && pick.close_action
        ? pick.close_action
        : 'take';
  return raw ?? 'take';
}

export function demandPickMatchesCloseFilter(
  pick: DemandStockPickSelection | PreorderDemandStockPick,
  filter: PreorderDemandCloseAction | null,
): boolean {
  if (!filter) return true;
  if (isDemandPickAlreadyClosed(pick)) return false;
  return demandPickCloseAction(pick) === filter;
}
