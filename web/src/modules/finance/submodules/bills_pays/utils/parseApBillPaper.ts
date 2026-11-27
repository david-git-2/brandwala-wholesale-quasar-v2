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
  /** Kernel paid/due in BDT when the bill is settled in foreign currency. */
  paidBdtLabel?: string | null;
  dueBdtLabel?: string | null;
  conversionRate?: number | null;
};

/** BDT per 1 unit of the bill’s foreign currency (from AP paper snapshot). */
export function apBillPaperConversionRate(
  channelMeta: Record<string, unknown> | null | undefined,
): number | null {
  const paper = parseApBillPaper(channelMeta, null);
  if (!paper) return null;

  if ('conversion_rate' in paper) {
    const rate = Number((paper as { conversion_rate?: number }).conversion_rate);
    if (rate > 0 && Math.abs(rate - 1) > 0.0001) return rate;
  }

  if ('lines' in paper) {
    const bucket = paper as ApBillPaperBucketLines;
    if (bucket.conversion_rate != null && bucket.conversion_rate > 0) {
      if (Math.abs(bucket.conversion_rate - 1) > 0.0001) return bucket.conversion_rate;
    }
    const foreign = bucket.foreign_total ?? bucket.currency_groups?.[0]?.foreign_total;
    const bdt = bucket.bdt_amount;
    const code = (bucket.currency_code ?? bucket.currency_groups?.[0]?.currency_code ?? 'BDT').toUpperCase();
    if (
      foreign != null &&
      foreign > 0 &&
      bdt != null &&
      bdt > 0 &&
      code !== 'BDT' &&
      Math.abs(bdt - foreign) > 0.02
    ) {
      return Math.round((bdt / foreign) * 10000) / 10000;
    }
  }

  return null;
}

const formatApCurrencyAmount = (amount: number, currencySymbol?: string, currencyCode?: string) =>
  formatSettlementCurrencyAmount(amount, currencyCode ?? 'BDT', currencySymbol);

export function apBillPaperCurrencyCode(
  channelMeta: Record<string, unknown> | null | undefined,
): string {
  const groups = apBillCurrencyGroups(channelMeta);
  const g = groups[0];
  const fromGroup = (g?.currency_code ?? '').trim().toUpperCase();
  if (fromGroup && fromGroup !== 'BDT') return fromGroup;

  const paper = parseApBillPaper(channelMeta, null);
  if (paper && 'lines' in paper) {
    const bucket = paper as ApBillPaperBucketLines;
    const fromBucket = (bucket.currency_code ?? '').trim().toUpperCase();
    if (fromBucket && fromBucket !== 'BDT') return fromBucket;
    const line = bucket.lines?.[0] ?? g?.lines?.[0];
    const fromLine = (line?.currency_code ?? '').trim().toUpperCase();
    if (fromLine && fromLine !== 'BDT') return fromLine;
  }

  if (g?.foreign_total != null && g.foreign_total > 0 && fromGroup !== 'BDT') {
    return fromGroup || 'BDT';
  }
  return fromGroup || 'BDT';
}

/** Kernel books (BDT) → settlement currency for AP voucher display. */
export function apBooksToSettlementAmount(
  booksAmount: number,
  channelMeta: Record<string, unknown> | null | undefined,
  foreignTotal: number,
  currencyCode: string,
): number {
  const books = Math.max(0, Number(booksAmount) || 0);
  const code = currencyCode.toUpperCase();
  if (code === 'BDT') return books;
  const rate = apBillPaperConversionRate(channelMeta);
  if (rate != null && rate > 0) {
    return Math.round((books / rate) * 100) / 100;
  }
  if (foreignTotal > 0 && books <= foreignTotal + 0.02) {
    return books;
  }
  if (foreignTotal > 0 && books <= 0) {
    return 0;
  }
  return books;
}

const apKernelBooksLookLikeTaka = (
  booksAmount: number,
  foreignTotal: number,
  currencyCode: string,
): boolean => {
  const code = currencyCode.toUpperCase();
  if (code === 'BDT') return false;
  if (foreignTotal <= 0) return false;
  return booksAmount > foreignTotal * 1.5;
};

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
  const paperCode = apBillPaperCurrencyCode(channelMeta);

  if (mixed) {
    return groups.map((g) => ({
      currency_code: g.currency_code,
      totalLabel: formatApCurrencyAmount(g.foreign_total, g.currency_symbol, g.currency_code),
      paidLabel: formatApCurrencyAmount(0, g.currency_symbol, g.currency_code),
      dueLabel: formatApCurrencyAmount(g.foreign_total, g.currency_symbol, g.currency_code),
    }));
  }

  const g = groups[0]!;
  const code = paperCode !== 'BDT' ? paperCode : (g.currency_code || 'BDT').toUpperCase();
  const symbol = g.currency_symbol;
  const foreignTotal = Number(g.foreign_total) || 0;
  const rate = apBillPaperConversionRate(channelMeta);
  const isForeignPaper = code !== 'BDT';

  if (isForeignPaper) {
    const paidForeign = apBooksToSettlementAmount(paid, channelMeta, foreignTotal, code);
    const dueForeign = apBooksToSettlementAmount(due, channelMeta, foreignTotal, code);
    const showBdtSide =
      apKernelBooksLookLikeTaka(paid, foreignTotal, code) ||
      apKernelBooksLookLikeTaka(due, foreignTotal, code);
    return [
      {
        currency_code: code,
        totalLabel: formatApCurrencyAmount(foreignTotal, symbol, code),
        paidLabel: formatApCurrencyAmount(paidForeign, symbol, code),
        dueLabel: formatApCurrencyAmount(dueForeign, symbol, code),
        paidBdtLabel: showBdtSide && paid > 0 ? formatBdtTaka(paid) : null,
        dueBdtLabel: showBdtSide && due > 0 ? formatBdtTaka(due) : null,
        conversionRate: rate,
      },
    ];
  }

  return [
    {
      currency_code: code,
      totalLabel: formatApCurrencyAmount(g.foreign_total, symbol, code),
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
