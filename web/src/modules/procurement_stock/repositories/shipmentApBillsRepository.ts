import { supabase } from 'src/boot/supabase';

export type ShipmentApKind = 'vendor' | 'cargo' | 'local';

export type ShipmentApBillRow = {
  id: number;
  invoice_no: string;
  ap_kind: ShipmentApKind;
  invoice_status: string;
  payment_status: string | null;
  total_amount: number;
  due_amount: number;
};

export async function syncShipmentApBills(shipmentId: number): Promise<void> {
  const { error } = await supabase.rpc('sync_shipment_ap_bills', {
    p_shipment_id: shipmentId,
  });
  if (error) throw error;
}

export async function listShipmentApBills(shipmentId: number): Promise<ShipmentApBillRow[]> {
  const { data, error } = await supabase
    .from('bills')
    .select('id, invoice_no, ap_kind, invoice_status, payment_status, total_amount, due_amount')
    .eq('ap_shipment_id', shipmentId)
    .eq('invoice_type', 'ap')
    .neq('invoice_status', 'voided')
    .in('ap_kind', ['vendor', 'cargo', 'local']);

  if (error) throw error;
  return (data ?? []) as ShipmentApBillRow[];
}
