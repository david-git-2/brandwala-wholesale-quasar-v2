import { computed, type Ref } from 'vue';
import type { ProductBasedCostingItem } from '../types';
import {
  calculateOfferPriceBdt,
  getUnitCostBdt,
  normalizeOfferPriceBdt,
  toNumberSafe,
} from '../utils/pricing';

export type PbcFileSummaryMetrics = {
  lineCount: number;
  totalQuantity: number;
  goodsCostGbp: number;
  goodsCostBdt: number;
  cargoWeightKg: number;
  cargoCostGbp: number;
  cargoCostBdt: number;
  totalCostGbp: number;
  totalCostBdt: number;
  totalOfferPriceBdt: number;
  totalProfitBdt: number;
  profitMarginPercent: number;
  avgOfferPerUnitBdt: number;
  avgCostPerUnitBdt: number;
  incompleteLineCount: number;
};

type RatesInput = {
  cargoRate: number;
  conversionRate: number;
  profitRate: number;
};

function resolveOfferPriceBdt(
  item: ProductBasedCostingItem,
  rates: RatesInput,
): number {
  const priceGbp = toNumberSafe(item.price_gbp);
  const productWeight = toNumberSafe(item.product_weight);
  const packageWeight = toNumberSafe(item.package_weight);

  if (item.is_offer_price_manual && item.offer_price != null) {
    return normalizeOfferPriceBdt(item.offer_price);
  }

  if (item.offer_price != null && toNumberSafe(item.offer_price) > 0) {
    const calculated = calculateOfferPriceBdt({
      priceGbp,
      productWeight,
      packageWeight,
      cargoRate: rates.cargoRate,
      conversionRate: rates.conversionRate,
      profitRate: rates.profitRate,
    });
    const stored = normalizeOfferPriceBdt(item.offer_price);
    if (stored !== calculated) {
      return stored;
    }
  }

  return calculateOfferPriceBdt({
    priceGbp,
    productWeight,
    packageWeight,
    cargoRate: rates.cargoRate,
    conversionRate: rates.conversionRate,
    profitRate: rates.profitRate,
  });
}

function isLineIncomplete(item: ProductBasedCostingItem): boolean {
  const qty = toNumberSafe(item.quantity);
  if (qty <= 0) return false;
  return (
    toNumberSafe(item.price_gbp) <= 0 ||
    (toNumberSafe(item.product_weight) <= 0 && toNumberSafe(item.package_weight) <= 0)
  );
}

export function computePbcFileSummaryMetrics(
  items: ProductBasedCostingItem[],
  rates: RatesInput,
): PbcFileSummaryMetrics {
  let totalQuantity = 0;
  let goodsCostGbp = 0;
  let cargoWeightGrams = 0;
  let cargoCostGbp = 0;
  let totalCostBdt = 0;
  let totalOfferPriceBdt = 0;
  let incompleteLineCount = 0;

  for (const item of items) {
    const qty = toNumberSafe(item.quantity);
    if (qty <= 0) continue;

    const priceGbp = toNumberSafe(item.price_gbp);
    const productWeight = toNumberSafe(item.product_weight);
    const packageWeight = toNumberSafe(item.package_weight);
    const totalWtPerUnit = productWeight + packageWeight;

    if (isLineIncomplete(item)) {
      incompleteLineCount += 1;
    }

    totalQuantity += qty;
    goodsCostGbp += priceGbp * qty;
    cargoWeightGrams += totalWtPerUnit * qty;
    cargoCostGbp += ((totalWtPerUnit / 1000) * rates.cargoRate) * qty;

    const unitCostBdt = getUnitCostBdt({
      priceGbp,
      productWeight,
      packageWeight,
      cargoRate: rates.cargoRate,
      conversionRate: rates.conversionRate,
    });
    totalCostBdt += unitCostBdt * qty;

    const offerPerUnit = resolveOfferPriceBdt(item, rates);
    totalOfferPriceBdt += offerPerUnit * qty;
  }

  const cargoWeightKg = cargoWeightGrams / 1000;
  const goodsCostBdt = goodsCostGbp * rates.conversionRate;
  const cargoCostBdt = cargoCostGbp * rates.conversionRate;
  const totalCostGbp = goodsCostGbp + cargoCostGbp;
  const totalProfitBdt = totalOfferPriceBdt - totalCostBdt;
  const profitMarginPercent =
    totalOfferPriceBdt > 0 ? (totalProfitBdt / totalOfferPriceBdt) * 100 : 0;

  return {
    lineCount: items.length,
    totalQuantity,
    goodsCostGbp,
    goodsCostBdt,
    cargoWeightKg,
    cargoCostGbp,
    cargoCostBdt,
    totalCostGbp,
    totalCostBdt,
    totalOfferPriceBdt,
    totalProfitBdt,
    profitMarginPercent,
    avgOfferPerUnitBdt: totalQuantity > 0 ? totalOfferPriceBdt / totalQuantity : 0,
    avgCostPerUnitBdt: totalQuantity > 0 ? totalCostBdt / totalQuantity : 0,
    incompleteLineCount,
  };
}

export function usePbcFileSummaryMetrics(
  items: Ref<ProductBasedCostingItem[]>,
  rates: Ref<RatesInput>,
) {
  const summaryMetrics = computed(() =>
    computePbcFileSummaryMetrics(items.value, rates.value),
  );

  return { summaryMetrics };
}

export type PbcFileSummaryRpcRow = {
  line_count?: number | null;
  total_quantity?: number | string | null;
  goods_cost_gbp?: number | string | null;
  goods_cost_bdt?: number | string | null;
  cargo_weight_kg?: number | string | null;
  cargo_cost_gbp?: number | string | null;
  cargo_cost_bdt?: number | string | null;
  total_cost_gbp?: number | string | null;
  total_cost_bdt?: number | string | null;
  total_offer_price_bdt?: number | string | null;
  total_profit_bdt?: number | string | null;
  profit_margin_percent?: number | string | null;
  avg_offer_per_unit_bdt?: number | string | null;
  avg_cost_per_unit_bdt?: number | string | null;
  incomplete_line_count?: number | null;
};

const toMetricNumber = (value: number | string | null | undefined) => {
  const num = Number(value ?? 0);
  return Number.isFinite(num) ? num : 0;
};

export const emptyPbcFileSummaryMetrics = (): PbcFileSummaryMetrics => ({
  lineCount: 0,
  totalQuantity: 0,
  goodsCostGbp: 0,
  goodsCostBdt: 0,
  cargoWeightKg: 0,
  cargoCostGbp: 0,
  cargoCostBdt: 0,
  totalCostGbp: 0,
  totalCostBdt: 0,
  totalOfferPriceBdt: 0,
  totalProfitBdt: 0,
  profitMarginPercent: 0,
  avgOfferPerUnitBdt: 0,
  avgCostPerUnitBdt: 0,
  incompleteLineCount: 0,
});

export function mapPbcFileSummaryFromRpc(
  row: PbcFileSummaryRpcRow | null | undefined,
): PbcFileSummaryMetrics {
  if (!row) return emptyPbcFileSummaryMetrics();

  return {
    lineCount: Number(row.line_count ?? 0),
    totalQuantity: toMetricNumber(row.total_quantity),
    goodsCostGbp: toMetricNumber(row.goods_cost_gbp),
    goodsCostBdt: toMetricNumber(row.goods_cost_bdt),
    cargoWeightKg: toMetricNumber(row.cargo_weight_kg),
    cargoCostGbp: toMetricNumber(row.cargo_cost_gbp),
    cargoCostBdt: toMetricNumber(row.cargo_cost_bdt),
    totalCostGbp: toMetricNumber(row.total_cost_gbp),
    totalCostBdt: toMetricNumber(row.total_cost_bdt),
    totalOfferPriceBdt: toMetricNumber(row.total_offer_price_bdt),
    totalProfitBdt: toMetricNumber(row.total_profit_bdt),
    profitMarginPercent: toMetricNumber(row.profit_margin_percent),
    avgOfferPerUnitBdt: toMetricNumber(row.avg_offer_per_unit_bdt),
    avgCostPerUnitBdt: toMetricNumber(row.avg_cost_per_unit_bdt),
    incompleteLineCount: Number(row.incomplete_line_count ?? 0),
  };
}
