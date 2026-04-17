import { roundBdtUpToZeroOrFive } from 'src/modules/costingFile/utils/costingCalculations'

type OfferPriceInput = {
  priceGbp: number
  productWeight: number
  packageWeight: number
  cargoRate: number
  conversionRate: number
  profitRate: number
}

export const toNumberSafe = (value: unknown) => {
  const normalized =
    typeof value === 'string'
      ? value.replace(/,/g, '').replace(/[^\d.-]/g, '').trim()
      : value
  const num = Number(normalized ?? 0)
  return Number.isNaN(num) ? 0 : num
}

export const getUnitTotalCostGbp = ({
  priceGbp,
  productWeight,
  packageWeight,
  cargoRate,
}: Pick<OfferPriceInput, 'priceGbp' | 'productWeight' | 'packageWeight' | 'cargoRate'>) => {
  const cargoCostGbp = ((productWeight + packageWeight) / 1000) * cargoRate
  return priceGbp + cargoCostGbp
}

export const getUnitCostBdt = (
  input: Pick<OfferPriceInput, 'priceGbp' | 'productWeight' | 'packageWeight' | 'cargoRate' | 'conversionRate'>,
) =>
  Math.ceil(getUnitTotalCostGbp(input) * input.conversionRate)

export const calculateOfferPriceBdt = (input: OfferPriceInput) => {
  const costBdt = getUnitCostBdt(input)
  return roundBdtUpToZeroOrFive(costBdt + (costBdt * input.profitRate) / 100)
}

export const normalizeOfferPriceBdt = (value: unknown) => {
  const num = toNumberSafe(value)
  return num > 0 ? roundBdtUpToZeroOrFive(num) : 0
}
