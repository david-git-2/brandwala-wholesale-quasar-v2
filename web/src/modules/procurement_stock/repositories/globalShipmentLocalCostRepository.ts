import { supabase } from 'src/boot/supabase';

const db = supabase as any;
import { LOCAL_COST_BUCKET, type GlobalShipmentCostEntry } from '../types/shipmentCostEntry';
import type { GlobalShipmentLocalCost } from '../types/shipmentLocalCost';
import { globalShipmentCostEntryRepository } from './globalShipmentCostEntryRepository';

export type UpsertShipmentLocalCostPayload = {
  parent_tenant_id: number;
  shipment_id: number;
  description: string;
  amount: number;
  section_id?: number | null;
  currency_id?: number | null;
};

const mapEntryToLocal = (entry: GlobalShipmentCostEntry): GlobalShipmentLocalCost => {
  const meta = (entry.metadata ?? {}) as { description?: string };
  return {
    id: entry.id,
    parent_tenant_id: entry.parent_tenant_id,
    shipment_id: entry.shipment_id,
    section_id: entry.section_id,
    description: entry.description?.trim() || meta.description?.trim() || '',
    amount: Number(entry.amount),
    currency_id: entry.currency_id,
    created_at: entry.created_at,
    updated_at: entry.updated_at,
  };
};

const listByShipmentId = async (shipmentId: number): Promise<GlobalShipmentLocalCost[]> => {
  const entries = await globalShipmentCostEntryRepository.listByShipmentId(shipmentId);
  return entries.filter((e) => e.cost_bucket === LOCAL_COST_BUCKET && !e.is_capitalizable).map(mapEntryToLocal);
};

const upsertLocal = async (
  shipmentId: number,
  payload: {
    id?: number | null;
    description: string;
    amount: number;
    section_id?: number | null;
    currency_id?: number | null;
  },
): Promise<GlobalShipmentLocalCost> => {
  const entry = await globalShipmentCostEntryRepository.upsert({
    shipment_id: shipmentId,
    cost_bucket: LOCAL_COST_BUCKET,
    cost_component: 'misc',
    is_capitalizable: false,
    description: payload.description,
    amount: payload.amount,
    currency_id: payload.currency_id ?? null,
    metadata: { description: payload.description },
    section_id: payload.section_id ?? null,
    id: payload.id ?? null,
  });
  return mapEntryToLocal(entry);
};

const create = async (payload: UpsertShipmentLocalCostPayload): Promise<GlobalShipmentLocalCost> =>
  upsertLocal(payload.shipment_id, {
    description: payload.description,
    amount: payload.amount,
    section_id: payload.section_id,
    currency_id: payload.currency_id,
  });

const update = async (
  id: number,
  payload: Pick<UpsertShipmentLocalCostPayload, 'description' | 'amount' | 'section_id' | 'currency_id'>,
): Promise<GlobalShipmentLocalCost> => {
  const { data: row, error } = await db
    .from('global_shipment_cost_entries')
    .select('shipment_id')
    .eq('id', id)
    .eq('cost_bucket', LOCAL_COST_BUCKET)
    .maybeSingle();
  if (error) throw error;
  if (!row?.shipment_id) throw new Error('Local cost not found');

  return upsertLocal(row.shipment_id, {
    id,
    description: payload.description,
    amount: payload.amount,
    section_id: payload.section_id,
    currency_id: payload.currency_id,
  });
};

const remove = async (id: number): Promise<void> => {
  await globalShipmentCostEntryRepository.delete(id);
};

export const globalShipmentLocalCostRepository = {
  listByShipmentId,
  create,
  update,
  remove,
};
