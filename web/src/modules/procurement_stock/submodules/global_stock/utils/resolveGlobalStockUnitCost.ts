import type { GlobalStockCostingInput } from '../types';
import {
  calculateLineLandedCostBdt,
  buildShipmentForLiveCosting,
  type CostingLineItemInput,
  type CostingShipmentInput,
} from 'src/shared/shipment-engine';
import type { ShipmentItemsCostingCache } from '../composables/useShipmentItemsCostingCache';

export const roundUnitCost = (value: number): number =>
  Math.round((value + Number.EPSILON) * 100) / 100;

export const toCostingShipmentInput = (line: GlobalStockCostingInput): CostingShipmentInput => ({
  type: line.shipment_type,
  received_weight: line.received_weight ?? null,
});

export const toCostingLineItemInput = (line: GlobalStockCostingInput): CostingLineItemInput => ({
  purchase_price: line.purchase_price,
  product_weight: line.product_weight,
  package_weight: line.package_weight,
  ordered_quantity: line.ordered_quantity,
});

export const isGlobalStockCostingInput = (
  row: Partial<GlobalStockCostingInput>,
): row is GlobalStockCostingInput =>
  typeof row.shipment_id === 'number' &&
  row.shipment_id > 0 &&
  typeof row.shipment_item_id === 'number' &&
  typeof row.ordered_quantity === 'number' &&
  typeof row.purchase_price === 'number' &&
  typeof row.product_weight === 'number' &&
  typeof row.package_weight === 'number' &&
  (row.shipment_type === 'local' ||
    row.shipment_type === 'international' ||
    row.shipment_type === 'transfer');

const resolveStamp = (
  line: GlobalStockCostingInput,
  shipmentItems: Array<CostingLineItemInput & { id?: number; landed_cost_bdt?: number | null }>,
): number | null => {
  if (line.landed_cost_bdt != null && Number.isFinite(Number(line.landed_cost_bdt))) {
    return Number(line.landed_cost_bdt);
  }
  const match = shipmentItems.find((i) => i.id === line.shipment_item_id);
  if (match?.landed_cost_bdt != null && Number.isFinite(Number(match.landed_cost_bdt))) {
    return Number(match.landed_cost_bdt);
  }
  return null;
};

/**
 * Unit cost for sell / pick / display.
 * Prefer living stamp (`landed_cost_bdt`); live header-rate recompute only when unstamped (draft).
 */
export function resolveGlobalStockUnitCostSync(
  line: GlobalStockCostingInput,
  shipmentItems: Array<CostingLineItemInput & { id?: number; landed_cost_bdt?: number | null }>,
): number {
  const stamp = resolveStamp(line, shipmentItems);
  if (stamp != null) {
    return stamp;
  }

  const shipmentInput = toCostingShipmentInput(line);
  const effectiveShipment =
    shipmentItems.length > 0
      ? buildShipmentForLiveCosting(shipmentInput, shipmentItems)
      : shipmentInput;

  return calculateLineLandedCostBdt(
    toCostingLineItemInput(line),
    effectiveShipment,
    shipmentItems.length > 0 ? shipmentItems : undefined,
  );
}

export async function resolveGlobalStockUnitCost(
  line: GlobalStockCostingInput,
  cache: ShipmentItemsCostingCache,
): Promise<number> {
  const items = await cache.ensureShipmentItems(line.shipment_id);
  return resolveGlobalStockUnitCostSync(line, items);
}
