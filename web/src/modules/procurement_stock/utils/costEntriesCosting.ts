/**
 * @deprecated Prefer `src/shared/shipment-engine` for pure cost compute.
 * Thin adapter: re-exports entry helpers + shipment finalize domain flag.
 */
export {
  effectiveRateForType,
  costingShipmentFromEntries,
  sumEntryAmount,
  sumProductEntryAmount,
  productCostEntries,
} from 'src/shared/shipment-engine';

/** Domain flag — not part of pure cost math. */
export function isShipmentCostFinalized(shipment: {
  stock_ready?: boolean | null;
}): boolean {
  return shipment.stock_ready === true;
}
