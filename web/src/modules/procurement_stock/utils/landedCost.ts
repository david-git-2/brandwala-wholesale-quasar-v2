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
  items?: CostingLineItemInput[],
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
  const txRate = (items && items.length > 0)
    ? getCalculatedTransactionRate(shipment, items)
    : shipment.transaction_rate

  const effectiveRate =
    txRate !== null && txRate !== undefined && txRate > 0
      ? txRate
      : ((shipment.product_conversion_rate || 1) + (shipment.cargo_conversion_rate || 1)) / 2

  return base * effectiveRate
}

/**
 * Calculates total packaging weight in kg from item list.
 */
export const calculatePackagingWeightKg = (items: CostingLineItemInput[]): number => {
  let weight = 0
  for (const item of items) {
    weight += ((item.product_weight || 0) + (item.package_weight || 0)) * (item.ordered_quantity || 0) / 1000
  }
  return weight
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
  const cargoRate = shipment.cargo_rate || 0
  const cargoWeight = calculatePackagingWeightKg(items)

  let goodsPurchase = 0
  for (const item of items) {
    goodsPurchase += (item.purchase_price || 0) * (item.ordered_quantity || 0)
  }

  const goodsBdt = goodsPurchase * productConv
  const cargoPurchase = cargoWeight * cargoRate
  const cargoBdt = cargoPurchase * cargoConv

  const denominator = goodsPurchase + cargoPurchase
  if (denominator > 0) {
    return (goodsBdt + cargoBdt) / denominator
  }

  return (productConv + cargoConv) / 2
}

/**
 * Thin alias to get calculated transaction rate.
 */
export const getCalculatedTransactionRate = (
  shipment: CostingShipmentInput,
  items: CostingLineItemInput[],
): number | null => {
  return calculateTransactionRate(shipment, items)
}

export interface ShipmentCostSummary {
  quantity: number
  packagingWeightKg: number
  cargoWeightKg: number
  goodsPurchase: number
  cargoPurchase: number
  totalPurchase: number
  goodsCost: number
  cargoCost: number
  totalCost: number
  transactionRate: number | null
  lineLandedCostTotal: number // Σ(unit cost × qty) using live rate
}

/**
 * Calculates the complete shipment costing summary.
 */
export function calculateShipmentCostSummary(
  shipment: CostingShipmentInput,
  items: CostingLineItemInput[],
): ShipmentCostSummary {
  let quantity = 0
  for (const item of items) {
    quantity += item.ordered_quantity || 0
  }

  const packagingWeightKg = calculatePackagingWeightKg(items)
  const cargoWeightKg = packagingWeightKg // ALWAYS packaging/estimated weight for costing

  let goodsPurchase = 0
  for (const item of items) {
    goodsPurchase += (item.purchase_price || 0) * (item.ordered_quantity || 0)
  }

  const cargoPurchase = cargoWeightKg * (shipment.cargo_rate || 0)
  const totalPurchase = goodsPurchase + cargoPurchase

  const goodsCost = shipment.type === 'domestic' ? goodsPurchase : goodsPurchase * (shipment.product_conversion_rate || 1)
  const cargoCost = shipment.type === 'domestic' ? cargoPurchase : cargoPurchase * (shipment.cargo_conversion_rate || 1)
  const totalCost = goodsCost + cargoCost

  const transactionRate = getCalculatedTransactionRate(shipment, items)

  let lineLandedCostTotal = 0
  for (const item of items) {
    const qty = item.ordered_quantity || 0
    lineLandedCostTotal += calculateLineLandedCostBdt(item, shipment, items) * qty
  }

  return {
    quantity,
    packagingWeightKg,
    cargoWeightKg,
    goodsPurchase,
    cargoPurchase,
    totalPurchase,
    goodsCost,
    cargoCost,
    totalCost,
    transactionRate,
    lineLandedCostTotal,
  }
}


