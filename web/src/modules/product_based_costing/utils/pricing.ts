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

/** Web £ unit price after VAT (VAT-then-£ mode). Rounded to 2 dp. */
export const getPriceGbpWithVat = (webPriceGbp: number, vatRate: number) => {
  const webGbp = toNumberSafe(webPriceGbp);
  const vat = toNumberSafe(vatRate);
  return Math.round(webGbp * (1 + vat / 100) * 100) / 100;
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
  const profitRate = toNumberSafe(input.profitRate);
  const vatRate = toNumberSafe(input.vatRate);
  const webGbp = toNumberSafe(input.priceGbp);
  const priceGbp =
    normalizeOfferPricingMode(input.offerPricingMode) === 'gbp_vat_then_profit'
      ? getPriceGbpWithVat(webGbp, vatRate)
      : webGbp;
  const costBdt = getUnitCostBdt({
    priceGbp,
    productWeight: toNumberSafe(input.productWeight),
    packageWeight: toNumberSafe(input.packageWeight),
    cargoRate: toNumberSafe(input.cargoRate),
    conversionRate: toNumberSafe(input.conversionRate),
  });
  return roundBdtUpToZeroOrFive(costBdt + (costBdt * profitRate) / 100);
};

export const normalizeOfferPriceBdt = (value: unknown) => {
  const num = toNumberSafe(value);
  return num > 0 ? roundBdtUpToZeroOrFive(num) : 0;
};

/** Auto lines follow the file offer mode. Only locked rows keep stored offer. */
export const resolveEffectiveOfferPriceBdt = (
  item: { offer_price?: number | null; is_offer_price_manual?: boolean | null },
  input: OfferPriceInput,
) => {
  if (item.is_offer_price_manual === true && item.offer_price != null) {
    return normalizeOfferPriceBdt(item.offer_price);
  }
  return calculateOfferPriceBdt(input);
};

/** Markup on unit cost from achieved profit (offer − cost), not the file profit input. */
export const computeProfitRatePercentOnCost = (
  costBdt: number,
  profitPerUnitBdt: number,
) => {
  if (costBdt <= 0) return 0;
  return (profitPerUnitBdt / costBdt) * 100;
};
