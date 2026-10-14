import type { InvoicePaymentHistoryEntry } from 'src/modules/sales_invoice/types';
import { formatBdtTaka, formatSettlementCurrencyAmount } from 'src/utils/currency';

/** Currency the cash actually moved in (payment row), not the bill’s invoice currency. */
export const paymentHistorySettlementCode = (
  entry: InvoicePaymentHistoryEntry,
  billCurrencyCode?: string | null,
) => (entry.settlement_currency_code || billCurrencyCode || 'BDT').trim().toUpperCase();

export const isForeignSettlementPaymentHistory = (
  entry: InvoicePaymentHistoryEntry,
  billCurrencyCode?: string | null,
) => {
  const code = paymentHistorySettlementCode(entry, billCurrencyCode);
  if (code !== 'BDT') return true;
  const rate = Number(entry.exchange_rate) || 0;
  return rate > 0 && Math.abs(rate - 1) > 0.0001;
};

/**
 * Full pay receipt in BDT. Corrects legacy AP FX rows where pays.amount was alloc × rate
 * while pay_allocations.amount was already BDT.
 */
export const paymentHistoryReceiptBdt = (entry: InvoicePaymentHistoryEntry): number => {
  const allocBdt = Number(entry.amount) || 0;
  const receiptBdt = Number(entry.receipt_amount) || 0;
  const rate = Number(entry.exchange_rate) || 1;
  if (
    isForeignSettlementPaymentHistory(entry) &&
    allocBdt > 0 &&
    rate > 0 &&
    receiptBdt > 0 &&
    allocBdt <= receiptBdt / rate + 0.05
  ) {
    return receiptBdt;
  }
  if (
    isForeignSettlementPaymentHistory(entry) &&
    allocBdt > 0 &&
    rate > 0 &&
    Math.abs(receiptBdt - allocBdt * rate) < 0.02
  ) {
    return allocBdt;
  }
  return receiptBdt || allocBdt;
};

/** BDT applied to this bill / note (allocation). */
export const paymentHistoryBooksApplied = (entry: InvoicePaymentHistoryEntry): number =>
  Number(entry.amount) || 0;

/** Cash face in settlement currency (e.g. GBP received on a USD invoice refund). */
export const paymentHistoryCashFaceAmount = (entry: InvoicePaymentHistoryEntry): number => {
  const code = paymentHistorySettlementCode(entry);
  if (code === 'BDT') {
    return paymentHistoryReceiptBdt(entry);
  }
  const foreign = Number(entry.foreign_amount);
  if (Number.isFinite(foreign) && foreign > 0) {
    return Math.round(foreign * 100) / 100;
  }
  const rate = Number(entry.exchange_rate) || 0;
  const receipt = paymentHistoryReceiptBdt(entry);
  if (rate > 0 && receipt > 0) {
    return Math.round((receipt / rate) * 100) / 100;
  }
  return paymentHistoryBooksApplied(entry);
};

/** Settlement-currency amount applied to this bill (legacy; prefers payment cash face). */
export const paymentHistorySettlementOnBill = (
  entry: InvoicePaymentHistoryEntry,
  billCurrencyCode?: string | null,
): number => {
  const settleCode = paymentHistorySettlementCode(entry, billCurrencyCode);
  if (settleCode === 'BDT') {
    return paymentHistoryBooksApplied(entry);
  }
  return paymentHistoryCashFaceAmount(entry);
};

export const formatPaymentHistoryPrimary = (
  entry: InvoicePaymentHistoryEntry,
  billCurrencyCode?: string | null,
): string => {
  const code = paymentHistorySettlementCode(entry, billCurrencyCode);
  if (code === 'BDT') {
    return formatBdtTaka(paymentHistoryReceiptBdt(entry));
  }
  return formatSettlementCurrencyAmount(paymentHistoryCashFaceAmount(entry), code);
};

export const formatPaymentHistoryBooksCaption = (
  entry: InvoicePaymentHistoryEntry,
  billCurrencyCode?: string | null,
): string | null => {
  const code = paymentHistorySettlementCode(entry, billCurrencyCode);
  if (code === 'BDT') return null;
  const books = paymentHistoryBooksApplied(entry);
  const rate = Number(entry.exchange_rate) || 1;
  return `${formatBdtTaka(books)} @ ${rate} BDT/${code}`;
};

/** Match Pay detail: cash in settlement currency → books on bill */
export const paymentHistoryFxCaption = (
  entry: InvoicePaymentHistoryEntry,
  billCurrencyCode?: string | null,
): string | null => {
  if (!isForeignSettlementPaymentHistory(entry, billCurrencyCode)) return null;
  const code = paymentHistorySettlementCode(entry, billCurrencyCode);
  const rate = Number(entry.exchange_rate) || 1;
  const onBillBdt = paymentHistoryBooksApplied(entry);
  const payFx = paymentHistoryCashFaceAmount(entry);
  return `Settlement: ${payFx} ${code} @ ${rate} → ${formatBdtTaka(onBillBdt)}`;
};

export const paymentHistoryEntryCaption = (
  entry: InvoicePaymentHistoryEntry,
  opts?: { isAp?: boolean },
): string => {
  if (entry.entry_type === 'write_off') {
    return entry.write_off_reason ? `Write-off · ${entry.write_off_reason}` : 'Write-off';
  }
  const relatedNo = entry.related_invoice_no?.trim();
  const relatedKind = entry.related_document_kind;
  if (relatedKind === 'credit_note' && entry.payment_source === 'customer_cash') {
    const label = opts?.isAp ? 'Vendor refund received' : 'Refund received';
    return relatedNo ? `${label} · ${relatedNo}` : label;
  }
  if (relatedKind === 'debit_note' && entry.payment_source === 'customer_cash') {
    const label = opts?.isAp ? 'Vendor payment on debit note' : 'Payment on debit note';
    return relatedNo ? `${label} · ${relatedNo}` : label;
  }
  const method = entry.method?.replace(/_/g, ' ') ?? 'Payment';
  return method;
};

export type VendorRefundReceiptBucket = {
  currencyCode: string;
  foreignTotal: number;
  booksBdt: number;
};

export function aggregateVendorRefundReceipts(
  entries: InvoicePaymentHistoryEntry[],
  opts?: { isAp?: boolean },
): VendorRefundReceiptBucket[] {
  if (!opts?.isAp) return [];
  const map = new Map<string, { foreign: number; bdt: number }>();
  for (const entry of entries) {
    if (entry.voided_at) continue;
    if (entry.related_document_kind !== 'credit_note' || entry.payment_source !== 'customer_cash') {
      continue;
    }
    const code = paymentHistorySettlementCode(entry);
    const bdt = paymentHistoryBooksApplied(entry);
    const fx = code === 'BDT' ? bdt : paymentHistoryCashFaceAmount(entry);
    const prev = map.get(code) ?? { foreign: 0, bdt: 0 };
    map.set(code, {
      foreign: Math.round((prev.foreign + fx) * 100) / 100,
      bdt: Math.round((prev.bdt + bdt) * 100) / 100,
    });
  }
  return [...map.entries()]
    .map(([currencyCode, v]) => ({
      currencyCode,
      foreignTotal: v.foreign,
      booksBdt: v.bdt,
    }))
    .sort((a, b) => a.currencyCode.localeCompare(b.currencyCode));
}
