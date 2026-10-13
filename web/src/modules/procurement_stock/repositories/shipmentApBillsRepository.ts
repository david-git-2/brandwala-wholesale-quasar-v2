import { supabase } from 'src/boot/supabase';
import {
  LEGACY_SHIPMENT_AP_KINDS,
  SHIPMENT_AP_COST_BUCKETS,
  type ShipmentApKind,
} from '../constants/shipmentApBuckets';

export type { ShipmentApKind };

export type ShipmentApBillRow = {
  id: number;
  invoice_no: string;
  ap_kind: ShipmentApKind | null;
  source_type: string | null;
  source_id: string | null;
  source_key: string | null;
  invoice_status: string;
  payment_status: string | null;
  total_amount: number;
  due_amount: number;
};

export const shipmentApBillBucket = (bill: ShipmentApBillRow): ShipmentApKind | null => {
  const key = bill.source_key ?? bill.ap_kind;
  if (!key) return null;
  return key as ShipmentApKind;
};

export type ShipmentApBucketPaidTotals = {
  bdt_paid: number;
  foreign_paid: number;
  conversion_rate: number;
  payment_count: number;
};

export type ShipmentApFxSnapshot = {
  product_conversion_rate: number;
  cargo_conversion_rate: number;
  cargo_rate: number;
  transaction_rate: number;
  goods_bdt: number;
  freight_bdt: number;
  product_foreign: number;
  cargo_foreign: number;
  material: ShipmentApBucketPaidTotals;
  freight: ShipmentApBucketPaidTotals;
};

const num = (v: unknown, fallback = 0): number => {
  const n = Number(v);
  return Number.isFinite(n) ? n : fallback;
};

const parseBucketPaid = (raw: unknown): ShipmentApBucketPaidTotals => {
  const o = raw && typeof raw === 'object' ? (raw as Record<string, unknown>) : {};
  return {
    bdt_paid: num(o.bdt_paid),
    foreign_paid: num(o.foreign_paid),
    conversion_rate: num(o.conversion_rate, 1),
    payment_count: num(o.payment_count),
  };
};

/** Pay-weighted FX for landed cost — same payload as `refresh_global_shipment_fx_from_ap_payments`. */
export async function fetchShipmentApFxSnapshot(
  shipmentId: number,
): Promise<ShipmentApFxSnapshot | null> {
  const { data, error } = await supabase.rpc('refresh_global_shipment_fx_from_ap_payments', {
    p_shipment_id: shipmentId,
  });
  if (error || !data || typeof data !== 'object') return null;
  const fx = data as Record<string, unknown>;
  return {
    product_conversion_rate: num(fx.product_conversion_rate, 1),
    cargo_conversion_rate: num(fx.cargo_conversion_rate, 1),
    cargo_rate: num(fx.cargo_rate),
    transaction_rate: num(fx.transaction_rate ?? fx.blended_rate, 1),
    goods_bdt: num(fx.goods_bdt),
    freight_bdt: num(fx.freight_bdt),
    product_foreign: num(fx.product_foreign),
    cargo_foreign: num(fx.cargo_foreign),
    material: parseBucketPaid(fx.material),
    freight: parseBucketPaid(fx.freight),
  };
}

const LISTABLE_AP_KINDS = [...SHIPMENT_AP_COST_BUCKETS, ...LEGACY_SHIPMENT_AP_KINDS];

export async function syncShipmentApBills(shipmentId: number): Promise<void> {
  const { error } = await supabase.rpc('sync_shipment_ap_bills', {
    p_shipment_id: shipmentId,
  });
  if (error) throw error;
}

export async function issueShipmentApBillForKind(
  shipmentId: number,
  apKind: ShipmentApKind,
): Promise<number> {
  const { data, error } = await supabase.rpc('issue_shipment_ap_bill_for_kind', {
    p_shipment_id: shipmentId,
    p_ap_kind: apKind,
  });
  if (error) throw error;
  return Number(data);
}

export async function listShipmentApBills(shipmentId: number): Promise<ShipmentApBillRow[]> {
  const sid = String(shipmentId);
  const { data, error } = await supabase
    .from('bills')
    .select(
      'id, invoice_no, ap_kind, source_type, source_id, source_key, invoice_status, payment_status, total_amount, due_amount',
    )
    .eq('invoice_type', 'ap')
    .eq('document_kind', 'standard')
    .neq('invoice_status', 'voided')
    .or(
      `and(source_type.eq.shipment_cost,source_id.eq.${sid}),ap_shipment_id.eq.${shipmentId}`,
    );

  if (error) throw error;
  const rows = (data ?? []) as ShipmentApBillRow[];
  return rows.filter((row) => {
    const bucket = shipmentApBillBucket(row);
    return bucket != null && LISTABLE_AP_KINDS.includes(bucket);
  });
}

export function findShipmentApBill(
  bills: ShipmentApBillRow[],
  kind: ShipmentApKind,
): ShipmentApBillRow | null {
  return bills.find((b) => shipmentApBillBucket(b) === kind) ?? null;
}
