import type { GlobalInvoiceItemRow } from 'src/modules/bills_pays/types/invoice';
import type { BillDetailBundleLine } from 'src/modules/bills_pays/repositories/billsRepository';

export function kernelBillLinesToStockRows(
  billLines: BillDetailBundleLine[],
  billId: number,
): GlobalInvoiceItemRow[] {
  return billLines.map((line) => {
    const qty = Math.max(0, Number(line.quantity) || 0) || 1;
    const lineTotal = Number(line.line_total_amount ?? 0);
    const sellRaw = line.sell_price_amount;
    const sell =
      sellRaw != null && Number.isFinite(Number(sellRaw))
        ? Number(sellRaw)
        : qty > 0
          ? lineTotal / qty
          : 0;

    return {
      id: line.id,
      invoice_id: billId,
      global_stock_id: line.global_stock_id ?? 0,
      name_snapshot: line.name_snapshot ?? 'Line',
      quantity: Number(line.quantity) || 0,
      sell_price_amount: sell,
      line_discount_amount: 0,
      line_total_amount: lineTotal,
      return_quantity: 0,
      costing: null,
      shipment_item_id: line.shipment_item_id ?? null,
      shipment_id: line.shipment_id ?? null,
    };
  });
}