import {
  globalShipmentRepository,
  type GlobalShipment,
  type GlobalShipmentItem,
} from '../repositories/globalShipmentRepository';
import { computePackageWeightAdjustments } from './weightBalance';
import { calculateTransactionRate } from './landedCost';

export interface ApplyWeightBalanceResult {
  estimatedKg: number;
  actualKg: number;
  deltaKg: number;
  adjustments: {
    itemId: number;
    newPackageWeight: number;
    perUnitDelta: number;
  }[];
}

export interface ApplyWeightBalancePreload {
  shipment: GlobalShipment;
  items: GlobalShipmentItem[];
}

/**
 * Distributes saved cargo invoice weight across line package_weight values.
 * Does not modify received_weight — that is set only via explicit save on the UI.
 */
export async function applyShipmentWeightBalance(
  shipmentId: number,
  preload?: ApplyWeightBalancePreload,
): Promise<ApplyWeightBalanceResult> {
  const shipment = preload?.shipment ?? (await globalShipmentRepository.getById(shipmentId));
  const items = preload?.items ?? (await globalShipmentRepository.listShipmentItems(shipmentId));

  const actualKg = Math.round((shipment.received_weight || 0) * 100) / 100;
  if (actualKg <= 0) {
    throw new Error('Cargo Invoice Weight must be saved before applying weight balance.');
  }

  const adjustments = computePackageWeightAdjustments(items, actualKg);

  const updatedItems = items.map((item) => {
    const adj = adjustments.find((a) => a.itemId === item.id);
    return adj ? { ...item, package_weight: adj.newPackageWeight } : item;
  });

  let transactionRate: number | null = null;
  if (shipment.type === 'international') {
    transactionRate = calculateTransactionRate(
      {
        type: shipment.type,
        product_conversion_rate: shipment.product_conversion_rate,
        cargo_conversion_rate: shipment.cargo_conversion_rate,
        cargo_rate: shipment.cargo_rate,
        received_weight: actualKg,
        transaction_rate: shipment.transaction_rate,
      },
      updatedItems.map((item) => ({
        purchase_price: item.purchase_price,
        product_weight: item.product_weight,
        package_weight: item.package_weight,
        ordered_quantity: item.ordered_quantity,
      })),
    );
  }

  const rpcResult = await globalShipmentRepository.applyWeightBalance(
    shipmentId,
    adjustments.map((adj) => ({
      item_id: adj.itemId,
      package_weight: adj.newPackageWeight,
    })),
    transactionRate,
  );

  return {
    estimatedKg: rpcResult.estimated_kg,
    actualKg: rpcResult.actual_kg,
    deltaKg: rpcResult.delta_kg,
    adjustments,
  };
}
