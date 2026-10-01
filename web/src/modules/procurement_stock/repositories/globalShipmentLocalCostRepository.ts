import { supabase } from 'src/boot/supabase';
import type { GlobalShipmentLocalCost } from '../types/shipmentLocalCost';

const db = supabase as any;

export type UpsertShipmentLocalCostPayload = {
  id?: number | null;
  parent_tenant_id: number;
  shipment_id: number;
  description: string;
  amount: number;
  section_id?: number | null;
  currency_id?: number | null;
};

const listByShipmentId = async (shipmentId: number): Promise<GlobalShipmentLocalCost[]> => {
  const { data, error } = await db
    .from('global_shipment_local_costs')
    .select('*')
    .eq('shipment_id', shipmentId)
    .order('id', { ascending: true });

  if (error) throw error;
  return (data as GlobalShipmentLocalCost[] | null) ?? [];
};

const create = async (payload: UpsertShipmentLocalCostPayload): Promise<GlobalShipmentLocalCost> => {
  const { data, error } = await db
    .from('global_shipment_local_costs')
    .insert([
      {
        parent_tenant_id: payload.parent_tenant_id,
        shipment_id: payload.shipment_id,
        description: payload.description.trim(),
        amount: payload.amount,
        section_id: payload.section_id ?? null,
        currency_id: payload.currency_id ?? null,
      },
    ])
    .select('*')
    .single();

  if (error) throw error;
  return data as GlobalShipmentLocalCost;
};

const update = async (
  id: number,
  payload: Pick<UpsertShipmentLocalCostPayload, 'description' | 'amount' | 'section_id' | 'currency_id'>,
): Promise<GlobalShipmentLocalCost> => {
  const { data, error } = await db
    .from('global_shipment_local_costs')
    .update({
      description: payload.description.trim(),
      amount: payload.amount,
      section_id: payload.section_id ?? null,
      currency_id: payload.currency_id ?? null,
    })
    .eq('id', id)
    .select('*')
    .single();

  if (error) throw error;
  return data as GlobalShipmentLocalCost;
};

const remove = async (id: number): Promise<void> => {
  const { error } = await db.from('global_shipment_local_costs').delete().eq('id', id);
  if (error) throw error;
};

export const globalShipmentLocalCostRepository = {
  listByShipmentId,
  create,
  update,
  remove,
};
