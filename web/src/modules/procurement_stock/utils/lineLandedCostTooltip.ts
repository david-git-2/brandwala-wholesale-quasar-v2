import type { LineLandedCostBreakdown } from 'src/shared/shipment-engine';

const fmt = (n: number) => (Math.round(n * 100) / 100).toFixed(2);

/** Multi-line hint for the landed cost cell (purchase currency + BDT). */
export const formatLineLandedCostTooltip = (
  breakdown: LineLandedCostBreakdown,
  purchaseCurrencySymbol: string,
): string => {
  const sym = purchaseCurrencySymbol || '';
  const lines: string[] = [];
  lines.push(`Purchase: ${sym}${fmt(breakdown.purchasePricePerUnit)}`);
  if (breakdown.cargoSharePerUnit > 0.000_5) {
    lines.push(`+ Cargo share/unit: ${sym}${fmt(breakdown.cargoSharePerUnit)}`);
  }
  lines.push(`= Base/unit: ${sym}${fmt(breakdown.basePerUnit)}`);
  if (breakdown.transactionRate != null) {
    lines.push(`× Blended FX: ${fmt(breakdown.transactionRate)}`);
  }
  lines.push(`= Landed: ৳${fmt(breakdown.landedCostBdt)}`);
  return lines.join('\n');
};
