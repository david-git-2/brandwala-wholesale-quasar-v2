import { supabase } from 'src/boot/supabase';
import type { BillDetailBundle } from 'src/modules/bills_pays/repositories/billsRepository';
import { parseBillDetailBundleFromRpc } from 'src/modules/sales_invoice/repositories/invoiceRepository';
import type { BillNetBalances } from 'src/modules/bills_pays/types/billBalances';
import type { ShipmentApKind } from '../constants/shipmentApBuckets';
import {
  parseShipmentApFxSnapshot,
  type ShipmentApBillRow,
  type ShipmentApFxSnapshot,
  type ShipmentSettingsFinanceBundle,
} from './shipmentApBillsRepository';

export type ShipmentMoneyKernelBundle = ShipmentSettingsFinanceBundle;

const parseApBillRow = (raw: unknown): ShipmentApBillRow => {
  const o = raw && typeof raw === 'object' ? (raw as Record<string, unknown>) : {};
  const nb = o.net_balances;
  return {
    id: Number(o.id),
    invoice_no: String(o.invoice_no ?? ''),
    ap_kind: (o.ap_kind as ShipmentApKind | null) ?? null,
    source_type: (o.source_type as string | null) ?? null,
    source_id: (o.source_id as string | null) ?? null,
    source_key: (o.source_key as string | null) ?? null,
    invoice_status: String(o.invoice_status ?? ''),
    payment_status: (o.payment_status as string | null) ?? null,
    total_amount: Number(o.total_amount) || 0,
    due_amount: Number(o.due_amount) || 0,
    net_balances:
      nb && typeof nb === 'object' ? (nb as BillNetBalances) : undefined,
  };
};

export async function fetchShipmentMoneyKernelBundle(
  shipmentId: number,
): Promise<ShipmentMoneyKernelBundle> {
  const { data, error } = await supabase.rpc('get_shipment_money_kernel_bundle', {
    p_shipment_id: shipmentId,
  });
  if (error) throw error;
  const payload = data && typeof data === 'object' ? (data as Record<string, unknown>) : {};
  const apBills = Array.isArray(payload.ap_bills)
    ? payload.ap_bills.map(parseApBillRow)
    : [];
  const costEntries = Array.isArray(payload.cost_entries) ? payload.cost_entries : [];
  return {
    apBills,
    apFx: parseShipmentApFxSnapshot(payload.ap_fx),
    costEntries,
  };
}

export async function syncShipmentApBills(shipmentId: number): Promise<void> {
  const { error } = await supabase.rpc('sync_shipment_ap_bills', {
    p_shipment_id: shipmentId,
  });
  if (error) throw error;
}

export async function issueShipmentApBillForKind(
  shipmentId: number,
  apKind: ShipmentApKind,
): Promise<BillDetailBundle> {
  const { data, error } = await supabase.rpc('issue_shipment_ap_bill_for_kind', {
    p_shipment_id: shipmentId,
    p_ap_kind: apKind,
  });
  if (error) throw error;
  return parseBillDetailBundleFromRpc(data);
}

export type { ShipmentApFxSnapshot };
