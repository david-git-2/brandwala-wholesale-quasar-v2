import { shipmentApKindLabel, SHIPMENT_AP_COST_BUCKETS } from '../constants/shipmentApBuckets';
import type {
  ShipmentApBillRow,
  ShipmentApBucketPaidTotals,
  ShipmentApFxSnapshot,
  ShipmentApKind,
} from '../repositories/shipmentApBillsRepository';
import {
  shipmentApBillBucket,
  shipmentApBillPlugCurrency,
} from '../repositories/shipmentApBillsRepository';
import {
  apBillInvoiceLabel,
  apBillStatusChip,
  displayBillTotal,
  type ApBillStatusChip,
} from './shipmentApBillDisplay';

const round2 = (n: number) => Math.round(n * 100) / 100;

export type SummaryApBillTableRow = {
  id: number;
  invoiceLabel: string;
  originCode: string;
  originAmount: number;
  bdtAmount: number;
  statusChip: ApBillStatusChip | null;
};

export type SummaryApBillBucketGroup = {
  bucket: ShipmentApKind;
  label: string;
  rows: SummaryApBillTableRow[];
  originLegs: { currency_code: string; amount: number }[];
  bdtSubtotal: number;
};

export const displayBillOriginAmount = (bill: ShipmentApBillRow): number => {
  const nb = bill.net_balances;
  if (nb?.original_total != null && nb.original_total > 0) return nb.original_total;
  const openTxn = nb?.open_txn ?? 0;
  const paid = nb?.paid_amount ?? 0;
  if (openTxn > 0 || paid > 0) return round2(openTxn + paid);
  const code = (shipmentApBillPlugCurrency(bill) ?? 'BDT').toUpperCase();
  const books = displayBillTotal(bill);
  if (code === 'BDT') return books;
  return books;
};

export const displayBillOriginCurrencyCode = (bill: ShipmentApBillRow): string =>
  (shipmentApBillPlugCurrency(bill) ?? 'BDT').toUpperCase();

/** Books (BDT) face for Summary — not kernel `total_amount` on foreign AP. */
export function displayBillBooksBdtAmount(
  bill: ShipmentApBillRow,
  bucketPaid?: ShipmentApBucketPaidTotals | null,
): number {
  const originCode = displayBillOriginCurrencyCode(bill);
  const originAmount = displayBillOriginAmount(bill);
  if (originCode === 'BDT') return round2(originAmount);

  const foreignPaid = Number(bucketPaid?.foreign_paid) || 0;
  const bdtPaid = Number(bucketPaid?.bdt_paid) || 0;
  if (originAmount > 0 && foreignPaid > 0 && bdtPaid > 0) {
    return round2((originAmount / foreignPaid) * bdtPaid);
  }

  const rate = Number(bucketPaid?.conversion_rate);
  if (originAmount > 0 && Number.isFinite(rate) && rate > 0) {
    return round2(originAmount * rate);
  }

  return round2(originAmount);
}

function bucketPaidFromApFx(
  apFx: ShipmentApFxSnapshot | null | undefined,
  bucket: ShipmentApKind,
): ShipmentApBucketPaidTotals | null {
  if (!apFx) return null;
  return apFx[bucket] ?? null;
}

const isVoidedBill = (bill: ShipmentApBillRow): boolean =>
  bill.invoice_status?.toLowerCase() === 'voided';

export function buildSummaryApBillsByBucket(
  bills: ShipmentApBillRow[],
  apFx?: ShipmentApFxSnapshot | null,
): SummaryApBillBucketGroup[] {
  const active = bills.filter((b) => !isVoidedBill(b));
  const groups: SummaryApBillBucketGroup[] = [];

  for (const bucket of SHIPMENT_AP_COST_BUCKETS) {
    const inBucket = active.filter((b) => shipmentApBillBucket(b) === bucket);
    if (inBucket.length === 0) continue;

    const originByCode = new Map<string, number>();
    let bdtSubtotal = 0;

    const bucketPaid = bucketPaidFromApFx(apFx, bucket);

    const rows: SummaryApBillTableRow[] = inBucket.map((bill) => {
      const originCode = displayBillOriginCurrencyCode(bill);
      const originAmount = displayBillOriginAmount(bill);
      const bdtAmount = displayBillBooksBdtAmount(bill, bucketPaid);
      bdtSubtotal += bdtAmount;
      if (originAmount > 0) {
        originByCode.set(
          originCode,
          round2((originByCode.get(originCode) ?? 0) + originAmount),
        );
      }
      return {
        id: bill.id,
        invoiceLabel: apBillInvoiceLabel(bill),
        originCode,
        originAmount,
        bdtAmount,
        statusChip: apBillStatusChip(bill),
      };
    });

    const originLegs = [...originByCode.entries()]
      .map(([currency_code, amount]) => ({ currency_code, amount }))
      .sort((a, b) => a.currency_code.localeCompare(b.currency_code));

    groups.push({
      bucket,
      label: shipmentApKindLabel(bucket),
      rows,
      originLegs,
      bdtSubtotal: round2(bdtSubtotal),
    });
  }

  return groups;
}

export function summaryApBillsGrandBdt(groups: SummaryApBillBucketGroup[]): number {
  return round2(groups.reduce((s, g) => s + g.bdtSubtotal, 0));
}