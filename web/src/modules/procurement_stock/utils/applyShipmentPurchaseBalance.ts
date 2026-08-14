import {
  globalShipmentRepository,
  type GlobalShipment,
  type GlobalShipmentItem,
} from '../repositories/globalShipmentRepository';
import { globalShipmentCostEntryRepository } from '../repositories/globalShipmentCostEntryRepository';
import { computePurchasePriceAdjustments } from './purchaseBalance';
import { sumProductEntryAmount } from 'src/shared/shipment-engine';
import type { GlobalShipmentCostEntry } from '../types/shipmentCostEntry';

export interface ApplyPurchaseBalanceResult {
  estimatedTotal: number;
  actualTotal: number;
  deltaTotal: number;
  adjustments: {
    itemId: number;
    newPurchasePrice: number;
    perUnitDelta: number;
  }[];
}

export interface ApplyPurchaseBalancePreload {
  shipment: GlobalShipment;
  items: GlobalShipmentItem[];
  costEntries?: GlobalShipmentCostEntry[];
}

/**
 * Distributes Σ(product cost-entry amounts) across line purchase_price values.
 * Does not write header FX / transaction_rate.
 */
export async function applyShipmentPurchaseBalance(
  shipmentId: number,
  preload?: ApplyPurchaseBalancePreload,
): Promise<ApplyPurchaseBalanceResult> {
  const shipment = preload?.shipment ?? (await globalShipmentRepository.getById(shipmentId));
  const items = preload?.items ?? (await globalShipmentRepository.listShipmentItems(shipmentId));

  let entries = preload?.costEntries;
  if (!entries) {
    await globalShipmentCostEntryRepository.ensureFromHeader(shipmentId);
    entries = await globalShipmentCostEntryRepository.listByShipmentId(shipmentId);
  }

  const actualTotal = sumProductEntryAmount(entries);
  if (actualTotal <= 0) {
    throw new Error(
      'Product cost entry amount must be saved (Match invoices / Landed cost) before applying purchase balance.',
    );
  }

  const adjustments = computePurchasePriceAdjustments(
    items.map((item) => ({
      id: item.id,
      name: item.name,
      purchase_price: item.purchase_price,
      ordered_quantity: item.ordered_quantity,
    })),
    actualTotal,
  );

  const rpcResult = await globalShipmentRepository.applyPurchaseBalance(
    shipmentId,
    adjustments.map((adj) => ({
      item_id: adj.itemId,
      purchase_price: adj.newPurchasePrice,
    })),
  );

  return {
    estimatedTotal: rpcResult.estimated_total,
    actualTotal: rpcResult.actual_total,
    deltaTotal: rpcResult.delta_total,
    adjustments,
  };
}
