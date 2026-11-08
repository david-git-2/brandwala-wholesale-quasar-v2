import { supabase } from 'src/boot/supabase';
import {
  billsRepository,
  type BillDetailBundle,
} from 'src/modules/bills_pays/repositories/billsRepository';
import { parseBillDetailBundleFromRpc } from 'src/modules/sales_invoice/repositories/invoiceRepository';
import type { BillNetBalances } from 'src/modules/bills_pays/types/billBalances';
import {
  LEGACY_SHIPMENT_AP_KINDS,
  SHIPMENT_AP_COST_BUCKETS,
  type ShipmentApKind,
} from '../constants/shipmentApBuckets';
import {
  parseShipmentApFxSnapshot,
  type ShipmentApBillRow,
  type ShipmentApFxSnapshot,
  type ShipmentSettingsFinanceBundle,
} from './shipmentApBillsRepository';

export type ShipmentMoneyKernelBundle = ShipmentSettingsFinanceBundle;

const shipmentApBucketFromKey = (key: string | null | undefined): ShipmentApKind | null => {
  if (!key?.trim()) return null;
  const bucket = key.includes(':') ? key.split(':')[0] : key;
  if (
    (SHIPMENT_AP_COST_BUCKETS as readonly string[]).includes(bucket)
    || (LEGACY_SHIPMENT_AP_KINDS as readonly string[]).includes(bucket)
  ) {
    return bucket as ShipmentApKind;
  }
  return null;
};

export const parseShipmentApBillRow = (raw: unknown): ShipmentApBillRow => {
  const o = raw && typeof raw === 'object' ? (raw as Record<string, unknown>) : {};
  const nb = o.net_balances;
  const sourceKey = (o.source_key as string | null) ?? null;
  const apKindRaw = (o.ap_kind as string | null) ?? null;
  const apKind =
    (apKindRaw as ShipmentApKind | null) ?? shipmentApBucketFromKey(sourceKey);
  return {
    id: Number(o.id),
    invoice_no: String(o.invoice_no ?? ''),
    ap_kind: apKind,
    ap_shipment_id:
      o.ap_shipment_id != null && Number.isFinite(Number(o.ap_shipment_id))
        ? Number(o.ap_shipment_id)
        : null,
    source_type: (o.source_type as string | null) ?? null,
    source_id: (o.source_id as string | null) ?? null,
    source_key: sourceKey,
    invoice_status: String(o.invoice_status ?? ''),
    payment_status: (o.payment_status as string | null) ?? null,
    total_amount: Number(o.total_amount) || 0,
    due_amount: Number(o.due_amount) || 0,
    net_balances:
      nb && typeof nb === 'object' ? (nb as BillNetBalances) : undefined,
  };
};

export const parseShipmentApBillRows = (raw: unknown): ShipmentApBillRow[] => {
  if (!Array.isArray(raw)) return [];
  return raw
    .map(parseShipmentApBillRow)
    .filter((row) => Number.isFinite(row.id) && row.id > 0);
};

const isShipmentLinkedApRow = (
  raw: unknown,
  shipmentId: number,
): boolean => {
  const o = raw && typeof raw === 'object' ? (raw as Record<string, unknown>) : {};
  if (o.invoice_type !== 'ap' || o.document_kind !== 'standard') return false;
  const sid = String(shipmentId);
  if (o.source_type === 'shipment_cost' && String(o.source_id ?? '') === sid) return true;
  if (Number(o.ap_shipment_id) === shipmentId) return true;
  return false;
};

const mergeApBillRows = (...groups: ShipmentApBillRow[][]): ShipmentApBillRow[] => {
  const byId = new Map<number, ShipmentApBillRow>();
  for (const group of groups) {
    for (const row of group) {
      if (!Number.isFinite(row.id) || row.id <= 0) continue;
      byId.set(row.id, row);
    }
  }
  return [...byId.values()];
};

async function loadApBillsForShipment(
  shipmentId: number,
  contextTenantId: number | null | undefined,
  fromBundle: ShipmentApBillRow[],
): Promise<ShipmentApBillRow[]> {
  if (!contextTenantId) return fromBundle;
  try {
    const listParams = {
      parentTenantId: contextTenantId,
      sourceType: 'shipment_cost',
      sourceId: String(shipmentId),
    } as const;
    const [strictRaw, looseRaw] = await Promise.all([
      billsRepository.listBillsForSource({
        ...listParams,
        apShipmentBucketsOnly: true,
      }),
      billsRepository.listBillsForSource({
        ...listParams,
        apShipmentBucketsOnly: false,
      }),
    ]);
    const listed = mergeApBillRows(
      Array.isArray(strictRaw) ? strictRaw.map(parseShipmentApBillRow) : [],
      (Array.isArray(looseRaw) ? looseRaw : [])
        .filter((row) => isShipmentLinkedApRow(row, shipmentId))
        .map(parseShipmentApBillRow),
    );
    return mergeApBillRows(fromBundle, listed);
  } catch {
    return fromBundle;
  }
}

export async function fetchShipmentMoneyKernelBundle(
  shipmentId: number,
  contextTenantId?: number | null,
): Promise<ShipmentMoneyKernelBundle> {
  const { data, error } = await supabase.rpc('get_shipment_money_kernel_bundle', {
    p_shipment_id: shipmentId,
  });
  if (error) throw error;
  const payload = data && typeof data === 'object' ? (data as Record<string, unknown>) : {};
  const bundleApBills = Array.isArray(payload.ap_bills)
    ? payload.ap_bills.map(parseShipmentApBillRow)
    : [];
  const apBills = await loadApBillsForShipment(shipmentId, contextTenantId, bundleApBills);
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
