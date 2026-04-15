import { computed, type Ref } from 'vue'

export type OrderItem = {
  id: number
  name: string
  cost_bdt: number | null
  cost_gbp: number | null
  order_id: number
  image_url: string | null
  price_gbp: number | null
  created_at: string
  product_id: number | null
  updated_at: string
  package_weight: number | null
  product_weight: number | null
  final_offer_bdt: number | null
  first_offer_bdt: number | null
  minimum_quantity: number
  ordered_quantity: number
  returned_quantity: number
  customer_offer_bdt: number | null
  delivered_quantity: number
}

export type OrderItemTableRow = OrderItem & {
  sl: number
  total_weight: number
  cargo_rate: number
  line_total_purchese_cost_gbp: number | null
  unit_line_cost_gbp: number
  line_total_cost_bdt: number
  seller_first_offer_bdt: number
  seller_first_offer_bdt_total: number
  seller_first_offer_profit_pc: number
  seler_first_offer_profit_pc_perc: number | null
  seller_first_offer_profit_total: number
  customer_offer_bdt_total: number | null
  customer_offer_profit_pc: number | null
  customer_offer_profit_total: number | null
  customer_offer_profit_pc_perc: number | null
  final_offer_profit_pc: number | null
  final_offer_profit_total: number | null
  final_offer_profit_pc_perc: number | null
}

type UseOrderItemTableRowsParams = {
  items: Ref<OrderItem[]>
  conversionRate: Ref<number | null | undefined>
  cargoRate: Ref<number | null | undefined>
  profitRate: Ref<number | null | undefined>
}

const ceil2 = (n: number) => Math.ceil(n * 100) / 100
const ceilInt = (n: number) => Math.ceil(n)
const roundToNearest5 = (n: number) => Math.round(n / 5) * 5

export const useOrderItemTableRows = ({
  items,
  conversionRate,
  cargoRate,
  profitRate,
}: UseOrderItemTableRowsParams) => {
  const tableRows = computed<OrderItemTableRow[]>(() =>
    items.value.map((item, index) => {
      const productWeight = Number(item.product_weight || 0)
      const packageWeight = Number(item.package_weight || 0)
      const totalWeight = productWeight + packageWeight

      const price = Number(item.price_gbp || 0)
      const quantity = Number(item.ordered_quantity || 0)
      const cargoRateValue = Number(cargoRate.value || 0)
      const conversionRateValue = Number(conversionRate.value || 0)
      const profitRateValue = Number(profitRate.value || 0)

      const lineTotalPurchaseCost =
        item.price_gbp != null ? ceil2(price * quantity) : null

      const unitLineCostRaw = (totalWeight / 1000) * cargoRateValue + price
      const unitLineCost = ceil2(unitLineCostRaw)

      const costBdtRaw = ceilInt(unitLineCost * conversionRateValue)
      const lineTotalCostBdt = ceilInt(costBdtRaw * quantity)

      const sellerFirstOfferBdt = roundToNearest5(
        (costBdtRaw * profitRateValue) / 100 + costBdtRaw
      )
      const sellerFirstOfferBdtTotal = sellerFirstOfferBdt * quantity
      const sellerFirstOfferProfitPc = ceilInt(sellerFirstOfferBdt - costBdtRaw)
      const selerFirstOfferProfitPcPerc =
        costBdtRaw > 0
          ? ceilInt(((sellerFirstOfferBdt - costBdtRaw) / costBdtRaw) * 100)
          : null
      const sellerFirstOfferProfitTotal = sellerFirstOfferProfitPc * quantity

      const customerOfferBdtPc = item.customer_offer_bdt
      const customerOfferBdtTotal =
        customerOfferBdtPc != null ? ceilInt(customerOfferBdtPc * quantity) : null
      const customerOfferProfitPc =
        customerOfferBdtPc != null
          ? ceilInt(customerOfferBdtPc - costBdtRaw)
          : null
      const customerOfferProfitTotal =
        customerOfferProfitPc != null ? ceilInt(customerOfferProfitPc * quantity) : null
      const customerOfferProfitPcPerc =
        costBdtRaw > 0 && customerOfferBdtPc != null
          ? ceilInt(((customerOfferBdtPc - costBdtRaw) / costBdtRaw) * 100)
          : null

      const finalOfferBdt =
        item.final_offer_bdt != null ? item.final_offer_bdt : item.customer_offer_bdt
      const finalOfferProfitPc =
        finalOfferBdt != null ? ceilInt(finalOfferBdt - costBdtRaw) : null
      const finalOfferProfitTotal =
        finalOfferProfitPc != null ? ceilInt(finalOfferProfitPc * quantity) : null
      const finalOfferProfitPcPerc =
        costBdtRaw > 0 && finalOfferBdt != null
          ? ceilInt(((finalOfferBdt - costBdtRaw) / costBdtRaw) * 100)
          : null

      return {
        ...item,
        sl: index + 1,
        total_weight: totalWeight,
        cargo_rate: cargoRateValue,
        line_total_purchese_cost_gbp: lineTotalPurchaseCost,
        unit_line_cost_gbp: unitLineCost,
        cost_bdt: costBdtRaw,
        line_total_cost_bdt: lineTotalCostBdt,
        seller_first_offer_bdt: sellerFirstOfferBdt,
        seller_first_offer_bdt_total: sellerFirstOfferBdtTotal,
        seller_first_offer_profit_pc: sellerFirstOfferProfitPc,
        seler_first_offer_profit_pc_perc: selerFirstOfferProfitPcPerc,
        seller_first_offer_profit_total: sellerFirstOfferProfitTotal,
        customer_offer_bdt: customerOfferBdtPc,
        customer_offer_bdt_total: customerOfferBdtTotal,
        customer_offer_profit_pc: customerOfferProfitPc,
        customer_offer_profit_total: customerOfferProfitTotal,
        customer_offer_profit_pc_perc: customerOfferProfitPcPerc,
        final_offer_bdt: finalOfferBdt,
        final_offer_profit_pc: finalOfferProfitPc,
        final_offer_profit_total: finalOfferProfitTotal,
        final_offer_profit_pc_perc: finalOfferProfitPcPerc,
      }
    })
  )

  return {
    tableRows,
  }
}
