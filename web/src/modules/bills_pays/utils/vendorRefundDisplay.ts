import { apBillPaperCurrencyCode as apInvoiceCurrencyFromMeta } from './apBillBooks';
import { apBillCurrencyGroups, apBillPaperConversionRate } from './parseApBillPaper';

export function vendorRefundDefaultSettlementCurrency(
  channelMeta: Record<string, unknown> | null | undefined,
  booksCurrency: string,
): string {
  const groups = apBillCurrencyGroups(channelMeta ?? null);
  if (groups.length === 1) {
    const c = (groups[0]?.currency_code ?? '').trim().toUpperCase();
    if (c && c !== booksCurrency) return c;
  }
  const code = apInvoiceCurrencyFromMeta(channelMeta ?? null);
  return code || booksCurrency;
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
  openCreditBooks: number,
  channelMeta: Record<string, unknown> | null | undefined,
  booksCurrency: string,
): { amount: number; currencyCode: string } {
  const currency = vendorRefundDefaultSettlementCurrency(channelMeta, booksCurrency);
  const rate = vendorRefundInvoiceConversionRate(channelMeta);
  if (currency !== booksCurrency && rate != null && rate > 0) {
    return {
      amount: Math.round((openCreditBooks / rate) * 100) / 100,
      currencyCode: currency,
    };
  }
  return { amount: openCreditBooks, currencyCode: booksCurrency };
}