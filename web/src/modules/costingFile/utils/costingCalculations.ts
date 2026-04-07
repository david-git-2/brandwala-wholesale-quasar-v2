export type CostingFileCalculationInput = {
  cargoRate1Kg: number | null | undefined
  cargoRate2Kg: number | null | undefined
  conversionRate: number | null | undefined
  adminProfitRate: number | null | undefined
  offerPriceOverrideBdt?: number | null | undefined
}

export type CostingItemCalculationInput = {
  itemType: string | null | undefined
  productWeight: number | null | undefined
  packageWeight: number | null | undefined
  priceInWebGbp: number | null | undefined
  deliveryPriceGbp: number | null | undefined
  customerProfitRate: number | null | undefined
}

const toSafeNumber = (value: number | null | undefined) => Number(value ?? 0)

export const roundGbp = (value: number) => Number(toSafeNumber(value).toFixed(2))

export const roundBdtUpToZeroOrFive = (value: number) => {
  const roundedUp = Math.ceil(toSafeNumber(value))
  const remainder = roundedUp % 5

  if (remainder === 0) {
    return roundedUp
  }

  return roundedUp + (5 - remainder)
}

export const calculateTotalWeight = (
  productWeight: number | null | undefined,
  packageWeight: number | null | undefined,
) => Math.max(0, Math.trunc(toSafeNumber(productWeight)) + Math.trunc(toSafeNumber(packageWeight)))

export const calculateAuxiliaryPriceGbp = (
  priceInWebGbp: number | null | undefined,
  deliveryPriceGbp: number | null | undefined,
) => {
  const basePriceGbp = roundGbp(toSafeNumber(priceInWebGbp) + toSafeNumber(deliveryPriceGbp))

  if (basePriceGbp <= 10) {
    return 0
  }

  if (basePriceGbp <= 100) {
    return 2
  }

  return roundGbp(2 + Math.ceil((basePriceGbp - 100) / 50))
}

export const calculateItemTypeSurchargeGbp = (itemType: string | null | undefined) => {
  const normalizedType = itemType?.trim().toLowerCase()
  return normalizedType === 'watch' || normalizedType === 'perfume' ? 3 : 0
}

export const calculateItemPriceGbp = (
  priceInWebGbp: number | null | undefined,
  deliveryPriceGbp: number | null | undefined,
  auxiliaryPriceGbp: number | null | undefined,
) => roundGbp(toSafeNumber(priceInWebGbp) + toSafeNumber(deliveryPriceGbp) + toSafeNumber(auxiliaryPriceGbp))

export const selectCargoRate = (
  itemPriceGbp: number | null | undefined,
  cargoRate1Kg: number | null | undefined,
  cargoRate2Kg: number | null | undefined,
) => {
  const normalizedItemPrice = toSafeNumber(itemPriceGbp)
  const selectedRate = normalizedItemPrice > 10 ? cargoRate2Kg : cargoRate1Kg

  return roundGbp(toSafeNumber(selectedRate))
}

export const calculateCostingPriceGbp = (
  itemPriceGbp: number | null | undefined,
  totalWeight: number | null | undefined,
  cargoRate: number | null | undefined,
) => roundGbp(toSafeNumber(itemPriceGbp) + (toSafeNumber(totalWeight) / 1000) * toSafeNumber(cargoRate))

export const calculateCostingPriceBdt = (
  costingPriceGbp: number | null | undefined,
  conversionRate: number | null | undefined,
) => roundBdtUpToZeroOrFive(toSafeNumber(costingPriceGbp) * toSafeNumber(conversionRate))

export const calculateOfferPriceBdt = (
  costingPriceBdt: number | null | undefined,
  adminProfitRate: number | null | undefined,
) =>
  roundBdtUpToZeroOrFive(
    toSafeNumber(costingPriceBdt) +
      (toSafeNumber(costingPriceBdt) * toSafeNumber(adminProfitRate)) / 100,
  )

export const calculateBuyerSellPrice = (
  offerPriceBdt: number | null | undefined,
  customerProfitRate: number | null | undefined,
) =>
  roundBdtUpToZeroOrFive(
    toSafeNumber(offerPriceBdt) +
      (toSafeNumber(offerPriceBdt) * toSafeNumber(customerProfitRate)) / 100,
  )

export const calculateCostingItem = (
  file: CostingFileCalculationInput,
  item: CostingItemCalculationInput,
) => {
  const totalWeight = calculateTotalWeight(item.productWeight, item.packageWeight)
  const auxiliaryPriceGbp = roundGbp(
    calculateAuxiliaryPriceGbp(item.priceInWebGbp, item.deliveryPriceGbp) +
      calculateItemTypeSurchargeGbp(item.itemType),
  )
  const itemPriceGbp = calculateItemPriceGbp(
    item.priceInWebGbp,
    item.deliveryPriceGbp,
    auxiliaryPriceGbp,
  )
  const cargoRate = selectCargoRate(itemPriceGbp, file.cargoRate1Kg, file.cargoRate2Kg)
  const costingPriceGbp = calculateCostingPriceGbp(itemPriceGbp, totalWeight, cargoRate)
  const costingPriceBdt = calculateCostingPriceBdt(costingPriceGbp, file.conversionRate)
  const calculatedOfferPriceBdt = calculateOfferPriceBdt(costingPriceBdt, file.adminProfitRate)
  const offerPriceBdt =
    file.offerPriceOverrideBdt == null ? calculatedOfferPriceBdt : toSafeNumber(file.offerPriceOverrideBdt)
  const buyerSellPrice = calculateBuyerSellPrice(offerPriceBdt, item.customerProfitRate)

  return {
    totalWeight,
    auxiliaryPriceGbp,
    itemPriceGbp,
    cargoRate,
    costingPriceGbp,
    costingPriceBdt,
    calculatedOfferPriceBdt,
    offerPriceBdt,
    buyerSellPrice,
  }
}
