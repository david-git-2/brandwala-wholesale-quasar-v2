/**
 * @deprecated Import from `src/shared/shipment-engine` instead.
 * Thin re-export for backward compatibility.
 */
export type {
  CostingLineItemInput,
  CostingShipmentInput,
  ShipmentCostSummary,
} from 'src/shared/shipment-engine';

export {
  calculateLineGrossWeightKg,
  calculatePackagingWeightKg,
  getCargoWeightKg,
  calculateLineCargoPurchaseShare,
  calculateLinePurchaseBase,
  calculateRawTransactionRate,
  calculateTransactionRate,
  getCalculatedTransactionRate,
  calculateLineLandedCostBdt,
  buildShipmentForLiveCosting,
  calculateShipmentCostSummary,
} from 'src/shared/shipment-engine';
