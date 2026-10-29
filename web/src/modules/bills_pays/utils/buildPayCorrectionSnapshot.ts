import type { PayDetail } from '../repositories/paysRepository';
import type { PayCorrectionSnapshot } from '../types/payCorrectionSnapshot';
import type { InvoicePaymentHistoryEntry } from 'src/modules/sales_invoice/types';
import { formatBdtTaka, formatSettlementCurrencyAmount } from 'src/utils/currency';
import { paymentHistoryReceiptBdt } from './paymentHistoryDisplay';

export function buildPayCorrectionSnapshot(pay: PayDetail): PayCorrectionSnapshot {
  const firstInst = pay.instruments[0];
  return {
    paymentId: pay.id,
    paymentDate: pay.payment_date,
    source: pay.source,
    method: pay.method,
    settlementCurrencyCode: (pay.settlement_currency_code ?? 'BDT').trim().toUpperCase(),
    foreignAmount: pay.foreign_amount,
    exchangeRate: Number(pay.exchange_rate) || 1,
    transactionRate: pay.transaction_rate ?? null,
    sourceCurrencyCode: pay.source_currency_code ?? null,
    cashbookPointPotId: pay.cashbook_point_pot_id ?? null,
    amountBdt: Number(pay.amount) || 0,
    reference: pay.reference,
    instrumentMethodCode: firstInst?.payment_method_code ?? null,
  };
}

/** From bundle payment history (includes pot/FX when list_invoice_payment_history exposes them). */
export function buildPayCorrectionSnapshotFromHistory(
  entry: InvoicePaymentHistoryEntry,
): PayCorrectionSnapshot | null {
  const paymentId = entry.payment_id;
  if (!paymentId) return null;
  const firstInst = entry.instruments[0];
  const source = (entry.payment_source ?? '').trim();
  if (!source) return null;

  return {
    paymentId,
    paymentDate: entry.payment_date,
    source,
    method: entry.method,
    settlementCurrencyCode: (entry.settlement_currency_code ?? 'BDT').trim().toUpperCase(),
    foreignAmount: entry.foreign_amount ?? null,
    exchangeRate: Number(entry.exchange_rate) || 1,
    transactionRate: entry.transaction_rate ?? null,
    sourceCurrencyCode: entry.source_currency_code ?? null,
    cashbookPointPotId: entry.cashbook_point_pot_id ?? null,
    amountBdt: paymentHistoryReceiptBdt(entry),
    reference: entry.payment_reference ?? firstInst?.reference ?? null,
    instrumentMethodCode: firstInst?.payment_method_code ?? null,
  };
}

export function historyEntrySummaryLine(entry: InvoicePaymentHistoryEntry): string {
  const code = (entry.settlement_currency_code ?? 'BDT').trim().toUpperCase();
  const receiptBdt = paymentHistoryReceiptBdt(entry);
  if (code !== 'BDT') {
    const foreign = entry.foreign_amount;
    const rate = Number(entry.exchange_rate) || 1;
    if (foreign != null && Number.isFinite(Number(foreign))) {
      return `${formatSettlementCurrencyAmount(Number(foreign), code)} @ ${rate} BDT/${code} (${formatBdtTaka(receiptBdt)})`;
    }
  }
  return formatBdtTaka(receiptBdt);
}
