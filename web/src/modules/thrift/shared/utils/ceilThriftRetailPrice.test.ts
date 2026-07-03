import { describe, it, expect } from 'vitest';
import { ceilThriftRetailPrice } from './ceilThriftRetailPrice';

describe('ceilThriftRetailPrice', () => {
  it('should round prices ending in 50 or 90 correctly', () => {
    expect(ceilThriftRetailPrice(129)).toBe(150);
    expect(ceilThriftRetailPrice(151)).toBe(190);
    expect(ceilThriftRetailPrice(100)).toBe(150);
    expect(ceilThriftRetailPrice(190)).toBe(190);
    expect(ceilThriftRetailPrice(191)).toBe(250);
    expect(ceilThriftRetailPrice(50)).toBe(50);
    expect(ceilThriftRetailPrice(0)).toBe(50);
    expect(ceilThriftRetailPrice(-10)).toBe(50);
  });
});
