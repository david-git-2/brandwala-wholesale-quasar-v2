import type { BillNetBalances } from 'src/modules/bills_pays/types/billBalances';
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
  net_balances?: BillNetBalances;
};

export const shipmentApBillBucket = (bill: ShipmentApBillRow): ShipmentApKind | null => {
  const key = bill.source_key ?? bill.ap_kind;
  if (!key) return null;
  const bucket = key.includes(':') ? key.split(':')[0] : key;
  if (
    (SHIPMENT_AP_COST_BUCKETS as readonly string[]).includes(bucket)
    || (LEGACY_SHIPMENT_AP_KINDS as readonly string[]).includes(bucket)
  ) {
    return bucket as ShipmentApKind;
  }
  return key as ShipmentApKind;
};

export const shipmentApBillPlugCurrency = (bill: ShipmentApBillRow): string | null => {
  const key = bill.source_key ?? bill.ap_kind;
  if (!key || !key.includes(':')) return null;
  return key.split(':').slice(1).join(':').toUpperCase();
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

export function parseShipmentApFxSnapshot(raw: unknown): ShipmentApFxSnapshot | null {
  if (!raw || typeof raw !== 'object') return null;
  const fx = raw as Record<string, unknown>;
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

export type ShipmentSettingsFinanceBundle = {
  apBills: ShipmentApBillRow[];
  apFx: ShipmentApFxSnapshot | null;
  costEntries: unknown[];
};

export function findShipmentApBill(
  bills: ShipmentApBillRow[],
  kind: ShipmentApKind,
  opts?: { currencyCode?: string | null },
): ShipmentApBillRow | null {
  const matches = bills.filter((b) => shipmentApBillBucket(b) === kind);
  if (matches.length === 0) return null;
  if (matches.length === 1) return matches[0];
  const ccy = opts?.currencyCode?.trim().toUpperCase();
  if (ccy) {
    const byCurrency = matches.find((b) => {
      const plug = (b.source_key ?? b.ap_kind ?? '').toUpperCase();
      return plug === `${kind}:${ccy}` || plug === `${kind.toUpperCase()}:${ccy}`;
    });
    if (byCurrency) return byCurrency;
  }
  return matches[0];
}

/** @deprecated Use fetchShipmentMoneyKernelBundle from shipmentMoneyKernelRepository */
export {
  fetchShipmentMoneyKernelBundle as fetchShipmentSettingsFinanceBundle,
  syncShipmentApBills,
  issueShipmentApBillForKind,
} from './shipmentMoneyKernelRepository';
