import type { ThriftStockPricingInput, ThriftUnitCostBreakdown } from './computeThriftUnitCosts';

export function resolveListedSellPrice(
  pricing: ThriftStockPricingInput | undefined,
  breakdown: ThriftUnitCostBreakdown | undefined,
): number {
  if (!pricing) return breakdown?.display_listed_unit_price ?? 0;
  if (pricing.is_listed_price_manual) return pricing.listed_unit_price;
  return (
    breakdown?.display_listed_unit_price ??
    breakdown?.suggested_sell_unit_price ??
    pricing.listed_unit_price
  );
}
