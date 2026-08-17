import {
  globalShipmentRepository,
  type GlobalShipment,
  type GlobalShipmentItem,
} from '../repositories/globalShipmentRepository';
import { computePackageWeightAdjustments } from './weightBalance';

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
 * Does not write header FX / transaction_rate.
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

  const rpcResult = await globalShipmentRepository.applyWeightBalance(
    shipmentId,
    adjustments.map((adj) => ({
      item_id: adj.itemId,
      package_weight: adj.newPackageWeight,
    })),
  );

  return {
    estimatedKg: rpcResult.estimated_kg,
    actualKg: rpcResult.actual_kg,
    deltaKg: rpcResult.delta_kg,
    adjustments,
  };
}
