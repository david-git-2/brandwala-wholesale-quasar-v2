import type { LineLandedCostBreakdown } from 'src/shared/shipment-engine';

const fmt = (n: number) => (Math.round(n * 100) / 100).toFixed(2);
const fmtRate = (n: number) => (Math.round(n * 10_000) / 10_000).toFixed(4);

/** Multi-line hint for the landed cost cell (purchase currency + BDT). */
export const formatLineLandedCostTooltip = (
  breakdown: LineLandedCostBreakdown,
  purchaseCurrencySymbol: string,
  costCurrencySymbol = '৳',
): string => {
  const purchaseSym = purchaseCurrencySymbol || '';
  const bdtSym = costCurrencySymbol || '৳';
  const lines: string[] = [];

  const productBdt =
    breakdown.productConversionRate != null
      ? breakdown.purchasePricePerUnit * breakdown.productConversionRate
      : breakdown.purchasePricePerUnit;

  lines.push(`Product: ${purchaseSym}${fmt(breakdown.purchasePricePerUnit)}`);
  if (breakdown.productConversionRate != null) {
    lines.push(
      `  × Material FX: ${bdtSym}${fmtRate(breakdown.productConversionRate)} / ${purchaseSym}`,
    );
    lines.push(`  → ${bdtSym}${fmt(productBdt)} on product`);
  }

  if (breakdown.cargoSharePerUnit > 0.000_5) {
    const cargoBdt =
      breakdown.cargoConversionRate != null
        ? breakdown.cargoSharePerUnit * breakdown.cargoConversionRate
        : breakdown.cargoSharePerUnit;
    lines.push(`Cargo share/unit: ${purchaseSym}${fmt(breakdown.cargoSharePerUnit)}`);
    if (breakdown.cargoConversionRate != null) {
      lines.push(
        `  × Freight FX: ${bdtSym}${fmtRate(breakdown.cargoConversionRate)} / ${purchaseSym}`,
      );
      lines.push(`  → ${bdtSym}${fmt(cargoBdt)} on freight share`);
    }
  }

  if (breakdown.productConversionRate != null || breakdown.cargoConversionRate != null) {
    lines.push(`= Landed/unit: ${bdtSym}${fmt(breakdown.landedCostBdt)}`);
    if (breakdown.transactionRate != null) {
      lines.push('');
      lines.push(
        `Payment blend (weighted): ${bdtSym}${fmtRate(breakdown.transactionRate)} / ${purchaseSym}`,
      );
      lines.push('(Not used on this line — material & freight rates above.)');
    }
  } else {
    lines.push(`= Landed/unit: ${bdtSym}${fmt(breakdown.landedCostBdt)}`);
  }

  return lines.join('\n');
};
