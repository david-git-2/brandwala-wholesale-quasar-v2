import type { GlobalStockCostingInput } from '../types';
import {
  calculateLineLandedCostBdt,
  buildShipmentForLiveCosting,
  type CostingLineItemInput,
  type CostingShipmentInput,
} from 'src/modules/procurement_stock/utils/landedCost';
import type { ShipmentItemsCostingCache } from '../composables/useShipmentItemsCostingCache';

export const roundUnitCost = (value: number): number =>
  Math.round((value + Number.EPSILON) * 100) / 100;

export const toCostingShipmentInput = (line: GlobalStockCostingInput): CostingShipmentInput => ({
  type: line.shipment_type,
  product_conversion_rate: line.product_conversion_rate,
  cargo_conversion_rate: line.cargo_conversion_rate,
  cargo_rate: line.cargo_rate,
  received_weight: line.received_weight,
  transaction_rate: line.transaction_rate,
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
  (row.shipment_type === 'domestic' || row.shipment_type === 'international');

export function resolveGlobalStockUnitCostSync(
  line: GlobalStockCostingInput,
  shipmentItems: CostingLineItemInput[],
): number {
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
