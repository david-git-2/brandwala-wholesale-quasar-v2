import { apBillCurrencyGroups } from './parseApBillPaper';

export function defaultApPaymentCurrency(
  bills: Array<{ channel_meta: Record<string, unknown> | null | undefined }>,
  booksCurrencyCode = 'BDT',
): string {
  const codes = new Set<string>();
  for (const bill of bills) {
    for (const group of apBillCurrencyGroups(bill.channel_meta ?? null)) {
      const code = group.currency_code?.trim().toUpperCase();
      if (code) codes.add(code);
    }
  }
  if (codes.size === 1) return [...codes][0];
  const base = booksCurrencyCode.trim().toUpperCase();
  return base || 'BDT';
}

export const currenciesMatch = (a: string, b: string): boolean =>
  a.trim().toUpperCase() === b.trim().toUpperCase();

export const needsPayoutTransactionRate = (paymentCurrency: string, sourceCurrency: string): boolean =>
  !currenciesMatch(paymentCurrency, sourceCurrency);

export const needsPayoutBooksFx = (paymentCurrency: string, booksCurrencyCode = 'BDT'): boolean =>
  !currenciesMatch(paymentCurrency, booksCurrencyCode);

/** Books rate fields only when books conversion differs from pot→payment rate. */
export const needsPayoutSeparateBooksFx = (
  paymentCurrency: string,
  sourceCurrency: string,
  booksCurrencyCode = 'BDT',
): boolean =>
  needsPayoutBooksFx(paymentCurrency, booksCurrencyCode) &&
  !currenciesMatch(sourceCurrency, booksCurrencyCode);

export const computePayoutBooksAmount = (
  paymentCurrency: string,
  foreignAmount: number | null,
  booksExchangeRate: number | null,
  booksCurrencyCode = 'BDT',
): number | null => {
  if (!needsPayoutBooksFx(paymentCurrency, booksCurrencyCode)) return null;
  if (foreignAmount == null || booksExchangeRate == null || foreignAmount <= 0 || booksExchangeRate <= 0) {
    return null;
  }
  return Math.round(foreignAmount * booksExchangeRate * 100) / 100;
};
