import { supabase } from 'src/boot/supabase';
import type {
  GlobalShipmentCostEntry,
  ReviseShipmentCostEntryInput,
  UpsertShipmentCostEntryPayload,
} from '../types/shipmentCostEntry';
import type { GlobalShipmentItem } from '../repositories/globalShipmentRepository';

const db = supabase as any;

export interface SaveShipmentCostEntriesOptions {
  deleteIds?: number[];
  receivedWeight?: number | null;
  totalWeightKg?: number | null;
}

export interface SaveShipmentCostEntriesResult {
  cost_entries: GlobalShipmentCostEntry[];
  items: GlobalShipmentItem[];
  items_stamped: number;
  shipment: {
    id: number;
    received_weight: number | null;
    total_weight_kg: number | null;
    updated_at: string;
  } | null;
}

const listByShipmentId = async (shipmentId: number): Promise<GlobalShipmentCostEntry[]> => {
  const { data, error } = await db.rpc('list_global_shipment_cost_entries', {
    p_shipment_id: shipmentId,
  });
  if (error) throw error;
  return (data as GlobalShipmentCostEntry[] | null) ?? [];
};

/** Idempotent seed of product+cargo from header rates when entries are empty. */
const ensureFromHeader = async (shipmentId: number): Promise<void> => {
  const { error } = await db.rpc('ensure_global_shipment_cost_entries_from_header', {
    p_shipment_id: shipmentId,
  });
  if (error) throw error;
};

const saveBatch = async (
  shipmentId: number,
  entries: UpsertShipmentCostEntryPayload[],
  options: SaveShipmentCostEntriesOptions = {},
): Promise<SaveShipmentCostEntriesResult> => {
  const rpcEntries = entries.map((e) => ({
    id: e.id ?? null,
    cost_bucket: e.cost_bucket,
    cost_component: e.cost_component,
    is_capitalizable: e.is_capitalizable ?? true,
    description: e.description ?? null,
    amount: e.amount,
    currency_id: e.currency_id ?? null,
    metadata: e.metadata ?? {},
    section_id: e.section_id ?? null,
  }));

  const { data, error } = await db.rpc('save_global_shipment_cost_entries', {
    p_shipment_id: shipmentId,
    p_entries: rpcEntries,
    p_delete_ids: options.deleteIds ?? [],
    p_received_weight: options.receivedWeight ?? null,
    p_total_weight_kg: options.totalWeightKg ?? null,
  });
  if (error) throw error;

  const result = data as {
    cost_entries: GlobalShipmentCostEntry[];
    items: GlobalShipmentItem[];
    items_stamped: number;
    shipment: SaveShipmentCostEntriesResult['shipment'];
  };

  return {
    cost_entries: result.cost_entries ?? [],
    items: result.items ?? [],
    items_stamped: result.items_stamped ?? 0,
    shipment: result.shipment ?? null,
  };
};

const upsert = async (payload: UpsertShipmentCostEntryPayload): Promise<GlobalShipmentCostEntry> => {
  const { data, error } = await db.rpc('upsert_global_shipment_cost_entry', {
    p_shipment_id: payload.shipment_id,
    p_cost_bucket: payload.cost_bucket,
    p_cost_component: payload.cost_component,
    p_amount: payload.amount,
    p_currency_id: payload.currency_id ?? null,
    p_metadata: payload.metadata ?? {},
    p_section_id: payload.section_id ?? null,
    p_id: payload.id ?? null,
    p_description: payload.description ?? null,
    p_is_capitalizable: payload.is_capitalizable ?? true,
  });
  if (error) throw error;
  return data as GlobalShipmentCostEntry;
};

const remove = async (id: number): Promise<void> => {
  const { error } = await db.rpc('delete_global_shipment_cost_entry', { p_id: id });
  if (error) throw error;
};

/** Post-finalize only — replaces entries and re-stamps landed_cost_bdt. No wallet. */
const revise = async (
  shipmentId: number,
  entries: ReviseShipmentCostEntryInput[],
): Promise<{ shipment_id: number; items_stamped: number; wallet_posted: boolean }> => {
  const { data, error } = await db.rpc('revise_global_shipment_costs', {
    p_shipment_id: shipmentId,
    p_entries: entries,
  });
  if (error) throw error;
  return data as { shipment_id: number; items_stamped: number; wallet_posted: boolean };
};

export const globalShipmentCostEntryRepository = {
  listByShipmentId,
  ensureFromHeader,
  saveBatch,
  upsert,
  remove,
  revise,
};
