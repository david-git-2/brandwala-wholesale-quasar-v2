import type { InvoicePaymentHistoryEntry } from 'src/modules/sales_invoice/types';
import { formatBdtTaka } from 'src/utils/currency';

export const paymentHistorySettlementCode = (
  entry: InvoicePaymentHistoryEntry,
  billCurrencyCode?: string | null,
) => (billCurrencyCode || entry.settlement_currency_code || 'BDT').toUpperCase();

export const isForeignSettlementPaymentHistory = (
  entry: InvoicePaymentHistoryEntry,
  billCurrencyCode?: string | null,
) => {
  const rate = Number(entry.exchange_rate) || 0;
  if (rate <= 0) return false;
  const entryCode = String(entry.settlement_currency_code ?? '').toUpperCase();
  if (entryCode && entryCode !== 'BDT') return true;
  const code = paymentHistorySettlementCode(entry, billCurrencyCode);
  return code !== 'BDT';
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

/** Settlement-currency amount applied to this bill. */
export const paymentHistorySettlementOnBill = (
  entry: InvoicePaymentHistoryEntry,
  billCurrencyCode?: string | null,
): number => {
  const allocBdt = Number(entry.amount) || 0;
  const rate = Number(entry.exchange_rate) || 1;
  if (!isForeignSettlementPaymentHistory(entry, billCurrencyCode) || rate <= 0) return allocBdt;
  const receiptBdt = paymentHistoryReceiptBdt(entry);
  if (receiptBdt > 0) {
    return Math.round((receiptBdt / rate) * 100) / 100;
  }
  if (allocBdt > rate * 50) {
    return Math.round((allocBdt / rate) * 100) / 100;
  }
  return allocBdt;
};

/** Match Pay detail: `Settlement: 1.69 GBP @ 166 → ৳280.38` */
export const paymentHistoryFxCaption = (
  entry: InvoicePaymentHistoryEntry,
  billCurrencyCode?: string | null,
): string | null => {
  if (!isForeignSettlementPaymentHistory(entry, billCurrencyCode)) return null;
  const code = paymentHistorySettlementCode(entry, billCurrencyCode);
  const rate = Number(entry.exchange_rate) || 1;
  const onBillBdt = Number(entry.amount) || 0;
  const onBillFx = paymentHistorySettlementOnBill(entry, billCurrencyCode);
  const receiptBdt = paymentHistoryReceiptBdt(entry);
  const payFx = rate > 0 ? Math.round((receiptBdt / rate) * 100) / 100 : 0;

  let line = `Settlement: ${onBillFx} ${code} @ ${rate} → ${formatBdtTaka(onBillBdt)}`;
  if (receiptBdt > 0 && Math.abs(receiptBdt - onBillBdt) > 0.005) {
    line += ` · Payment ${payFx} ${code} → ${formatBdtTaka(receiptBdt)}`;
  }
  return line;
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
