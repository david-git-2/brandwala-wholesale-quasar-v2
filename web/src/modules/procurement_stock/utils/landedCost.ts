export interface CostingShipmentInput {
  type: 'domestic' | 'international'
  product_conversion_rate: number
  cargo_conversion_rate: number
  cargo_rate: number
  received_weight: number | null
  transaction_rate: number | null
}

export interface CostingLineItemInput {
  purchase_price: number
  product_weight: number // in grams
  package_weight: number // in grams
  ordered_quantity: number
}

/**
 * Calculates the BDT landed cost for a single line item.
 */
export const calculateLineLandedCostBdt = (
  item: CostingLineItemInput,
  shipment: CostingShipmentInput,
): number => {
  const purchasePrice = item.purchase_price || 0
  const productWeight = item.product_weight || 0
  const packageWeight = item.package_weight || 0
  const cargoRate = shipment.cargo_rate || 0

  // base = purchase_price + ((product_weight + package_weight) / 1000) * cargo_rate
  const weightKg = (productWeight + packageWeight) / 1000
  const base = purchasePrice + weightKg * cargoRate

  if (shipment.type === 'domestic') {
    return base
  }

  // International: base * effective_rate
  const txRate = shipment.transaction_rate
  const effectiveRate =
    txRate !== null && txRate !== undefined && txRate > 0
      ? txRate
      : ((shipment.product_conversion_rate || 1) + (shipment.cargo_conversion_rate || 1)) / 2

  return base * effectiveRate
}

/**
 * Computes the transaction rate for an international shipment.
 */
export const calculateTransactionRate = (
  shipment: CostingShipmentInput,
  items: CostingLineItemInput[],
): number | null => {
  if (shipment.type === 'domestic') {
    return null
  }

  const productConv = shipment.product_conversion_rate || 1.0
  const cargoConv = shipment.cargo_conversion_rate || 1.0
  const receivedWeight = shipment.received_weight || 0
  const cargoRate = shipment.cargo_rate || 0

  let goodsPurchase = 0
  for (const item of items) {
    goodsPurchase += (item.purchase_price || 0) * (item.ordered_quantity || 0)
  }

  const goodsBdt = goodsPurchase * productConv
  const cargoPurchase = receivedWeight * cargoRate
  const cargoBdt = cargoPurchase * cargoConv

  const denominator = goodsPurchase + cargoPurchase
  if (denominator > 0) {
    return (goodsBdt + cargoBdt) / denominator
  }

  return (productConv + cargoConv) / 2
}
