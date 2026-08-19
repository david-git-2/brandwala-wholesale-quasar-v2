import { supabase } from 'src/boot/supabase';
import type {
  CreateShipmentSectionPayload,
  ShipmentSection,
  UpdateShipmentSectionPayload,
} from '../types/shipmentSection';

const db = supabase as any;

const listByShipmentId = async (shipmentId: number): Promise<ShipmentSection[]> => {
  const { data, error } = await db
    .from('global_shipment_sections')
    .select(`
      *,
      vendor:vendors(*)
    `)
    .eq('shipment_id', shipmentId)
    .order('sort_order', { ascending: true })
    .order('id', { ascending: true });

  if (error) throw error;
  return (data as ShipmentSection[] | null) ?? [];
};

const getById = async (id: number): Promise<ShipmentSection> => {
  const { data, error } = await db
    .from('global_shipment_sections')
    .select(`
      *,
      vendor:vendors(*)
    `)
    .eq('id', id)
    .single();

  if (error) throw error;
  return data as ShipmentSection;
};

const create = async (payload: CreateShipmentSectionPayload): Promise<ShipmentSection> => {
  const { data, error } = await db
    .from('global_shipment_sections')
    .insert([
      {
        parent_tenant_id: payload.parent_tenant_id,
        shipment_id: payload.shipment_id,
        vendor_id: payload.vendor_id,
        title: payload.title.trim(),
        sort_order: payload.sort_order ?? 0,
        metadata: payload.metadata ?? {},
      },
    ])
    .select(`
      *,
      vendor:vendors(*)
    `)
    .single();

  if (error) throw error;
  return data as ShipmentSection;
};

const update = async (
  id: number,
  payload: UpdateShipmentSectionPayload,
): Promise<ShipmentSection> => {
  const patch: Record<string, unknown> = {};
  if (payload.title !== undefined) patch.title = payload.title.trim();
  if (payload.vendor_id !== undefined) patch.vendor_id = payload.vendor_id;
  if (payload.sort_order !== undefined) patch.sort_order = payload.sort_order;
  if (payload.metadata !== undefined) patch.metadata = payload.metadata;

  const { data, error } = await db
    .from('global_shipment_sections')
    .update(patch)
    .eq('id', id)
    .select(`
      *,
      vendor:vendors(*)
    `)
    .single();

  if (error) throw error;
  return data as ShipmentSection;
};

const remove = async (id: number): Promise<void> => {
  const { error } = await db.from('global_shipment_sections').delete().eq('id', id);
  if (error) throw error;
};

const reorder = async (shipmentId: number, sectionIds: number[]): Promise<void> => {
  const { error } = await db.rpc('reorder_shipment_sections', {
    p_shipment_id: shipmentId,
    p_section_ids: sectionIds,
  });
  if (error) throw error;
};

export const shipmentSectionRepository = {
  listByShipmentId,
  getById,
  create,
  update,
  delete: remove,
  reorder,
};
