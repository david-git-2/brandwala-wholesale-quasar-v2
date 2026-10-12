import { formatBdtTaka, formatSettlementCurrencyAmount } from 'src/utils/currency';
import { shipmentApKindLabel } from 'src/modules/procurement_stock/constants/shipmentApBuckets';
import type {
  ApBillPaperBucketLines,
  ApBillPaperCurrencyGroup,
  ApBillPaperSnapshot,
} from '../types/apBillPaper';

export function parseApBillPaper(
  channelMeta: Record<string, unknown> | null | undefined,
  apKind: string | null | undefined,
): ApBillPaperSnapshot | null {
  const raw = channelMeta?.ap_paper;
  if (raw && typeof raw === 'object' && raw !== null && 'paper' in raw) {
    return raw as ApBillPaperSnapshot;
  }
  return null;
}

export type ApBillCurrencyBalanceRow = {
  currency_code: string;
  totalLabel: string;
  paidLabel: string;
  dueLabel: string;
};

const formatApCurrencyAmount = (amount: number, currencySymbol?: string, currencyCode?: string) =>
  formatSettlementCurrencyAmount(amount, currencyCode ?? 'BDT', currencySymbol);

export function apBillCurrencyBalances(
  channelMeta: Record<string, unknown> | null | undefined,
  paidAmount: number | null | undefined,
  dueAmount: number | null | undefined,
): ApBillCurrencyBalanceRow[] | null {
  const groups = apBillCurrencyGroups(channelMeta);
  if (!groups.length) return null;

  const paid = Math.max(0, Number(paidAmount ?? 0));
  const due = Math.max(0, Number(dueAmount ?? 0));
  const mixed = groups.length > 1;

  if (mixed) {
    return groups.map((g) => ({
      currency_code: g.currency_code,
      totalLabel: formatApCurrencyAmount(g.foreign_total, g.currency_symbol, g.currency_code),
      paidLabel: formatApCurrencyAmount(0, g.currency_symbol, g.currency_code),
      dueLabel: formatApCurrencyAmount(g.foreign_total, g.currency_symbol, g.currency_code),
    }));
  }

  const g = groups[0]!;
  return [
    {
      currency_code: g.currency_code,
      totalLabel: formatApCurrencyAmount(g.foreign_total, g.currency_symbol, g.currency_code),
      paidLabel: formatBdtTaka(paid),
      dueLabel: formatBdtTaka(due),
    },
  ];
}

export function apBillCurrencyGroups(
  channelMeta: Record<string, unknown> | null | undefined,
): ApBillPaperCurrencyGroup[] {
  const paper = parseApBillPaper(channelMeta, null);
  if (!paper || !('lines' in paper)) return [];

  const bucket = paper as ApBillPaperBucketLines;
  if (bucket.currency_groups?.length) {
    return bucket.currency_groups;
  }
  if (!bucket.lines?.length) return [];

  return [
    {
      currency_code: bucket.currency_code ?? '',
      currency_symbol: bucket.currency_symbol,
      foreign_total: bucket.foreign_total ?? bucket.bdt_amount ?? 0,
      lines: bucket.lines,
    },
  ];
}

/** Pre–per-component snapshots (summed foreign total + conversion rate, no lines). */
export function isLegacyApPaperSnapshot(
  channelMeta: Record<string, unknown> | null | undefined,
): boolean {
  const raw = channelMeta?.ap_paper;
  if (!raw || typeof raw !== 'object') {
    return true;
  }
  const paper = raw as Record<string, unknown>;
  const lines = paper.lines;
  if (Array.isArray(lines) && lines.length > 0) {
    const groups = paper.currency_groups;
    if (Array.isArray(groups) && groups.length > 0) {
      return false;
    }
    return !Array.isArray(groups);
  }
  return 'foreign_amount' in paper || !('lines' in paper);
}

export function apKindTitle(apKind: string | null | undefined): string {
  return shipmentApKindLabel(apKind);
}
