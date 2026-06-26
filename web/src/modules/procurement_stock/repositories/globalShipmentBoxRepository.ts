import { supabase } from 'src/boot/supabase'
import type { Tables } from 'src/types/supabase'

export type GlobalShipmentBox = Tables<'global_shipment_boxes'>

const db = supabase as any

const listByShipmentId = async (shipmentId: number): Promise<GlobalShipmentBox[]> => {
  const { data, error } = await db
    .from('global_shipment_boxes')
    .select('*')
    .eq('shipment_id', shipmentId)
    .order('box_number', { ascending: true })

  if (error) throw error
  return (data as GlobalShipmentBox[] | null) ?? []
}

const create = async (
  payload: Omit<GlobalShipmentBox, 'id' | 'created_at' | 'updated_at'>,
): Promise<GlobalShipmentBox> => {
  const { data, error } = await db
    .from('global_shipment_boxes')
    .insert([payload])
    .select()
    .single()

  if (error) throw error
  return data as GlobalShipmentBox
}

const update = async (
  id: number,
  payload: Partial<Pick<GlobalShipmentBox, 'box_number' | 'weight_kg'>>,
): Promise<GlobalShipmentBox> => {
  const { data, error } = await db
    .from('global_shipment_boxes')
    .update(payload)
    .eq('id', id)
    .select()
    .single()

  if (error) throw error
  return data as GlobalShipmentBox
}

const remove = async (id: number): Promise<void> => {
  const { error } = await db.from('global_shipment_boxes').delete().eq('id', id)
  if (error) throw error
}

export const globalShipmentBoxRepository = {
  listByShipmentId,
  create,
  update,
  delete: remove,
}
