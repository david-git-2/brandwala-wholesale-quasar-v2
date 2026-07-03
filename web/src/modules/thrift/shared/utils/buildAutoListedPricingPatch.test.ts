import { describe, test, expect } from 'vitest';
import { buildAutoListedPricingPatch } from './buildAutoListedPricingPatch';
import type { ThriftStock } from '../../stock/types';
import type { ThriftUnitCostBreakdown } from './computeThriftUnitCosts';

describe('buildAutoListedPricingPatch', () => {
  const stock = {
    id: 1,
    pricing: {
      listed_unit_price: 137,
      is_listed_price_manual: true,
      markup_rate_override: 0.5,
      cost_of_goods_sold: 0,
      target_price: 0,
      extra_expense_cost: 0,
    },
  } as ThriftStock;

  const breakdown = {
    suggested_sell_unit_price: 190,
  } as ThriftUnitCostBreakdown;

  test('sets auto listed price from breakdown and clears manual flag', () => {
    const patch = buildAutoListedPricingPatch(stock, breakdown);
    expect(patch.is_listed_price_manual).toBe(false);
    expect(patch.listed_unit_price).toBe(190);
    expect(patch.markup_rate_override).toBe(0.5);
  });
});
