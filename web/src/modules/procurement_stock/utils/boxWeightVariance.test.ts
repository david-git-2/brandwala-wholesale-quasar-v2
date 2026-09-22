import { describe, test, expect } from 'vitest';
import {
  boxWeightDiffKg,
  boxWeightVarianceStatus,
  describeBoxTotalsNetDiff,
  describeBoxVsInvoiceCargo,
  formatBoxWeightDiffKg,
} from './boxWeightVariance';

describe('boxWeightVariance', () => {
  test('boxWeightDiffKg is shipping minus received', () => {
    expect(boxWeightDiffKg(10, 10.5)).toBe(0.5);
    expect(boxWeightDiffKg(10.3, 10)).toBe(-0.3);
  });

  test('boxWeightVarianceStatus boundaries', () => {
    expect(boxWeightVarianceStatus(10, 10)).toBe('match');
    expect(boxWeightVarianceStatus(10, 10.01)).toBe('match');
    expect(boxWeightVarianceStatus(10, 10.02)).toBe('weight_loss');
    expect(boxWeightVarianceStatus(10, 9.99)).toBe('match');
    expect(boxWeightVarianceStatus(10, 9.98)).toBe('minor_over');
  });

  test('formatBoxWeightDiffKg signs positive diff', () => {
    expect(formatBoxWeightDiffKg(10, 10.5)).toBe('+0.50');
    expect(formatBoxWeightDiffKg(10, 9.5)).toBe('-0.50');
  });

  test('describeBoxTotalsNetDiff explains negative diff as received heavier', () => {
    const d = describeBoxTotalsNetDiff(100, 84.09);
    expect(d.signedKgLabel).toBe('-15.91 kg');
    expect(d.explanation).toContain('Received is 15.91 kg heavier');
  });

  test('describeBoxVsInvoiceCargo explains below invoice', () => {
    const d = describeBoxVsInvoiceCargo('Box shipping', 84.09, 100);
    expect(d.signedKgLabel).toBe('-15.91 kg');
    expect(d.explanation).toContain('below invoice cargo');
  });
});
