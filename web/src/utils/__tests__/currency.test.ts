import { describe, expect, it } from 'vitest';
import {
  formatAmountBdt,
  formatBdtTaka,
  formatCurrencyAmount,
  formatSettlementCurrencyAmount,
  resolveSettlementCurrencySymbol,
} from '../currency';

describe('currency utils', () => {
  it('formats BDT with Indian digit grouping', () => {
    expect(formatAmountBdt(1234567.5)).toBe('12,34,567.50');
    expect(formatAmountBdt(-100000)).toBe('-1,00,000.00');
    expect(formatAmountBdt(null)).toBe('0.00');
    expect(formatBdtTaka(250000)).toBe('৳2,50,000.00');
  });

  it('formats foreign currencies with standard grouping and symbols', () => {
    expect(formatCurrencyAmount(100000, 'GBP')).toBe('£100,000.00');
    expect(formatCurrencyAmount(12345.67, 'USD')).toBe('$12,345.67');
    expect(formatCurrencyAmount(5000, 'EUR')).toBe('€5,000.00');
    expect(formatCurrencyAmount(8800, 'CNY')).toBe('¥8,800.00');
    expect(formatCurrencyAmount(1500, 'AED')).toBe('1,500.00 AED');
  });

  it('keeps formatSettlementCurrencyAmount backwards-compatible while fixing foreign grouping', () => {
    expect(formatSettlementCurrencyAmount(100000, 'BDT')).toBe('৳1,00,000.00');
    expect(formatSettlementCurrencyAmount(100000, 'GBP')).toBe('£100,000.00');
    expect(formatSettlementCurrencyAmount(1000, 'USD', 'USD')).toBe('$1,000.00');
  });

  it('handles symbol-only foreign amounts without defaulting to BDT', () => {
    expect(formatCurrencyAmount(12500, null, '£')).toBe('£12,500.00');
    expect(formatCurrencyAmount(12500, '', '£')).toBe('£12,500.00');
    expect(formatCurrencyAmount(12500, '', '৳')).toBe('৳12,500.00');
  });

  it('respects custom fraction digit options', () => {
    expect(formatCurrencyAmount(1200, 'GBP', null, { minimumFractionDigits: 0, maximumFractionDigits: 0 })).toBe('£1,200');
    expect(formatAmountBdt(1200, { minimumFractionDigits: 0, maximumFractionDigits: 0 })).toBe('1,200');
  });

  it('resolves settlement symbols while ignoring ISO-code duplicates', () => {
    expect(resolveSettlementCurrencySymbol('GBP', 'GBP')).toBe('£');
    expect(resolveSettlementCurrencySymbol('CNY')).toBe('¥');
    expect(resolveSettlementCurrencySymbol('AED')).toBeNull();
  });
});
