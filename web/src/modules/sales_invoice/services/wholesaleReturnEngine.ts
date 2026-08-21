import type {
  GlobalInvoiceDetail,
  GlobalInvoiceItemRow,
  WholesaleReturnItemInput,
  WholesaleReturnPreviewSummary,
} from '../types';

/**
 * Pure in-memory calculation engine for wholesale invoice returns.
 * Computes revised quantities, retained values, new invoice totals, remaining dues,
 * and customer overpayment refunds with 0 DB roundtrips.
 */
export function computeWholesaleReturnPreview(
  invoice: GlobalInvoiceDetail,
  items: GlobalInvoiceItemRow[],
  returnInputs: WholesaleReturnItemInput[],
  returnCharge = 0,
): WholesaleReturnPreviewSummary {
  const originalSubtotal = Number(invoice.subtotal_amount ?? 0);
  const originalTotal = Number(invoice.total_amount ?? 0);
  const originalPaid = Number(invoice.paid_amount ?? 0);
  const originalDue = Number(invoice.due_amount ?? 0);

  const inputMap = new Map<number, WholesaleReturnItemInput>();
  for (const input of returnInputs) {
    if (input.invoice_item_id) {
      inputMap.set(input.invoice_item_id, input);
    }
  }

  let totalReturnValue = 0;
  let newSubtotal = 0;

  const lineSummaries = items.map((item) => {
    const invoicedQty = Number(item.quantity ?? 0);
    const prevReturnedQty = Number(item.return_quantity ?? 0);
    const availableToReturn = Math.max(invoicedQty - prevReturnedQty, 0);

    const input = inputMap.get(item.id);
    const requestedReturnQty = input ? Number(input.quantity ?? 0) : 0;
    // Bound return quantity between 0 and remaining returnable units
    const validReturnQty = Math.min(Math.max(requestedReturnQty, 0), availableToReturn);

    const unitPrice = Number(item.sell_price_amount ?? 0);
    const lineReturnValue = Math.round(validReturnQty * unitPrice * 100) / 100;
    totalReturnValue += lineReturnValue;

    const cumulativeReturned = prevReturnedQty + validReturnQty;
    const retainedQty = Math.max(invoicedQty - cumulativeReturned, 0);
    const lineDiscount = Number(item.line_discount_amount ?? 0);

    // Retained line total = (retainedQty * unitPrice) - lineDiscount
    const newLineTotal = Math.max(retainedQty * unitPrice - lineDiscount, 0);
    newSubtotal += newLineTotal;

    return {
      invoice_item_id: item.id,
      invoiced_qty: invoicedQty,
      return_qty: validReturnQty,
      retained_qty: retainedQty,
      unit_price: unitPrice,
      line_return_value: lineReturnValue,
      new_line_total: newLineTotal,
    };
  });

  const charge = Math.max(Number(returnCharge) || 0, 0);
  const netReturnCredit = Math.max(totalReturnValue - charge, 0);

  const shippingCharge = Number(invoice.shipping_charge ?? 0);
  const wrappingCharge = Number(invoice.wrapping_charge ?? 0);
  const printCharge = Number(invoice.print_charge ?? 0);
  const invoiceDiscount = Number(invoice.discount_amount ?? 0);

  const totalAncillaryCharges = shippingCharge + wrappingCharge + printCharge + charge;
  const newTotal = Math.max(newSubtotal + totalAncillaryCharges - invoiceDiscount, 0);

  const newDue = Math.max(newTotal - originalPaid, 0);
  const excessPaidRefund = Math.max(originalPaid - newTotal, 0);

  let settlementType: 'no_money_exchanged' | 'reduce_due_only' | 'refund_required' = 'no_money_exchanged';
  if (excessPaidRefund > 0) {
    settlementType = 'refund_required';
  } else if (newDue < originalDue) {
    settlementType = 'reduce_due_only';
  }

  return {
    originalSubtotal,
    originalTotal,
    originalPaid,
    originalDue,

    totalReturnValue,
    returnCharge: charge,
    netReturnCredit,

    newSubtotal,
    newTotal,
    newDue,
    excessPaidRefund,

    settlementType,
    lineSummaries,
  };
}
