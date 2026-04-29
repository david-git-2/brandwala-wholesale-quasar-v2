type ShipmentCostInput = {
  productWeight: number | null | undefined
  packageWeight: number | null | undefined
  cargoRate: number | null | undefined
  priceGbp: number | null | undefined
  productConversionRate: number | null | undefined
  cargoConversionRate: number | null | undefined
}

const toNumber = (value: number | null | undefined) => {
  const parsed = Number(value ?? 0)
  return Number.isFinite(parsed) ? parsed : 0
}

export const calculateCostBdt = (input: ShipmentCostInput): number => {
  const productWeight = toNumber(input.productWeight)
  const packageWeight = toNumber(input.packageWeight)
  const cargoRate = toNumber(input.cargoRate)
  const priceGbp = toNumber(input.priceGbp)
  const productConversionRate = toNumber(input.productConversionRate)
  const cargoConversionRate = toNumber(input.cargoConversionRate)

  return (
    (((productWeight + packageWeight) / 1000) * cargoRate + priceGbp) *
    ((productConversionRate + cargoConversionRate) / 2)
  )
}

