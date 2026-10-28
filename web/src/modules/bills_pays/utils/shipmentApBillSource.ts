import { supabase } from 'src/boot/supabase';
import type { GlobalInvoiceDetail } from 'src/modules/sales_invoice/types';
import type { ShipmentApKind } from 'src/modules/procurement_stock/repositories/shipmentApBillsRepository';

export type BillShipmentPlug = {
  id: number;
  ap_shipment_id: number | null;
  source_type: string | null;
  source_id: string | null;
};

type BillShipmentSource = Pick<
  GlobalInvoiceDetail,
  'ap_shipment_id' | 'source_type' | 'source_id'
>;

export function shipmentIdFromBill(
  bill: GlobalInvoiceDetail | BillShipmentSource | undefined,
): number | null {
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

export function shipmentIdFromBillPlug(row: BillShipmentPlug): number | null {
  return shipmentIdFromBill(row);
}

export function shipmentIdFromBillDetail(bill: GlobalInvoiceDetail | undefined): number | null {
  return shipmentIdFromBill(bill);
}

export async function resolveShipmentIdsFromBillIds(billIds: number[]): Promise<number[]> {
  const ids = [...new Set(billIds.filter((id) => Number.isFinite(id) && id > 0))];
  if (ids.length === 0) return [];

  const { data, error } = await supabase
    .from('bills')
    .select('id, ap_shipment_id, source_type, source_id')
    .in('id', ids);

  if (error) throw error;

  const shipmentIds = new Set<number>();
  for (const row of data ?? []) {
    const sid = shipmentIdFromBillPlug(row as BillShipmentPlug);
    if (sid != null) shipmentIds.add(sid);
  }
  return [...shipmentIds].sort((a, b) => a - b);
}

export async function resolveShipmentIdsForApPayout(options: {
  shipmentId?: number | null;
  allocationBillIds?: number[];
}): Promise<number[]> {
  if (options.shipmentId != null && Number.isFinite(options.shipmentId)) {
    return [options.shipmentId];
  }
  if (options.allocationBillIds?.length) {
    return resolveShipmentIdsFromBillIds(options.allocationBillIds);
  }
  return [];
}
