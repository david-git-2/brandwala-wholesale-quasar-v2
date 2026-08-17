import { supabase } from 'src/boot/supabase';
import type {
  GlobalShipmentCostEntry,
  ReviseShipmentCostEntryInput,
  UpsertShipmentCostEntryPayload,
} from '../types/shipmentCostEntry';

const db = supabase as any;

/** Shipment is source_* only — never a wallet payee. */
const assertPayeeAllowed = (entityType: string | null | undefined) => {
  if (entityType === 'shipment') {
    throw new Error("Payee entity_type cannot be 'shipment'");
  }
};

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

const upsert = async (payload: UpsertShipmentCostEntryPayload): Promise<GlobalShipmentCostEntry> => {
  assertPayeeAllowed(payload.entity_type);
  const { data, error } = await db.rpc('upsert_global_shipment_cost_entry', {
    p_shipment_id: payload.shipment_id,
    p_cost_type: payload.cost_type,
    p_amount: payload.amount,
    p_exchange_rate: payload.exchange_rate ?? 1,
    p_currency_id: payload.currency_id ?? null,
    p_payment_source: payload.payment_source ?? null,
    p_entity_type: payload.entity_type ?? null,
    p_entity_id: payload.entity_id ?? null,
    p_allocation: payload.allocation ?? null,
    p_metadata: payload.metadata ?? {},
    p_id: payload.id ?? null,
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
  for (const e of entries) {
    assertPayeeAllowed(e.entity_type);
  }
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
  upsert,
  remove,
  revise,
};
