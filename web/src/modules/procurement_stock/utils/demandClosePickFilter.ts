import type { DemandStockPickSelection } from '../components/ProcurementDemandStockPickDialog.vue';
import type {
  PreorderDemandCloseAction,
  PreorderDemandStockPick,
  ProcurementDemandGroup,
} from '../repositories/procurementDemandRepository';

type DraftStockPicks = {
  stockPicks?: Array<DemandStockPickSelection | PreorderDemandStockPick>;
};

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

/** Bill id for a close action (take uses document invoice_id; condition from picks). */
export function resolveInvoiceIdForCloseAction(
  group: ProcurementDemandGroup,
  action: PreorderDemandCloseAction,
  drafts: Record<string, DraftStockPicks>,
  groupKeyPrefix: string,
): number | null {
  if (action === 'return') return null;

  const invoiceIds = new Set<number>();
  if (action === 'take' && group.invoice_id) {
    invoiceIds.add(group.invoice_id);
  }

  for (const [key, draft] of Object.entries(drafts)) {
    if (!key.startsWith(groupKeyPrefix)) continue;
    for (const pick of draft.stockPicks ?? []) {
      const inv =
        'invoiceId' in pick && pick.invoiceId != null
          ? pick.invoiceId
          : 'invoice_id' in pick && pick.invoice_id != null
            ? pick.invoice_id
            : null;
      if (inv == null) continue;
      if (demandPickCloseAction(pick) === action) invoiceIds.add(Number(inv));
    }
  }

  if (invoiceIds.size === 0) return null;
  return [...invoiceIds][0] ?? null;
}

/** Open (not invoiced / returned) unit counts per close action for one delivery paper. */
export function sumOpenClosePickQuantitiesByAction(
  drafts: Record<string, DraftStockPicks>,
  groupKeyPrefix: string,
): Record<PreorderDemandCloseAction, number> {
  const totals: Record<PreorderDemandCloseAction, number> = {
    take: 0,
    condition: 0,
    return: 0,
  };

  for (const [key, draft] of Object.entries(drafts)) {
    if (!key.startsWith(groupKeyPrefix)) continue;
    for (const pick of draft.stockPicks ?? []) {
      if (isDemandPickAlreadyClosed(pick)) continue;
      const qty = Number('quantity' in pick ? pick.quantity : 0);
      if (!Number.isFinite(qty) || qty <= 0) continue;
      totals[demandPickCloseAction(pick)] += qty;
    }
  }

  return totals;
}
