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

const formatGbp = (value: number | null | undefined) =>
  value == null ? '-' : Number(value).toFixed(2)

const formatBdt = (value: number | null | undefined) =>
  value == null ? '-' : String(value)

export const buildAdminProductRows = (items: CostingFileItem[]) =>
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
) =>
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
    const profitRate =
      calculated.costingPriceBdt > 0
        ? `${((profitAmount / calculated.costingPriceBdt) * 100).toFixed(2)}%`
        : '-'
    const quantity = Number(item.quantity ?? 0)
    const totalCostBdt = calculated.costingPriceBdt * quantity
    const totalCostGbp = calculated.costingPriceGbp * quantity
    const totalOfferPriceBdt = calculated.offerPriceBdt * quantity
    const totalProfitBdt = totalOfferPriceBdt - totalCostBdt
    const averageProfitRate =
      totalCostBdt > 0 ? `${((totalProfitBdt / totalCostBdt) * 100).toFixed(2)}%` : '-'

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
      auxiliaryPriceGbp: formatGbp(calculated.auxiliaryPriceGbp),
      purchasePriceGbp: formatGbp(calculated.itemPriceGbp),
      cargoRateValue: item.cargo_rate_is_manual ? item.cargo_rate : calculated.cargoRate,
      cargoRateGbp: formatGbp(
        item.cargo_rate_is_manual ? item.cargo_rate : calculated.cargoRate,
      ),
      costingPriceGbp: formatGbp(calculated.costingPriceGbp),
      costingPriceBdt: formatBdt(calculated.costingPriceBdt),
      offerPriceBdtValue: calculated.offerPriceBdt,
      offerPriceBdt: formatBdt(calculated.offerPriceBdt),
      offerPriceOverrideBdt: item.offer_price_override_bdt,
      profitRate,
      profitAmount: formatBdt(profitAmount),
      totalCostGbp: formatGbp(totalCostGbp),
      totalCostBdt: formatBdt(totalCostBdt),
      totalOfferPriceBdt: formatBdt(totalOfferPriceBdt),
      totalProfitBdt: formatBdt(totalProfitBdt),
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
) =>
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
      itemType: item.item_type ?? '-',
      size: item.size ?? '-',
      color: item.color ?? '-',
      extraInformation1: item.extra_information_1 ?? '-',
      extraInformation2: item.extra_information_2 ?? '-',
      name: item.name ?? '-',
      offerPriceBdt: formatBdt(item.offer_price_bdt),
      buyerSellingPriceBdt: formatBdt(buyerSellingPriceBdt),
      customerProfitAmountBdt: formatBdt(customerProfitAmountBdt),
      customerProfitRateDisplay,
      status: item.status,
    }
  })
