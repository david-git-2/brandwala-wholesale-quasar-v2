import type { GlobalInvoiceDetail } from 'src/modules/sales_invoice/types';
import type { ShipmentApKind } from 'src/modules/procurement_stock/repositories/shipmentApBillsRepository';

export function shipmentIdFromBill(bill: GlobalInvoiceDetail | undefined): number | null {
  if (!bill) return null;
  if (bill.ap_shipment_id != null && Number.isFinite(Number(bill.ap_shipment_id))) {
    return Number(bill.ap_shipment_id);
  }
  if (bill.source_type === 'shipment_cost' && bill.source_id) {
    const id = Number(bill.source_id);
    return Number.isFinite(id) && id > 0 ? id : null;
  }
  return null;
}

export function shipmentApKindFromBill(bill: GlobalInvoiceDetail | undefined): ShipmentApKind | null {
  if (!bill) return null;
  const key = (bill.source_key ?? bill.ap_kind)?.trim();
  return key ? (key as ShipmentApKind) : null;
}

export function isShipmentCostApBill(bill: GlobalInvoiceDetail | undefined): boolean {
  if (!bill || bill.invoice_type !== 'ap') return false;
  if (bill.source_type === 'shipment_cost') return true;
  return bill.ap_shipment_id != null;
}
