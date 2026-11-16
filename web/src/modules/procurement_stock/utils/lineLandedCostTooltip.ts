import type { LineLandedCostBreakdown } from 'src/shared/shipment-engine';

const fmt = (n: number) => (Math.round(n * 100) / 100).toFixed(2);
const fmtRate = (n: number) => (Math.round(n * 10_000) / 10_000).toFixed(4);
const fmtKg = (n: number) => (Math.round(n * 100_000) / 100_000).toFixed(3);

export type LineLandedCostTooltipOpts = {
  quantity?: number;
  productName?: string | null;
  /** Unit gross weight (product + pack) in kg — for freight line in tooltip. */
  unitKg?: number | null;
  /** Shipment freight Taka per kg (paid pool). */
  freightBdtPerKg?: number | null;
};

const otherCostsPerUnit = (breakdown: LineLandedCostBreakdown): number => {
  let sum = 0;
  const add = (v: number | undefined) => {
    if (v != null && v > 0) sum += v;
  };
  add(breakdown.surplusBdtPerUnit);
  add(breakdown.customsBdtPerUnit);
  add(breakdown.handlingBdtPerUnit);
  add(breakdown.financeBdtPerUnit);
  add(breakdown.otherBdtPerUnit);
  return sum;
};

const freightBdtOnUnit = (
  breakdown: LineLandedCostBreakdown,
  opts?: LineLandedCostTooltipOpts,
): number => {
  if (breakdown.freightBdtPerUnit != null && breakdown.freightBdtPerUnit > 0) {
    return breakdown.freightBdtPerUnit;
  }
  const rate = opts?.freightBdtPerKg;
  const kg = opts?.unitKg;
  if (rate != null && rate > 0 && kg != null && kg > 0) return rate * kg;
  if (breakdown.cargoConversionRate != null && breakdown.cargoSharePerUnit > 0) {
    return breakdown.cargoSharePerUnit * breakdown.cargoConversionRate;
  }
  return 0;
};

const goodsBdtPerUnit = (breakdown: LineLandedCostBreakdown): number => {
  if (breakdown.goodsBdtPerUnit != null) return breakdown.goodsBdtPerUnit;
  if (breakdown.productConversionRate != null) {
    return breakdown.purchasePricePerUnit * breakdown.productConversionRate;
  }
  return breakdown.purchasePricePerUnit;
};

const formatInternationalTooltip = (
  breakdown: LineLandedCostBreakdown,
  purchaseSym: string,
  bdtSym: string,
  opts?: LineLandedCostTooltipOpts,
): string => {
  const lines: string[] = [];
  const purchaseCode = purchaseSym || '£';

  lines.push(`Purchase price: ${purchaseCode}${fmt(breakdown.purchasePricePerUnit)}`);

  if (breakdown.productConversionRate != null) {
    lines.push(
      `Conversion rate: 1 ${purchaseCode} = ${bdtSym}${fmtRate(breakdown.productConversionRate)}`,
    );
  }

  lines.push(`Goods in ${bdtSym}: ${bdtSym}${fmt(goodsBdtPerUnit(breakdown))}`);

  const freightPerKg = opts?.freightBdtPerKg;
  const unitKg = opts?.unitKg;
  const freightUnit = freightBdtOnUnit(breakdown, opts);

  if (freightPerKg != null && freightPerKg > 0) {
    lines.push(`Freight: ${bdtSym}${fmt(freightPerKg)} / kg`);
    if (unitKg != null && unitKg > 0) {
      lines.push(`  × ${fmtKg(unitKg)} kg → ${bdtSym}${fmt(freightUnit)} on this unit`);
    } else if (freightUnit > 0.005) {
      lines.push(`  → ${bdtSym}${fmt(freightUnit)} on this unit`);
    }
  } else if (freightUnit > 0.005) {
    lines.push(`Freight on unit: ${bdtSym}${fmt(freightUnit)}`);
  }

  const other = otherCostsPerUnit(breakdown);
  if (other > 0.005) {
    lines.push(`Other costs: ${bdtSym}${fmt(other)}`);
  }

  lines.push(`─────────────`);
  lines.push(`Total per unit: ${bdtSym}${fmt(breakdown.landedCostBdt)}`);

  const qty = opts?.quantity;
  if (qty != null && qty > 1) {
    lines.push(`Line total (×${qty}): ${bdtSym}${fmt(breakdown.landedCostBdt * qty)}`);
  }

  return lines.join('\n');
};

const formatDomesticTooltip = (
  breakdown: LineLandedCostBreakdown,
  bdtSym: string,
  opts?: LineLandedCostTooltipOpts,
): string => {
  const lines: string[] = [];
  lines.push(`Purchase price: ${bdtSym}${fmt(breakdown.purchasePricePerUnit)}`);
  const freightUnit = freightBdtOnUnit(breakdown, opts);
  if (freightUnit > 0.005) lines.push(`Freight on unit: ${bdtSym}${fmt(freightUnit)}`);
  lines.push(`─────────────`);
  lines.push(`Total per unit: ${bdtSym}${fmt(breakdown.landedCostBdt)}`);
  const qty = opts?.quantity;
  if (qty != null && qty > 1) {
    lines.push(`Line total (×${qty}): ${bdtSym}${fmt(breakdown.landedCostBdt * qty)}`);
  }
  return lines.join('\n');
};

/** Hover text on shipment line unit cost. */
export const formatLineLandedCostTooltip = (
  breakdown: LineLandedCostBreakdown,
  purchaseCurrencySymbol: string,
  costCurrencySymbol = '৳',
  opts?: LineLandedCostTooltipOpts,
): string => {
  const purchaseSym = purchaseCurrencySymbol || '£';
  const bdtSym = costCurrencySymbol || '৳';

  const header: string[] = [];
  const name = opts?.productName?.trim();
  if (name) header.push(name);
  const qty = opts?.quantity;
  if (qty != null && qty > 0) header.push(`Qty: ${qty.toLocaleString()}`);

  const body =
    breakdown.productConversionRate != null
      ? formatInternationalTooltip(breakdown, purchaseSym, bdtSym, opts)
      : formatDomesticTooltip(breakdown, bdtSym, opts);

  if (header.length === 0) return body;
  return `${header.join('\n')}\n\n${body}`;
};