import type { ShopOrderItem } from '../types';
import type { DropshipInvoiceDeliveredQuantitiesState } from './dropshipInvoiceFulfillment';
import type { DropshipInvoiceSummaryState } from './dropshipInvoiceSummary';
import { buildSummaryChargeRows } from './dropshipInvoiceSummary';

export function computeDropshipProcessingFinance(
  items: ShopOrderItem[],
  deliveredQuantities: DropshipInvoiceDeliveredQuantitiesState,
  summary: DropshipInvoiceSummaryState,
) {
  const recipientSubtotal = items.reduce((sum, item) => {
    const qty = deliveredQuantities[item.id] ?? item.quantity;
    const unit = item.customer_sell_price_amount ?? item.final_price_amount ?? item.unit_sell_price_amount ?? 0;
    return sum + unit * qty;
  }, 0);

  const accountingSubtotal = items.reduce((sum, item) => {
    const qty = deliveredQuantities[item.id] ?? item.quantity;
    const unit = item.unit_sell_price_amount ?? item.unit_list_price_amount ?? 0;
    return sum + unit * qty;
  }, 0);

  const deliveryChargeVal = summary.delivery_charge_amount;
  const codChargeVal = summary.cod_charge_amount;
  const printChargeVal = summary.print_charge_amount;
  const packingChargeVal = summary.packing_charge_amount;
  const discountVal = summary.discount_amount;

  const recipientGrandTotal =
    recipientSubtotal +
    buildSummaryChargeRows(summary)
      .filter((row) => row.countsTowardRecipientTotal)
      .reduce((sum, row) => sum + row.amount, 0) -
    discountVal;

  const middlemanTotalCost =
    accountingSubtotal +
    (summary.deduct_print_from_margin ? printChargeVal : 0) +
    (summary.deduct_packing_from_margin ? packingChargeVal : 0) +
    (summary.deduct_delivery_from_margin ? deliveryChargeVal : 0) +
    (summary.deduct_cod_from_margin ? codChargeVal : 0);

  const estimatedProfit = recipientSubtotal - discountVal - middlemanTotalCost;

  return {
    recipientSubtotal,
    accountingSubtotal,
    deliveryChargeVal,
    codChargeVal,
    printChargeVal,
    packingChargeVal,
    discountVal,
    recipientGrandTotal,
    estimatedProfit,
  };
}

export const formatDropshipBdt = (amount: number) =>
  `${Number(amount || 0).toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })} BDT`;
