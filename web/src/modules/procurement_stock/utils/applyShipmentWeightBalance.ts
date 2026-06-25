import { globalShipmentRepository } from '../repositories/globalShipmentRepository'
import { globalShipmentBoxRepository } from '../repositories/globalShipmentBoxRepository'
import { syncShipmentWeightToProduct } from './syncShipmentWeightToProduct'
import {
  computePackageWeightAdjustments,
  calculateEstimatedWeightKg,
  calculateActualWeightKg,
} from './weightBalance'
import { calculateTransactionRate } from './landedCost'

export interface ApplyWeightBalanceResult {
  estimatedKg: number
  actualKg: number
  deltaKg: number
  adjustments: {
    itemId: number
    newPackageWeight: number
    perUnitDelta: number
  }[]
}

/**
 * Orchestrates the weight balance application process.
 * Updates items, syncs matching products, and saves header received_weight and transaction_rate.
 */
export async function applyShipmentWeightBalance(shipmentId: number): Promise<ApplyWeightBalanceResult> {
  // 1. Fetch shipment details, items and boxes
  const shipment = await globalShipmentRepository.getById(shipmentId)
  const items = await globalShipmentRepository.listShipmentItems(shipmentId)
  const boxes = await globalShipmentBoxRepository.listByShipmentId(shipmentId)

  // 2. Compute actual weight
  const actualKg = calculateActualWeightKg(boxes)
  const estimatedKg = calculateEstimatedWeightKg(items)
  const deltaKg = actualKg - estimatedKg

  // 3. Compute adjustments
  const adjustments = computePackageWeightAdjustments(items, actualKg)

  // 4. Sequentially update each item and sync its product
  const updatedItems = [...items]
  for (const adj of adjustments) {
    // Update shipment item
    const updatedItem = await globalShipmentRepository.updateShipmentItem(adj.itemId, {
      package_weight: adj.newPackageWeight,
    })

    // Find and update item in our local copy to use for transaction rate calculation
    const idx = updatedItems.findIndex((item) => item.id === adj.itemId)
    if (idx !== -1) {
      updatedItems[idx] = updatedItem
    }

    // Sync product if linked
    if (updatedItem.product_id) {
      await syncShipmentWeightToProduct(updatedItem.product_id, 'package_weight', adj.newPackageWeight)
    }
  }

  // 5. Build shipment patch
  const patch: Parameters<typeof globalShipmentRepository.updateShipment>[1] = {
    received_weight: actualKg,
  }

  // 6. If international, calculate and set transaction_rate
  if (shipment.type === 'international') {
    const shipmentInputForRate = {
      type: shipment.type,
      product_conversion_rate: shipment.product_conversion_rate,
      cargo_conversion_rate: shipment.cargo_conversion_rate,
      cargo_rate: shipment.cargo_rate,
      received_weight: actualKg,
      transaction_rate: shipment.transaction_rate,
    }

    const itemsInputForRate = updatedItems.map((item) => ({
      purchase_price: item.purchase_price,
      product_weight: item.product_weight,
      package_weight: item.package_weight,
      ordered_quantity: item.ordered_quantity,
    }))

    const newTxRate = calculateTransactionRate(shipmentInputForRate, itemsInputForRate)
    patch.transaction_rate = newTxRate
  }

  // 7. Update shipment header
  await globalShipmentRepository.updateShipment(shipmentId, patch)

  return {
    estimatedKg,
    actualKg,
    deltaKg,
    adjustments,
  }
}
