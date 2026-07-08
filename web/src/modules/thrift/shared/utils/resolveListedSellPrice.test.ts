import { describe, it, expect } from 'vitest';
import { resolveListedSellPrice } from './resolveListedSellPrice';

describe('resolveListedSellPrice', () => {
  it('should return breakdown.display_listed_unit_price if no pricing exists', () => {
    const breakdown = { display_listed_unit_price: 150 } as any;
    expect(resolveListedSellPrice(undefined, breakdown)).toBe(150);
  });

  it('should return pricing.listed_unit_price if manual flag is true', () => {
    const pricing = { listed_unit_price: 137, is_listed_price_manual: true };
    const breakdown = { display_listed_unit_price: 150 } as any;
    expect(resolveListedSellPrice(pricing, breakdown)).toBe(137);
  });

  it('should return breakdown.display_listed_unit_price or breakdown.suggested_sell_unit_price if manual flag is false', () => {
    const pricing = { listed_unit_price: 137, is_listed_price_manual: false };
    const breakdown = { display_listed_unit_price: 150, suggested_sell_unit_price: 190 } as any;
    expect(resolveListedSellPrice(pricing, breakdown)).toBe(150);

    const breakdown2 = { suggested_sell_unit_price: 190 } as any;
    expect(resolveListedSellPrice(pricing, breakdown2)).toBe(190);
  });
});
