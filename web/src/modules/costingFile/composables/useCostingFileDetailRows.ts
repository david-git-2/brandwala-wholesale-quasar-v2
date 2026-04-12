import type { CostingFileItem } from 'src/modules/costingFile/types'
import {
  calculateBuyerSellPrice,
  calculateCostingItem,
} from 'src/modules/costingFile/utils/costingCalculations'

type AdminPricingInput = {
  cargoRate1Kg: number | null
  cargoRate2Kg: number | null
  conversionRate: number | null
  adminProfitRate: number | null
}

const toNumber = (value: number | null | undefined) => Number(value ?? 0)

const formatGbp = (value: number | null | undefined) =>
  value == null ? '-' : Number(value).toFixed(2)

const formatBdt = (value: number | null | undefined) =>
  value == null ? '-' : String(value)

export type AdminProductRow = {
  id: number
  sl: number
  imageUrl: string | null
  websiteUrl: string | null
  name: string
  itemType: string
  size: string
  color: string
  extraInformation1: string
  extraInformation2: string
  priceInWebGbpValue: number | null
  priceInWebGbp: string
  productWeightValue: number | null
  productWeight: number | string
  packageWeightValue: number | null
  packageWeight: number | string
  quantity: number | null
}

export type AdminReviewRow = {
  id: number
  sl: number
  imageUrl: string | null
  websiteUrl: string | null
  quantity: number
  name: string
  itemType: string
  size: string
  color: string
  extraInformation1: string
  extraInformation2: string
  productWeight: number | string
  productWeightValue: number | null
  packageWeight: number | string
  packageWeightValue: number | null
  totalWeight: number
  priceInWebGbpValue: number | null
  priceInWebGbp: string
  deliveryPriceGbpValue: number | null
  deliveryPriceGbp: string
  status: string | null
  auxiliaryPriceGbpValue: number
  auxiliaryPriceGbp: string
  purchasePriceGbpValue: number
  purchasePriceGbp: string
  cargoRateValue: number | null
  cargoRateGbp: string
  costingPriceGbpValue: number
  costingPriceGbp: string
  costingPriceBdtValue: number
  costingPriceBdt: string
  offerPriceBdtValue: number
  offerPriceBdt: string
  offerPriceOverrideBdt: number | null
  profitRateValue: number
  profitRate: string
  profitAmountValue: number
  profitAmount: string
  totalCostGbpValue: number
  totalCostGbp: string
  totalCostBdtValue: number
  totalCostBdt: string
  totalOfferPriceBdtValue: number
  totalOfferPriceBdt: string
  totalProfitBdtValue: number
  totalProfitBdt: string
  averageProfitRateValue: number
  averageProfitRate: string
}

export type CustomerProductRow = {
  id: number
  sl: number
  imageUrl: string | null
  websiteUrl: string | null
  quantity: number | null
  quantityValue: number
  itemType: string
  size: string
  color: string
  extraInformation1: string
  extraInformation2: string
  name: string
  offerPriceBdtValue: number
  offerPriceBdt: string
  buyerSellingPriceBdtValue: number
  buyerSellingPriceBdt: string
  customerProfitAmountBdtValue: number
  customerProfitAmountBdt: string
  customerProfitRateValue: number | null
  customerProfitRateDisplay: string
  status: string | null
}

export const buildAdminProductRows = (items: CostingFileItem[]): AdminProductRow[] =>
  items.map((item, index) => ({
    id: item.id,
    sl: index + 1,
    imageUrl: item.image_url,
    websiteUrl: item.website_url,
    name: item.name ?? '-',
    itemType: item.item_type ?? '-',
    size: item.size ?? '-',
    color: item.color ?? '-',
    extraInformation1: item.extra_information_1 ?? '-',
    extraInformation2: item.extra_information_2 ?? '-',
    priceInWebGbpValue: item.price_in_web_gbp,
    priceInWebGbp:
      item.price_in_web_gbp == null ? '-' : Number(item.price_in_web_gbp).toFixed(2),
    productWeightValue: item.product_weight,
    productWeight: item.product_weight == null ? '-' : item.product_weight,
    packageWeightValue: item.package_weight,
    packageWeight: item.package_weight == null ? '-' : item.package_weight,
    quantity: item.quantity,
  }))

export const buildAdminReviewRows = (
  items: CostingFileItem[],
  pricing: AdminPricingInput,
): AdminReviewRow[] =>
  items.map((item, index) => {
    const calculated = calculateCostingItem(
      {
        cargoRate1Kg: pricing.cargoRate1Kg,
        cargoRate2Kg: pricing.cargoRate2Kg,
        cargoRateOverride: item.cargo_rate,
        cargoRateIsManual: item.cargo_rate_is_manual,
        conversionRate: pricing.conversionRate,
        adminProfitRate: pricing.adminProfitRate,
        offerPriceOverrideBdt: item.offer_price_override_bdt,
      },
      {
        productWeight: item.product_weight,
        packageWeight: item.package_weight,
        priceInWebGbp: item.price_in_web_gbp,
        deliveryPriceGbp: item.delivery_price_gbp,
        customerProfitRate: item.customer_profit_rate,
        itemType: item.item_type,
      },
    )
    const profitAmount = calculated.offerPriceBdt - calculated.costingPriceBdt
    const profitRateValue =
      calculated.costingPriceBdt > 0 ? (profitAmount / calculated.costingPriceBdt) * 100 : 0
    const profitRate =
      calculated.costingPriceBdt > 0 ? `${profitRateValue.toFixed(2)}%` : '-'
    const quantity = Number(item.quantity ?? 0)
    const totalCostBdt = calculated.costingPriceBdt * quantity
    const totalCostGbp = calculated.costingPriceGbp * quantity
    const totalOfferPriceBdt = calculated.offerPriceBdt * quantity
    const totalProfitBdt = totalOfferPriceBdt - totalCostBdt
    const averageProfitRateValue =
      totalCostBdt > 0 ? (totalProfitBdt / totalCostBdt) * 100 : 0
    const averageProfitRate =
      totalCostBdt > 0 ? `${averageProfitRateValue.toFixed(2)}%` : '-'

    return {
      id: item.id,
      sl: index + 1,
      imageUrl: item.image_url,
      websiteUrl: item.website_url,
      quantity,
      name: item.name ?? '-',
      itemType: item.item_type ?? '-',
      size: item.size ?? '-',
      color: item.color ?? '-',
      extraInformation1: item.extra_information_1 ?? '-',
      extraInformation2: item.extra_information_2 ?? '-',
      productWeight: item.product_weight ?? '-',
      productWeightValue: item.product_weight,
      packageWeight: item.package_weight ?? '-',
      packageWeightValue: item.package_weight,
      totalWeight: calculated.totalWeight,
      priceInWebGbpValue: item.price_in_web_gbp,
      priceInWebGbp: formatGbp(item.price_in_web_gbp),
      deliveryPriceGbpValue: item.delivery_price_gbp,
      deliveryPriceGbp: formatGbp(item.delivery_price_gbp),
      status: item.status,
      auxiliaryPriceGbpValue: calculated.auxiliaryPriceGbp,
      auxiliaryPriceGbp: formatGbp(calculated.auxiliaryPriceGbp),
      purchasePriceGbpValue: calculated.itemPriceGbp,
      purchasePriceGbp: formatGbp(calculated.itemPriceGbp),
      cargoRateValue: item.cargo_rate_is_manual ? item.cargo_rate : calculated.cargoRate,
      cargoRateGbp: formatGbp(
        item.cargo_rate_is_manual ? item.cargo_rate : calculated.cargoRate,
      ),
      costingPriceGbpValue: calculated.costingPriceGbp,
      costingPriceGbp: formatGbp(calculated.costingPriceGbp),
      costingPriceBdtValue: calculated.costingPriceBdt,
      costingPriceBdt: formatBdt(calculated.costingPriceBdt),
      offerPriceBdtValue: calculated.offerPriceBdt,
      offerPriceBdt: formatBdt(calculated.offerPriceBdt),
      offerPriceOverrideBdt: item.offer_price_override_bdt,
      profitRateValue,
      profitRate,
      profitAmountValue: profitAmount,
      profitAmount: formatBdt(profitAmount),
      totalCostGbpValue: totalCostGbp,
      totalCostGbp: formatGbp(totalCostGbp),
      totalCostBdtValue: totalCostBdt,
      totalCostBdt: formatBdt(totalCostBdt),
      totalOfferPriceBdtValue: totalOfferPriceBdt,
      totalOfferPriceBdt: formatBdt(totalOfferPriceBdt),
      totalProfitBdtValue: totalProfitBdt,
      totalProfitBdt: formatBdt(totalProfitBdt),
      averageProfitRateValue,
      averageProfitRate,
    }
  })

export const buildStaffProductRows = (items: CostingFileItem[]) =>
  items.map((item, index) => ({
    id: item.id,
    sl: index + 1,
    imageUrl: item.image_url,
    websiteUrl: item.website_url,
    name: item.name ?? '-',
    itemType: item.item_type ?? '-',
    size: item.size ?? '-',
    color: item.color ?? '-',
    extraInformation1: item.extra_information_1 ?? '-',
    extraInformation2: item.extra_information_2 ?? '-',
    webPriceGbp: item.price_in_web_gbp == null ? '-' : `GBP ${item.price_in_web_gbp}`,
    productWeight: item.product_weight == null ? '-' : item.product_weight,
    packageWeight: item.package_weight == null ? '-' : item.package_weight,
    quantity: item.quantity ?? '-',
  }))

export const buildCustomerProductRows = (
  items: CostingFileItem[],
  sharedProfitRate: number | null,
): CustomerProductRow[] =>
  items.map((item, index) => {
    const offerPriceBdt = Number(item.offer_price_bdt ?? 0)
    const effectiveProfitRate = sharedProfitRate ?? item.customer_profit_rate
    const buyerSellingPriceBdt = calculateBuyerSellPrice(
      item.offer_price_bdt,
      effectiveProfitRate,
    )
    const customerProfitAmountBdt = buyerSellingPriceBdt - offerPriceBdt
    const customerProfitRateDisplay =
      offerPriceBdt > 0
        ? `${((customerProfitAmountBdt / offerPriceBdt) * 100).toFixed(2)}%`
        : '-'

    return {
      id: item.id,
      sl: index + 1,
      imageUrl: item.image_url,
      websiteUrl: item.website_url,
      quantity: item.quantity,
      quantityValue: toNumber(item.quantity),
      itemType: item.item_type ?? '-',
      size: item.size ?? '-',
      color: item.color ?? '-',
      extraInformation1: item.extra_information_1 ?? '-',
      extraInformation2: item.extra_information_2 ?? '-',
      name: item.name ?? '-',
      offerPriceBdtValue: offerPriceBdt,
      offerPriceBdt: formatBdt(item.offer_price_bdt),
      buyerSellingPriceBdtValue: buyerSellingPriceBdt,
      buyerSellingPriceBdt: formatBdt(buyerSellingPriceBdt),
      customerProfitAmountBdtValue: customerProfitAmountBdt,
      customerProfitAmountBdt: formatBdt(customerProfitAmountBdt),
      customerProfitRateValue:
        offerPriceBdt > 0 ? (customerProfitAmountBdt / offerPriceBdt) * 100 : null,
      customerProfitRateDisplay,
      status: item.status,
    }
  })

export const summarizeAdminProductRows = (rows: AdminProductRow[]) => ({
  quantity: rows.reduce((sum, row) => sum + toNumber(row.quantity), 0),
  priceInWebGbp: rows.reduce((sum, row) => sum + toNumber(row.priceInWebGbpValue), 0),
  productWeight: rows.reduce((sum, row) => sum + toNumber(row.productWeightValue), 0),
  packageWeight: rows.reduce((sum, row) => sum + toNumber(row.packageWeightValue), 0),
})

export const summarizeAdminReviewRows = (rows: AdminReviewRow[]) => {
  const totals = rows.reduce(
    (sum, row) => {
      sum.quantity += row.quantity
      sum.productWeight += toNumber(row.productWeightValue)
      sum.packageWeight += toNumber(row.packageWeightValue)
      sum.totalWeight += row.totalWeight
      sum.priceInWebGbp += toNumber(row.priceInWebGbpValue)
      sum.deliveryPriceGbp += toNumber(row.deliveryPriceGbpValue)
      sum.auxiliaryPriceGbp += row.auxiliaryPriceGbpValue
      sum.purchasePriceGbp += row.purchasePriceGbpValue
      sum.cargoRateGbp += toNumber(row.cargoRateValue)
      sum.costingPriceGbp += row.costingPriceGbpValue
      sum.costingPriceBdt += row.costingPriceBdtValue
      sum.offerPriceBdt += row.offerPriceBdtValue
      sum.totalCostGbp += row.totalCostGbpValue
      sum.totalCostBdt += row.totalCostBdtValue
      sum.totalOfferPriceBdt += row.totalOfferPriceBdtValue
      sum.totalProfitBdt += row.totalProfitBdtValue
      sum.profitAmount += row.profitAmountValue
      return sum
    },
    {
      quantity: 0,
      productWeight: 0,
      packageWeight: 0,
      totalWeight: 0,
      priceInWebGbp: 0,
      deliveryPriceGbp: 0,
      auxiliaryPriceGbp: 0,
      purchasePriceGbp: 0,
      cargoRateGbp: 0,
      costingPriceGbp: 0,
      costingPriceBdt: 0,
      offerPriceBdt: 0,
      totalCostGbp: 0,
      totalCostBdt: 0,
      totalOfferPriceBdt: 0,
      totalProfitBdt: 0,
      profitAmount: 0,
    },
  )

  return {
    ...totals,
    profitRate:
      totals.costingPriceBdt > 0 ? (totals.profitAmount / totals.costingPriceBdt) * 100 : null,
    averageProfitRate:
      totals.totalCostBdt > 0 ? (totals.totalProfitBdt / totals.totalCostBdt) * 100 : null,
  }
}

export const summarizeCustomerProductRows = (rows: CustomerProductRow[]) => {
  const totals = rows.reduce(
    (sum, row) => {
      sum.quantity += row.quantityValue
      sum.offerPriceBdt += row.offerPriceBdtValue
      sum.buyerSellingPriceBdt += row.buyerSellingPriceBdtValue
      sum.customerProfitAmountBdt += row.customerProfitAmountBdtValue
      return sum
    },
    {
      quantity: 0,
      offerPriceBdt: 0,
      buyerSellingPriceBdt: 0,
      customerProfitAmountBdt: 0,
    },
  )

  return {
    ...totals,
    customerProfitRate:
      totals.offerPriceBdt > 0
        ? (totals.customerProfitAmountBdt / totals.offerPriceBdt) * 100
        : null,
  }
}
