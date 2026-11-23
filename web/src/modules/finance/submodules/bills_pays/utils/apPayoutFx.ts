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

export const roundCurrencyAmount = (value: number): number =>
  Math.round(value * 100) / 100;

export const roundExchangeRate = (value: number): number =>
  Math.round(value * 1_000_000) / 1_000_000;

export const amountsMatchToCent = (
  a: number | null | undefined,
  b: number | null | undefined,
): boolean => Math.round((a ?? 0) * 100) === Math.round((b ?? 0) * 100);

/**
 * Derive `sourceCurrency` per 1 `paymentCurrency` from each currency's books rate.
 * Example: payment=GBP (150 BDT), source=USD (120 BDT) -> 150 / 120 = 1.25 USD per 1 GBP.
 */
export const derivePaymentToSourceCrossRate = (
  paymentToBooksRate: number | null | undefined,
  sourceToBooksRate: number | null | undefined,
): number | null => {
  if (
    paymentToBooksRate == null ||
    sourceToBooksRate == null ||
    !Number.isFinite(paymentToBooksRate) ||
    !Number.isFinite(sourceToBooksRate) ||
    paymentToBooksRate <= 0 ||
    sourceToBooksRate <= 0
  ) {
    return null;
  }
  return roundExchangeRate(paymentToBooksRate / sourceToBooksRate);
};

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
  return roundCurrencyAmount(foreignAmount * booksExchangeRate);
};

export const computePayoutBooksTotal = (params: {
  paymentCurrency: string;
  sourceCurrency: string;
  booksCurrency: string;
  paymentAmount: number | null;
  paymentToSourceRate: number | null;
  paymentToBooksRate: number | null;
}): number | null => {
  const {
    paymentCurrency,
    sourceCurrency,
    booksCurrency,
    paymentAmount,
    paymentToSourceRate,
    paymentToBooksRate,
  } = params;
  if (!needsPayoutBooksFx(paymentCurrency, booksCurrency)) return null;
  const effectiveRate = needsPayoutSeparateBooksFx(paymentCurrency, sourceCurrency, booksCurrency)
    ? paymentToBooksRate
    : paymentToSourceRate;
  return computePayoutBooksAmount(paymentCurrency, paymentAmount, effectiveRate, booksCurrency);
};
