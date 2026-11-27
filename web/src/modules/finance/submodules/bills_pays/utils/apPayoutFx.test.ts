import { describe, expect, it } from 'vitest';
import {
  amountsMatchToCent,
  computePayoutBooksAmount,
  computePayoutBooksTotal,
  derivePaymentToSourceCrossRate,
  needsPayoutBooksFx,
  needsPayoutSeparateBooksFx,
  needsPayoutTransactionRate,
} from './apPayoutFx';

describe('apPayoutFx', () => {
  it('handles 1-currency books payout (BDT bill, BDT pot, BDT books)', () => {
    expect(needsPayoutTransactionRate('BDT', 'BDT')).toBe(false);
    expect(needsPayoutBooksFx('BDT', 'BDT')).toBe(false);
    expect(needsPayoutSeparateBooksFx('BDT', 'BDT', 'BDT')).toBe(false);
    expect(
      computePayoutBooksTotal({
        paymentCurrency: 'BDT',
        sourceCurrency: 'BDT',
        booksCurrency: 'BDT',
        paymentAmount: 1000,
        paymentToSourceRate: 1,
        paymentToBooksRate: null,
      }),
    ).toBeNull();
  });

  it('handles 2-currency payout (GBP bill, BDT pot, BDT books)', () => {
    expect(needsPayoutTransactionRate('GBP', 'BDT')).toBe(true);
    expect(needsPayoutBooksFx('GBP', 'BDT')).toBe(true);
    expect(needsPayoutSeparateBooksFx('GBP', 'BDT', 'BDT')).toBe(false);
    expect(
      computePayoutBooksTotal({
        paymentCurrency: 'GBP',
        sourceCurrency: 'BDT',
        booksCurrency: 'BDT',
        paymentAmount: 100,
        paymentToSourceRate: 150.125,
        paymentToBooksRate: null,
      }),
    ).toBe(15012.5);
  });

  it('handles 3-currency payout (GBP bill, USD pot, BDT books)', () => {
    expect(needsPayoutTransactionRate('GBP', 'USD')).toBe(true);
    expect(needsPayoutBooksFx('GBP', 'BDT')).toBe(true);
    expect(needsPayoutSeparateBooksFx('GBP', 'USD', 'BDT')).toBe(true);
    expect(
      computePayoutBooksTotal({
        paymentCurrency: 'GBP',
        sourceCurrency: 'USD',
        booksCurrency: 'BDT',
        paymentAmount: 200,
        paymentToSourceRate: 1.25,
        paymentToBooksRate: 150,
      }),
    ).toBe(30000);
  });

  it('derives payment-to-source cross-rate from books rates', () => {
    expect(derivePaymentToSourceCrossRate(150, 120)).toBe(1.25);
    expect(derivePaymentToSourceCrossRate(150, 0)).toBeNull();
    expect(derivePaymentToSourceCrossRate(null, 120)).toBeNull();
  });

  it('rounds books amounts and compares to nearest cent', () => {
    expect(computePayoutBooksAmount('USD', 10.005, 120, 'BDT')).toBe(1200.6);
    expect(amountsMatchToCent(1200.601, 1200.6)).toBe(true);
    expect(amountsMatchToCent(1200.62, 1200.6)).toBe(false);
  });
});
