import type { CostingTotalsSummary } from 'src/types/costingTotalsSummary';
import type { PbcFileSummaryMetrics } from '../composables/usePbcFileSummaryMetrics';

function marginOnLandedCost(offerTotal: number, landedSellTotal: number): number {
  if (landedSellTotal <= 0) return 0;
  return ((offerTotal - landedSellTotal) / landedSellTotal) * 100;
}

export function mapPbcSummaryToCostingTotals(metrics: PbcFileSummaryMetrics): CostingTotalsSummary {
  const landedSell = metrics.totalCostBdt;
  const finalOffer = metrics.totalOfferPriceBdt;
  const margin = marginOnLandedCost(finalOffer, landedSell);

  return {
    totalQuantity: metrics.totalQuantity,
    totalWeightGm: metrics.cargoWeightKg * 1000,
    grandTotalPurchasePrice: metrics.goodsCostGbp,
    grandTotalCargoPurchase: metrics.cargoCostGbp,
    grandTotalLandedPurchase: metrics.totalCostGbp,
    grandTotalLandedSell: landedSell,
    grandTotalFirstOffer: 0,
    overallFirstOfferMargin: 0,
    grandTotalCounterOffer: 0,
    overallCounterOfferMargin: 0,
    grandTotalFinalOffer: finalOffer,
    overallFinalOfferMargin: margin,
  };
}