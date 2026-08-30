/**
 * @deprecated Prefer `src/shared/shipment-engine` for pure cost compute.
 * Thin adapter: re-exports entry helpers + shipment domain flags.
 */
export {
  effectiveRateForType,
  costingShipmentFromEntries,
  sumEntryAmount,
  sumProductEntryAmount,
  productCostEntries,
} from 'src/shared/shipment-engine';

type ShipmentCostFlags = {
  stock_ready?: boolean | null;
  status?: string | null;
  costs_locked?: boolean | null;
};

/** Stock posted to warehouse (receive complete). */
export function isShipmentStockPosted(shipment: ShipmentCostFlags): boolean {
  return shipment.stock_ready === true || shipment.status === 'received';
}

/** Books frozen — no further cost/weight/rate edits. */
export function isShipmentCostsLocked(shipment: ShipmentCostFlags): boolean {
  return shipment.costs_locked === true;
}

/** @deprecated Use isShipmentStockPosted */
export function isShipmentCostFinalized(shipment: ShipmentCostFlags): boolean {
  return isShipmentStockPosted(shipment);
}
