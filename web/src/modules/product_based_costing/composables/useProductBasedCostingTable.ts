import { computed, unref, watchEffect, type MaybeRef } from 'vue'

export interface ProductBasedCostingItem {
  id: number
  product_based_costing_file_id: number | null
  name: string | null
  image_url: string | null
  quantity: number | null
  barcode: string | null
  product_code: string | null
  web_link: string | null
  price_gbp: number | null
  product_weight: number | null
  package_weight: number | null
  offer_price: number | null
  status: string | null
  created_at: string
  updated_at: string
}

export interface ProductBasedCostingTableRow {
  id: number
  sl: number
  name: string
  imageUrl: string | null
  qty: number
  barcodeText: string
  website: string | null
  priceGbp: number
  productWeight: number
  packageWeight: number
  totalWeight: number
  cargoRate: number
  cargoCostGbp: number
  totalCostGbp: number
  costBdt: number
  totalCostBdt: number
  offerPriceBdt: number
  totalBdt: number
  profitBdt: number
  profitRate: number
  status: string
  raw: ProductBasedCostingItem
}

const toNumber = (value: unknown) => {
  const num = Number(value ?? 0)
  return Number.isNaN(num) ? 0 : num
}

const toText = (value: unknown, fallback = '-') => {
  if (typeof value !== 'string') {
    return fallback
  }

  const trimmed = value.trim()
  return trimmed.length > 0 ? trimmed : fallback
}

export const useProductBasedCostingTable = ({
  items,
  cargoRate,
  conversionRate,
  profitRate,
}: {
  items: MaybeRef<ProductBasedCostingItem[] | null | undefined>
  cargoRate?: MaybeRef<number | null | undefined>
  conversionRate?: MaybeRef<number | null | undefined>
  profitRate?: MaybeRef<number | null | undefined>
}) => {
  const tableRows = computed<ProductBasedCostingTableRow[]>(() => {
    const sourceItems = unref(items) ?? []
    const currentCargoRate = toNumber(unref(cargoRate))
    const currentConversionRate = toNumber(unref(conversionRate))
    const currentProfitRate = toNumber(unref(profitRate))

    console.log('[useProductBasedCostingTable] input items:', sourceItems)
    console.log('[useProductBasedCostingTable] input cargoRate:', currentCargoRate)
    console.log('[useProductBasedCostingTable] input conversionRate:', currentConversionRate)
    console.log('[useProductBasedCostingTable] input profitRate:', currentProfitRate)

    const rows = sourceItems.map((item, index) => {
      const qty = toNumber(item.quantity)
      const priceGbp = toNumber(item.price_gbp)
      const productWeight = toNumber(item.product_weight)
      const packageWeight = toNumber(item.package_weight)
      const offerPrice = toNumber(item.offer_price)

      const totalWeight = (productWeight + packageWeight) * qty
      const cargoCostGbp = (totalWeight / 1000) * currentCargoRate
      const totalCostGbp = priceGbp + cargoCostGbp
      const costBdt = totalCostGbp * currentConversionRate
      const totalCostBdt = costBdt * qty
      const offerPriceBdt = offerPrice * currentConversionRate
      const totalBdt = totalCostBdt
      const profitBdt = totalBdt * (currentProfitRate / 100)

      const barcode = toText(item.barcode, '')
      const productCode = toText(item.product_code, '')
      const barcodeParts = [barcode, productCode, String(item.id)].filter(Boolean)

      const row = {
        id: item.id,
        sl: index + 1,
        name: toText(item.name),
        imageUrl: item.image_url ?? null,
        qty,
        barcodeText: barcodeParts.length > 0 ? barcodeParts.join(' / ') : '-',
        website: item.web_link ?? null,
        priceGbp,
        productWeight,
        packageWeight,
        totalWeight,
        cargoRate: currentCargoRate,
        cargoCostGbp,
        totalCostGbp,
        costBdt,
        totalCostBdt,
        offerPriceBdt,
        totalBdt,
        profitBdt,
        profitRate: currentProfitRate,
        status: toText(item.status),
        raw: item,
      }

      console.log(`[useProductBasedCostingTable] mapped row ${index}:`, {
        input: item,
        output: row,
      })

      return row
    })

    console.log('[useProductBasedCostingTable] output rows:', rows)

    return rows
  })

  watchEffect(() => {
    console.log('[useProductBasedCostingTable] tableRows changed:', tableRows.value)
  })

  return {
    tableRows,
  }
}
