import type { BatchCodeItem } from '../repositories/batchCodeRepository';
import {
  BATCH_EXPIRE_WARN_DAYS,
  daysUntilExpire,
  formatExpiresIn,
  toDisplayDate,
} from './batchCodeExpiry';

export const normalizeBatchMatchKey = (value: string | null | undefined): string =>
  (value ?? '').trim().replace(/^['`]+/, '').replace(/\s+/g, '').toLowerCase();

export type ShipmentLineCodes = {
  barcode?: string | null;
  product_code?: string | null;
};

export type BatchCodeLineSummary = {
  /** Short cell label (count). */
  compactLabel: string;
  summaryLabel: string;
  subLabel: string | null;
  lineCount: number;
  toneClass: string;
};

export type BatchCodeMatchTableRow = {
  itemId: number;
  batchId: string;
  expireDate: string;
  expiresIn: string;
  isArrived: boolean;
  toneClass: string;
};

const TONE_UNSET = 'batch-code-tone--unset';
const TONE_OK = 'batch-code-tone--ok';
const TONE_WARN = 'batch-code-tone--warn';

export const batchExpiryTextClassFromDays = (days: number | null): string => {
  if (days === null) return TONE_UNSET;
  if (days < BATCH_EXPIRE_WARN_DAYS) return TONE_WARN;
  return TONE_OK;
};

export const matchBatchItemsForShipmentLine = (
  line: ShipmentLineCodes,
  batchItems: BatchCodeItem[],
): BatchCodeItem[] => {
  const bar = normalizeBatchMatchKey(line.barcode);
  const code = normalizeBatchMatchKey(line.product_code);
  if (!bar && !code) return [];

  return batchItems.filter((row) => {
    const rowBar = normalizeBatchMatchKey(row.barcode);
    const rowCode = normalizeBatchMatchKey(row.product_code);
    if (bar && rowBar && bar === rowBar) return true;
    if (code && rowCode && code === rowCode) return true;
    return false;
  });
};

const minDaysUntilExpire = (matches: BatchCodeItem[]): number | null => {
  let min: number | null = null;
  for (const row of matches) {
    const days = daysUntilExpire(row.expire_date);
    if (days === null) continue;
    if (min === null || days < min) min = days;
  }
  return min;
};

export const batchMatchTableRows = (matches: BatchCodeItem[]): BatchCodeMatchTableRow[] => {
  const sorted = [...matches].sort((a, b) => {
    const daysA = daysUntilExpire(a.expire_date);
    const daysB = daysUntilExpire(b.expire_date);
    if (daysA === null && daysB === null) return 0;
    if (daysA === null) return 1;
    if (daysB === null) return -1;
    return daysA - daysB;
  });

  return sorted.map((row) => {
    const days = daysUntilExpire(row.expire_date);
    return {
      itemId: row.id,
      batchId: row.batch_id?.trim() || '—',
      expireDate: row.expire_date ? toDisplayDate(row.expire_date) : '—',
      expiresIn: formatExpiresIn(row.expire_date),
      isArrived: row.is_arrived,
      toneClass: batchExpiryTextClassFromDays(days),
    };
  });
};

export const summarizeBatchMatches = (matches: BatchCodeItem[]): BatchCodeLineSummary => {
  if (matches.length === 0) {
    return {
      compactLabel: '—',
      summaryLabel: '—',
      subLabel: null,
      lineCount: 0,
      toneClass: 'text-grey-5',
    };
  }

  const batchIds = [
    ...new Set(
      matches
        .map((row) => row.batch_id?.trim())
        .filter((value): value is string => Boolean(value)),
    ),
  ];

  const summaryLabel =
    batchIds.length > 0 ? batchIds.join(' · ') : `${matches.length} line${matches.length === 1 ? '' : 's'}`;

  const compactLabel = String(matches.length);

  const minDays = minDaysUntilExpire(matches);
  const subLabel =
    minDays !== null
      ? formatExpiresIn(
          matches.find((row) => daysUntilExpire(row.expire_date) === minDays)?.expire_date ?? null,
        )
      : null;

  return {
    compactLabel,
    summaryLabel,
    subLabel,
    lineCount: matches.length,
    toneClass: batchExpiryTextClassFromDays(minDays),
  };
};

export const buildBatchSummaryMapForLines = (
  lines: Array<ShipmentLineCodes & { id: number }>,
  batchItems: BatchCodeItem[],
): Map<number, BatchCodeLineSummary> => {
  const map = new Map<number, BatchCodeLineSummary>();
  for (const line of lines) {
    const matches = matchBatchItemsForShipmentLine(line, batchItems);
    map.set(line.id, summarizeBatchMatches(matches));
  }
  return map;
};
