import {
  globalShipmentRepository,
  type GlobalShipment,
  type GlobalShipmentItem,
} from '../repositories/globalShipmentRepository';
import { computePurchasePriceAdjustments } from './purchaseBalance';
import { calculateTransactionRate } from './landedCost';

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
}

/**
 * Distributes saved purchase invoice total across line purchase_price values.
 */
export async function applyShipmentPurchaseBalance(
  shipmentId: number,
  preload?: ApplyPurchaseBalancePreload,
): Promise<ApplyPurchaseBalanceResult> {
  const shipment = preload?.shipment ?? (await globalShipmentRepository.getById(shipmentId));
  const items = preload?.items ?? (await globalShipmentRepository.listShipmentItems(shipmentId));

  const actualTotal = shipment.purchase_invoice_total || 0;
  if (actualTotal <= 0) {
    throw new Error('Purchase Invoice Total must be saved before applying purchase balance.');
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

  const updatedItems = items.map((item) => {
    const adj = adjustments.find((a) => a.itemId === item.id);
    return adj ? { ...item, purchase_price: adj.newPurchasePrice } : item;
  });

  let transactionRate: number | null = null;
  if (shipment.type === 'international') {
    transactionRate = calculateTransactionRate(
      {
        type: shipment.type,
        product_conversion_rate: shipment.product_conversion_rate,
        cargo_conversion_rate: shipment.cargo_conversion_rate,
        cargo_rate: shipment.cargo_rate,
        received_weight: shipment.received_weight,
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

  const rpcResult = await globalShipmentRepository.applyPurchaseBalance(
    shipmentId,
    adjustments.map((adj) => ({
      item_id: adj.itemId,
      purchase_price: adj.newPurchasePrice,
    })),
    transactionRate,
  );

  return {
    estimatedTotal: rpcResult.estimated_total,
    actualTotal: rpcResult.actual_total,
    deltaTotal: rpcResult.delta_total,
    adjustments,
  };
}
