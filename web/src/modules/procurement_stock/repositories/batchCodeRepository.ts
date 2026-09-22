import { supabase } from 'src/boot/supabase';
import type { Tables } from 'src/types/supabase';

export type BatchCodeList = Tables<'batch_code_lists'>;
export type BatchCodeItem = Tables<'batch_code_items'>;

export type BatchCodeListRow = BatchCodeList & {
  vendor: { id: number; name: string } | null;
  shipment: { id: number; name: string; tenant_shipment_id: number | null } | null;
  batch_code_items: Array<{ count: number }>;
};

const db = supabase as any;

const listByParentTenantId = async (parentTenantId: number): Promise<BatchCodeListRow[]> => {
  const { data, error } = await db
    .from('batch_code_lists')
    .select(
      '*, vendor:vendors(id, name), shipment:global_shipments(id, name, tenant_shipment_id), batch_code_items(count)',
    )
    .eq('parent_tenant_id', parentTenantId)
    .order('updated_at', { ascending: false });

  if (error) throw error;
  return (data as BatchCodeListRow[] | null) ?? [];
};

const getById = async (id: number): Promise<BatchCodeListRow | null> => {
  const { data, error } = await db
    .from('batch_code_lists')
    .select(
      '*, vendor:vendors(id, name), shipment:global_shipments(id, name, tenant_shipment_id), batch_code_items(count)',
    )
    .eq('id', id)
    .maybeSingle();

  if (error) throw error;
  return (data as BatchCodeListRow | null) ?? null;
};

const getByShipmentId = async (shipmentId: number): Promise<BatchCodeList | null> => {
  const { data, error } = await db
    .from('batch_code_lists')
    .select('*')
    .eq('shipment_id', shipmentId)
    .maybeSingle();

  if (error) throw error;
  return (data as BatchCodeList | null) ?? null;
};

const createList = async (
  payload: Omit<BatchCodeList, 'id' | 'created_at' | 'updated_at'>,
): Promise<BatchCodeList> => {
  const { data, error } = await db.from('batch_code_lists').insert([payload]).select().single();
  if (error) throw error;
  return data as BatchCodeList;
};

const updateList = async (
  id: number,
  payload: Partial<Pick<BatchCodeList, 'name' | 'vendor_id' | 'shipment_id'>>,
): Promise<BatchCodeList> => {
  const { data, error } = await db
    .from('batch_code_lists')
    .update(payload)
    .eq('id', id)
    .select()
    .single();

  if (error) throw error;
  return data as BatchCodeList;
};

const listItemsByListId = async (listId: number): Promise<BatchCodeItem[]> => {
  const { data, error } = await db
    .from('batch_code_items')
    .select('*')
    .eq('list_id', listId)
    .order('id', { ascending: true });

  if (error) throw error;
  return (data as BatchCodeItem[] | null) ?? [];
};

const createItem = async (
  payload: Omit<BatchCodeItem, 'id' | 'created_at' | 'updated_at'>,
): Promise<BatchCodeItem> => {
  const { data, error } = await db.from('batch_code_items').insert([payload]).select().single();
  if (error) throw error;
  return data as BatchCodeItem;
};

const updateItem = async (
  id: number,
  payload: Partial<
    Pick<
      BatchCodeItem,
      'barcode' | 'product_code' | 'batch_id' | 'manufacturing_date' | 'expire_date'
    >
  >,
): Promise<BatchCodeItem> => {
  const { data, error } = await db
    .from('batch_code_items')
    .update(payload)
    .eq('id', id)
    .select()
    .single();

  if (error) throw error;
  return data as BatchCodeItem;
};

const deleteItem = async (id: number): Promise<void> => {
  const { error } = await db.from('batch_code_items').delete().eq('id', id);
  if (error) throw error;
};

const deleteList = async (id: number): Promise<void> => {
  const { error } = await db.from('batch_code_lists').delete().eq('id', id);
  if (error) throw error;
};

export type BatchCodePasteRow = Partial<
  Pick<BatchCodeItem, 'barcode' | 'product_code' | 'batch_id' | 'manufacturing_date' | 'expire_date'>
>;

export type BatchCodePasteResult = {
  created: number;
  updated: number;
};

const pasteItems = async (
  listId: number,
  startRowIndex: number,
  rows: BatchCodePasteRow[],
): Promise<BatchCodePasteResult> => {
  const { data, error } = await db.rpc('paste_batch_code_items', {
    p_list_id: listId,
    p_start_row_index: startRowIndex,
    p_rows: rows,
  });

  if (error) throw error;

  const result = (data as { created?: number; updated?: number } | null) ?? {};
  return {
    created: result.created ?? 0,
    updated: result.updated ?? 0,
  };
};

export const batchCodeRepository = {
  listByParentTenantId,
  getById,
  getByShipmentId,
  createList,
  updateList,
  deleteList,
  pasteItems,
  listItemsByListId,
  createItem,
  updateItem,
  deleteItem,
};
