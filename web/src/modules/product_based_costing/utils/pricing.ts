import { roundBdtUpToZeroOrFive } from 'src/modules/costingFile/utils/costingCalculations';

export type OfferPricingMode = 'landed_cost_plus' | 'gbp_vat_then_profit';

export const DEFAULT_OFFER_PRICING_MODE: OfferPricingMode = 'landed_cost_plus';

export const normalizeOfferPricingMode = (value: unknown): OfferPricingMode =>
  value === 'gbp_vat_then_profit' ? 'gbp_vat_then_profit' : 'landed_cost_plus';

type OfferPriceInput = {
  priceGbp: number;
  productWeight: number;
  packageWeight: number;
  cargoRate: number;
  conversionRate: number;
  profitRate: number;
  vatRate?: number;
  offerPricingMode?: OfferPricingMode | string | null;
};

export const toNumberSafe = (value: unknown) => {
  const normalized =
    typeof value === 'string'
      ? value
          .replace(/,/g, '')
          .replace(/[^\d.-]/g, '')
          .trim()
      : value;
  const num = Number(normalized ?? 0);
  return Number.isNaN(num) ? 0 : num;
};

export const getUnitTotalCostGbp = ({
  priceGbp,
  productWeight,
  packageWeight,
  cargoRate,
}: Pick<OfferPriceInput, 'priceGbp' | 'productWeight' | 'packageWeight' | 'cargoRate'>) => {
  const cargoCostGbp = ((productWeight + packageWeight) / 1000) * cargoRate;
  return priceGbp + cargoCostGbp;
};

export const getUnitCostBdt = (
  input: Pick<
    OfferPriceInput,
    'priceGbp' | 'productWeight' | 'packageWeight' | 'cargoRate' | 'conversionRate'
  >,
) => {
  // Keep BDT cost aligned with the displayed GBP precision (2 decimals),
  // so values like shown "2.90" convert consistently.
  const unitTotalCostGbpRounded = Math.round(getUnitTotalCostGbp(input) * 100) / 100;
  return Math.ceil(unitTotalCostGbpRounded * input.conversionRate - 1e-9);
};

export const calculateOfferPriceBdt = (input: OfferPriceInput) => {
  const profitRate = input.profitRate;
  if (normalizeOfferPricingMode(input.offerPricingMode) === 'gbp_vat_then_profit') {
    const vatRate = toNumberSafe(input.vatRate);
    const markedGbp =
      Math.round(input.priceGbp * (1 + vatRate / 100) * (1 + profitRate / 100) * 100) / 100;
    return roundBdtUpToZeroOrFive(Math.ceil(markedGbp * input.conversionRate - 1e-9));
  }
  const costBdt = getUnitCostBdt(input);
  return roundBdtUpToZeroOrFive(costBdt + (costBdt * profitRate) / 100);
};

export const normalizeOfferPriceBdt = (value: unknown) => {
  const num = toNumberSafe(value);
  return num > 0 ? roundBdtUpToZeroOrFive(num) : 0;
};

/** Markup on unit cost from achieved profit (offer − cost), not the file profit input. */
export const computeProfitRatePercentOnCost = (
  costBdt: number,
  profitPerUnitBdt: number,
) => {
  if (costBdt <= 0) return 0;
  return (profitPerUnitBdt / costBdt) * 100;
};
