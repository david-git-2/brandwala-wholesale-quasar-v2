import type { ThriftStock } from '../../stock/types';
import type { ThriftUnitCostBreakdown } from './computeThriftUnitCosts';

type ThriftStockPricing = NonNullable<ThriftStock['pricing']>;

export function buildAutoListedPricingPatch(
  stock: ThriftStock,
  breakdown: ThriftUnitCostBreakdown,
): ThriftStockPricing {
  const currentPricing = stock.pricing || {
    cost_of_goods_sold: 0,
    target_price: 0,
    listed_unit_price: 0,
    extra_expense_cost: 0,
  };
  return {
    ...currentPricing,
    is_listed_price_manual: false,
    listed_unit_price: breakdown.suggested_sell_unit_price,
  };
}
