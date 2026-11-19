import { apBillPaperConversionRate } from './parseApBillPaper';

/** Vendor refund is always recorded in the bill / credit note header currency. */
export function vendorRefundBillCurrency(
  invoiceCurrencyCode: string | null | undefined,
  booksCurrency: string,
): string {
  const header = (invoiceCurrencyCode ?? '').trim().toUpperCase();
  return header || booksCurrency;
}

export function vendorRefundDefaultSettlementCurrency(
  _channelMeta: Record<string, unknown> | null | undefined,
  booksCurrency: string,
  invoiceCurrencyCode?: string | null,
): string {
  return vendorRefundBillCurrency(invoiceCurrencyCode, booksCurrency);
}

export function vendorRefundInvoiceConversionRate(
  channelMeta: Record<string, unknown> | null | undefined,
): number | null {
  const fromPaper = apBillPaperConversionRate(channelMeta ?? null);
  if (fromPaper != null && fromPaper > 0) return fromPaper;
  const raw = channelMeta?.ap_paper;
  if (!raw || typeof raw !== 'object') return null;
  const direct = Number((raw as Record<string, unknown>).conversion_rate);
  if (Number.isFinite(direct) && direct > 0 && Math.abs(direct - 1) > 0.0001) return direct;
  return null;
}

export function vendorRefundOpenCreditFace(
  openCreditAmount: number,
  channelMeta: Record<string, unknown> | null | undefined,
  booksCurrency: string,
  invoiceCurrencyCode?: string | null,
): { amount: number; currencyCode: string } {
  const amount = Math.max(0, Number(openCreditAmount) || 0);
  const currency = vendorRefundBillCurrency(invoiceCurrencyCode, booksCurrency);
  return { amount, currencyCode: currency };
}