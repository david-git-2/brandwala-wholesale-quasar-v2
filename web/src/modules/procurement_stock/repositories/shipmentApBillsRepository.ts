import { supabase } from 'src/boot/supabase';

export async function syncShipmentApBills(shipmentId: number): Promise<void> {
  const { error } = await supabase.rpc('sync_shipment_ap_bills', {
    p_shipment_id: shipmentId,
  });
  if (error) throw error;
}
