import type { GlobalInvoiceDetail } from 'src/modules/sales_invoice/types';

/** Courier AP issued at dropship ship (`upsert_dropship_courier_ap_bill`). */
export function isDropshipCourierApBill(bill: GlobalInvoiceDetail | undefined): boolean {
  if (!bill || bill.invoice_type !== 'ap') return false;
  if (bill.source_type === 'dropship_courier') return true;
  return bill.source_type === 'shop_order' && bill.source_key === 'courier';
}

/** Merchant AR to dropshipper (`INV-DS-*`, invoice_type dropship). */
export function isDropshipMerchantCustomerBill(bill: GlobalInvoiceDetail | undefined): boolean {
  if (!bill) return false;
  if (bill.invoice_type === 'dropship') return true;
  return (
    bill.shop_order_id != null &&
    typeof bill.invoice_no === 'string' &&
    bill.invoice_no.startsWith('INV-DS-')
  );
}

/** Collect/remit from dropship settlement desk or Payments → Courier — not generic bill pay-in. */
export function isDropshipManagerBill(bill: GlobalInvoiceDetail | undefined): boolean {
  return isDropshipCourierApBill(bill) || isDropshipMerchantCustomerBill(bill);
}
