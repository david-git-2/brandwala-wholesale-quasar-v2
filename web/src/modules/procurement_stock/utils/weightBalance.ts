export interface WeightBalanceItemInput {
  id: number
  name: string
  product_weight: number // grams
  package_weight: number // grams
  ordered_quantity: number
}

export interface WeightBalanceBoxInput {
  weight_kg: number
}

export interface WeightAdjustmentResult {
  itemId: number
  newPackageWeight: number // in grams, rounded to 3 decimal places
  perUnitDelta: number // in grams
}

/**
 * Calculates estimated weight in kg from shipment line items.
 */
export function calculateEstimatedWeightKg(items: WeightBalanceItemInput[]): number {
  let totalGm = 0
  for (const item of items) {
    const qty = item.ordered_quantity || 0
    totalGm += ((item.product_weight || 0) + (item.package_weight || 0)) * qty
  }
  return totalGm / 1000
}

/**
 * Calculates actual weight in kg from physical boxes.
 */
export function calculateActualWeightKg(boxes: WeightBalanceBoxInput[]): number {
  return boxes.reduce((sum, box) => sum + (box.weight_kg || 0), 0)
}

/**
 * Computes proportional package weight adjustments to distribute the estimated-vs-actual delta.
 */
export function computePackageWeightAdjustments(
  items: WeightBalanceItemInput[],
  actualTotalKg: number,
): WeightAdjustmentResult[] {
  // 1. Validation before computing
  if (items.length === 0) {
    throw new Error('At least one shipment line item is required to perform weight balance.')
  }

  const hasPositiveQtyItem = items.some((item) => (item.ordered_quantity || 0) > 0)
  if (!hasPositiveQtyItem) {
    throw new Error('At least one shipment line must have an ordered quantity greater than 0.')
  }

  // Calculate estimated total grams
  const estimatedTotalGm = items.reduce(
    (sum, item) => sum + ((item.product_weight || 0) + (item.package_weight || 0)) * (item.ordered_quantity || 0),
    0,
  )

  const actualTotalGm = actualTotalKg * 1000
  const deltaGm = actualTotalGm - estimatedTotalGm

  // Guard: If estimated is 0 and delta is not 0
  if (estimatedTotalGm === 0) {
    if (deltaGm !== 0) {
      throw new Error('no weight basis to distribute')
    }
    // If both are 0, no adjustments needed
    return items.map((item) => ({
      itemId: item.id,
      newPackageWeight: item.package_weight,
      perUnitDelta: 0,
    }))
  }

  // Prepare tracking variables
  const adjustmentsMap = new Map<number, {
    newWeightRaw: number
    newWeightRounded: number
    grossWeight: number
    qty: number
    originalPackageWeight: number
  }>()

  let sumAdjustedGm = 0
  let maxGrossWeight = -1
  let maxGrossWeightItemId = -1

  for (const item of items) {
    const qty = item.ordered_quantity || 0
    const currentGross = ((item.product_weight || 0) + (item.package_weight || 0)) * qty

    // Keep track of the item with the largest gross weight
    if (currentGross > maxGrossWeight) {
      maxGrossWeight = currentGross
      maxGrossWeightItemId = item.id
    }

    if (qty === 0) {
      adjustmentsMap.set(item.id, {
        newWeightRaw: item.package_weight,
        newWeightRounded: item.package_weight,
        grossWeight: 0,
        qty: 0,
        originalPackageWeight: item.package_weight,
      })
      continue
    }

    const share = currentGross / estimatedTotalGm
    const lineDeltaGm = deltaGm * share
    const perUnitDelta = lineDeltaGm / qty
    const newWeightRaw = item.package_weight + perUnitDelta

    // Validate that line would not go below 0
    if (newWeightRaw < 0) {
      throw new Error(
        `Package weight for line "${item.name}" would go below 0 after adjustment (${newWeightRaw.toFixed(3)}g). Adjustments blocked.`,
      )
    }

    const newWeightRounded = Math.round(newWeightRaw * 1000) / 1000
    sumAdjustedGm += (newWeightRounded - item.package_weight) * qty

    adjustmentsMap.set(item.id, {
      newWeightRaw,
      newWeightRounded,
      grossWeight: currentGross,
      qty,
      originalPackageWeight: item.package_weight,
    })
  }

  // Handle rounding remainder by assigning to the item with the largest gross weight
  const remainderGm = deltaGm - sumAdjustedGm
  if (Math.abs(remainderGm) > 0.00001 && maxGrossWeightItemId !== -1) {
    const target = adjustmentsMap.get(maxGrossWeightItemId)
    if (target && target.qty > 0) {
      const additionalPerUnit = remainderGm / target.qty
      const adjustedWeightRaw = target.newWeightRounded + additionalPerUnit
      
      if (adjustedWeightRaw < 0) {
        throw new Error(
          `Package weight for line "${items.find(i => i.id === maxGrossWeightItemId)?.name}" would go below 0 after remainder distribution (${adjustedWeightRaw.toFixed(3)}g). Adjustments blocked.`,
        )
      }
      
      target.newWeightRounded = Math.round(adjustedWeightRaw * 1000) / 1000
      adjustmentsMap.set(maxGrossWeightItemId, target)
    }
  }

  // Construct final result list
  return items.map((item) => {
    const data = adjustmentsMap.get(item.id)!
    return {
      itemId: item.id,
      newPackageWeight: data.newWeightRounded,
      perUnitDelta: data.newWeightRounded - data.originalPackageWeight,
    }
  })
}
