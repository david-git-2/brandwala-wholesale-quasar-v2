import { calculateLineLandedCostBdt, type CostingLineItemInput, type CostingShipmentInput } from '../../procurement_stock/utils/landedCost'

export interface LineInput {
  id?: number | null | undefined
  sell_price_amount?: number | null | undefined
  sell_price?: number | null | undefined
  unit_cost_price?: number | null | undefined
  unit_cost?: number | null | undefined
  quantity?: number | null | undefined
  qty?: number | null | undefined
  line_discount_amount?: number | null | undefined
  line_discount?: number | null | undefined
  recipient_price_amount?: number | null | undefined
  recipient_price?: number | null | undefined
  line_total_amount?: number | null | undefined
  line_face_total_amount?: number | null | undefined
}

export interface InvoiceInput {
  invoice_type: 'wholesale' | 'retail' | 'dropship'
  shipping_charge?: number | null | undefined
  cod_charge?: number | null | undefined
  print_charge?: number | null | undefined
  wrapping_charge?: number | null | undefined
  discount_amount?: number | null | undefined
  settlement_discount_amount?: number | null | undefined
  invoice_status?: string | null | undefined
  accounting_subtotal_amount?: number | null | undefined
  face_subtotal_amount?: number | null | undefined
  middle_man_payout_amount?: number | null | undefined
}

export interface ReturnInput {
  invoice_item_id: number
  quantity: number
  return_accounting_amount: number
}

export interface ShipmentItemInput {
  id: number
  received_qty?: number | null | undefined
  received_quantity?: number | null | undefined
  purchase_price?: number | null | undefined
  product_weight?: number | null | undefined
  package_weight?: number | null | undefined
  ordered_quantity?: number | null | undefined
  landed_unit_cost?: number | null | undefined
  sellable_qty?: number | null | undefined
  stolen_qty?: number | null | undefined
  box_damage_qty?: number | null | undefined
  expired_qty?: number | null | undefined
  reserved_qty?: number | null | undefined
}

export interface SoldLineInput {
  id: number
  shipment_item_id: number | null | undefined
  unit_cost_price?: number | null | undefined
  unit_cost?: number | null | undefined
  sell_price_amount?: number | null | undefined
  sell_price?: number | null | undefined
  quantity?: number | null | undefined
  qty?: number | null | undefined
}

/**
 * Calculates margin for a single invoice line.
 * Formula: (sell_price - unit_cost_price) * qty - line_discount
 */
export const lineMargin = (line: LineInput): number => {
  const sellPrice = line.sell_price_amount ?? line.sell_price ?? 0
  const unitCost = line.unit_cost_price ?? line.unit_cost ?? 0
  const qty = line.quantity ?? line.qty ?? 0
  const discount = line.line_discount_amount ?? line.line_discount ?? 0
  return (sellPrice - unitCost) * qty - discount
}

/**
 * Calculates the type-aware charge effect on invoice gross profit.
 * - Wholesale: shipping_charge only.
 * - Retail: shipping_charge + cod_charge + print_charge + wrapping_charge.
 * - Dropship: shipping_charge only (accounting charges).
 */
export const chargeEffect = (invoice: InvoiceInput): number => {
  const type = invoice.invoice_type
  const shipping = invoice.shipping_charge ?? 0
  const cod = invoice.cod_charge ?? 0
  const print = invoice.print_charge ?? 0
  const wrapping = invoice.wrapping_charge ?? 0

  if (type === 'wholesale' || type === 'dropship') {
    return shipping
  }
  if (type === 'retail') {
    return shipping + cod + print + wrapping
  }
  return 0
}

/**
 * Calculates the gross profit for an invoice.
 * Formula: Σ line margin - discount + charge_effect - return_margin_total
 * Filters: invoice_status = 'posted' only; voided/drafts return 0.
 */
export const invoiceGrossProfit = (
  invoice: InvoiceInput,
  lines: (LineInput & { id: number })[],
  returns: ReturnInput[] = []
): number => {
  if (invoice.invoice_status !== undefined && invoice.invoice_status !== 'posted') {
    return 0
  }

  const sumLineMargin = lines.reduce((sum, line) => sum + lineMargin(line), 0)
  const discount = (invoice.discount_amount ?? 0) + (invoice.settlement_discount_amount ?? 0)
  const charges = chargeEffect(invoice)

  const returnMarginTotal = returns.reduce((sum, ret) => {
    const line = lines.find((l) => l.id === ret.invoice_item_id)
    if (!line) return sum
    const unitCost = line.unit_cost_price ?? line.unit_cost ?? 0
    const returnMargin = ret.return_accounting_amount - (unitCost * ret.quantity)
    return sum + returnMargin
  }, 0)

  return sumLineMargin - discount + charges - returnMarginTotal
}

export interface BatchPnlResult {
  landedCost: number
  soldCost: number
  revenue: number
  grossProfit: number
  sellableOnHandValue: number
  shrinkageValue: number
  stolenValue: number
  boxDamageValue: number
  expiredValue: number
  unsoldValue: number
}

/**
 * Calculates Batch P&L statistics for a list of shipment items and sold lines.
 * Reuses landedCost.ts calculations when necessary.
 */
export const batchPnl = (
  shipment: CostingShipmentInput,
  shipmentItems: ShipmentItemInput[],
  soldLines: SoldLineInput[],
  returns: ReturnInput[] = []
): BatchPnlResult => {
  // Convert ShipmentItemInput to CostingLineItemInput to reuse calculateLineLandedCostBdt
  const costingItems: CostingLineItemInput[] = shipmentItems.map((item) => ({
    purchase_price: item.purchase_price ?? 0,
    product_weight: item.product_weight ?? 0,
    package_weight: item.package_weight ?? 0,
    ordered_quantity: item.ordered_quantity ?? item.received_qty ?? item.received_quantity ?? 0,
  }))

  let totalLandedCost = 0
  let totalSoldCost = 0
  let totalRevenue = 0
  let totalSellableOnHandValue = 0
  let totalShrinkageValue = 0
  let totalStolenValue = 0
  let totalBoxDamageValue = 0
  let totalExpiredValue = 0

  shipmentItems.forEach((item, index) => {
    const receivedQty = item.received_qty ?? item.received_quantity ?? 0
    
    // Resolve landed unit cost: use calculated landed cost from landedCost.ts if available, otherwise direct override
    let landedUnitCost = item.landed_unit_cost
    if (landedUnitCost === undefined || landedUnitCost === null) {
      const costingItem = costingItems[index]
      if (costingItem) {
        landedUnitCost = calculateLineLandedCostBdt(costingItem, shipment, costingItems)
      } else {
        landedUnitCost = 0
      }
    }

    totalLandedCost += landedUnitCost * receivedQty

    // Find sold lines matching this shipment item
    const matchingLines = soldLines.filter((line) => line.shipment_item_id === item.id)

    let itemSoldQty = 0
    let itemSoldCost = 0
    let itemRevenue = 0

    matchingLines.forEach((line) => {
      const lineQty = line.quantity ?? line.qty ?? 0
      const sellPrice = line.sell_price_amount ?? line.sell_price ?? 0
      const unitCost = line.unit_cost_price ?? line.unit_cost ?? 0

      // Find returns matching this line
      const lineReturns = returns.filter((ret) => ret.invoice_item_id === line.id)
      const returnedQty = lineReturns.reduce((sum, r) => sum + r.quantity, 0)
      const returnedAmount = lineReturns.reduce((sum, r) => sum + r.return_accounting_amount, 0)

      const activeQty = lineQty - returnedQty
      itemSoldQty += activeQty
      itemSoldCost += unitCost * activeQty
      itemRevenue += (sellPrice * lineQty) - returnedAmount
    })

    totalSoldCost += itemSoldCost
    totalRevenue += itemRevenue

    const sellableQty = (item.sellable_qty !== undefined && item.sellable_qty !== null)
      ? item.sellable_qty
      : (receivedQty - itemSoldQty)
    const stolenQty = item.stolen_qty ?? 0
    const boxDamageQty = item.box_damage_qty ?? 0
    const expiredQty = item.expired_qty ?? 0

    totalSellableOnHandValue += sellableQty * landedUnitCost
    totalStolenValue += stolenQty * landedUnitCost
    totalBoxDamageValue += boxDamageQty * landedUnitCost
    totalExpiredValue += expiredQty * landedUnitCost
    totalShrinkageValue += (stolenQty + boxDamageQty + expiredQty) * landedUnitCost
  })

  return {
    landedCost: totalLandedCost,
    soldCost: totalSoldCost,
    revenue: totalRevenue,
    grossProfit: totalRevenue - totalSoldCost,
    sellableOnHandValue: totalSellableOnHandValue,
    shrinkageValue: totalShrinkageValue,
    stolenValue: totalStolenValue,
    boxDamageValue: totalBoxDamageValue,
    expiredValue: totalExpiredValue,
    unsoldValue: totalSellableOnHandValue,
  }
}

export interface DropshipColumnsResult {
  accountingSubtotal: number
  faceSubtotal: number
  middleManPayout: number
  accountingMargin: number
}

/**
 * Calculates separate accounting margin vs face/COD totals for dropship invoices.
 */
export const dropshipColumns = (
  invoice: InvoiceInput,
  lines: (LineInput & { id: number })[],
  returns: ReturnInput[] = []
): DropshipColumnsResult => {
  const accountingSubtotal = invoice.accounting_subtotal_amount ?? lines.reduce((sum, line) => {
    return sum + (line.line_total_amount ?? ((line.sell_price_amount ?? line.sell_price ?? 0) * (line.quantity ?? line.qty ?? 0) - (line.line_discount_amount ?? line.line_discount ?? 0)))
  }, 0)

  const faceSubtotal = invoice.face_subtotal_amount ?? lines.reduce((sum, line) => {
    const recipientPrice = line.recipient_price_amount ?? line.recipient_price ?? line.sell_price_amount ?? line.sell_price ?? 0
    return sum + (line.line_face_total_amount ?? (recipientPrice * (line.quantity ?? line.qty ?? 0) - (line.line_discount_amount ?? line.line_discount ?? 0)))
  }, 0)

  const middleManPayout = invoice.middle_man_payout_amount ?? lines.reduce((sum, line) => {
    const sellPrice = line.sell_price_amount ?? line.sell_price ?? 0
    const recipientPrice = line.recipient_price_amount ?? line.recipient_price ?? sellPrice
    const qty = line.quantity ?? line.qty ?? 0
    return sum + Math.max((recipientPrice - sellPrice) * qty, 0)
  }, 0)

  const accountingMargin = invoiceGrossProfit(invoice, lines, returns)

  return {
    accountingSubtotal,
    faceSubtotal,
    middleManPayout,
    accountingMargin,
  }
}
