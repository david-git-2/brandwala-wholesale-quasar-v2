import { supabase } from 'src/boot/supabase';
import type { Json } from 'src/types/database.types';
import type { ShipmentApKind } from '../constants/shipmentApBuckets';
import { issueShipmentApBillV2 } from './shipmentMoneyKernelRepository';

export type ShipmentApBillLineInput = {
  cost_component: string;
  amount: number;
  description?: string | null;
  is_capitalizable?: boolean;
};

export type CreateShipmentApBillPayload = {
  currency_code: string;
  lines: ShipmentApBillLineInput[];
  note?: string | null;
  source_key_suffix?: string | null;
};

const db = supabase as any;

const mapRpcBillLinesToInputs = (lines: unknown): ShipmentApBillLineInput[] => {
  if (!Array.isArray(lines)) return [];
  return lines
    .map((raw) => {
      if (!raw || typeof raw !== 'object') return null;
      const row = raw as Record<string, unknown>;
      const meta = row.meta && typeof row.meta === 'object' ? (row.meta as Record<string, unknown>) : {};
      const amount = Number(row.line_total ?? row.unit_price);
      const cost_component = String(meta.cost_component ?? 'misc');
      if (!Number.isFinite(amount) || amount <= 0) return null;
      return {
        cost_component,
        amount,
        description: (row.description as string | null) ?? null,
      } satisfies ShipmentApBillLineInput;
    })
    .filter((line): line is ShipmentApBillLineInput => line != null);
};

export const shipmentApBillV2Repository = {
  async create(shipmentId: number, bucket: ShipmentApKind, payload: CreateShipmentApBillPayload) {
    const { data, error } = await db.rpc('create_shipment_ap_bill_v2', {
      p_shipment_id: shipmentId,
      p_bucket: bucket,
      p_payload: payload as Json,
    });
    if (error) throw error;
    return data as Record<string, unknown>;
  },

  async update(shipmentId: number, billId: number, payload: Partial<CreateShipmentApBillPayload>) {
    const { data, error } = await db.rpc('update_shipment_ap_bill_v2', {
      p_shipment_id: shipmentId,
      p_bill_id: billId,
      p_payload: payload as Json,
    });
    if (error) throw error;
    return data as Record<string, unknown>;
  },

  async loadDraftCostLines(booksTenantId: number, billId: number): Promise<ShipmentApBillLineInput[]> {
    const { data, error } = await db.rpc('rpc_get_bill', {
      p_tenant_id: booksTenantId,
      p_bill_id: billId,
      p_include: ['lines'],
    });
    if (error) throw error;
    const payload = data as Record<string, unknown> | null;
    return mapRpcBillLinesToInputs(payload?.lines);
  },

  async voidDraft(shipmentId: number, billId: number) {
    const { data, error } = await db.rpc('void_shipment_ap_bill_v2', {
      p_shipment_id: shipmentId,
      p_bill_id: billId,
    });
    if (error) throw error;
    return data as Record<string, unknown>;
  },

  async issue(shipmentId: number, billId: number) {
    return issueShipmentApBillV2(shipmentId, billId);
  },
};
