import { supabase } from 'src/boot/supabase';
import type { StockLocation, UpsertStockLocationPayload } from '../types/stockLocation';

const db = supabase as any;

const listStockLocations = async (
  parentTenantId: number,
  includeInactive = true,
): Promise<StockLocation[]> => {
  const { data, error } = await db.rpc('list_stock_locations', {
    p_parent_tenant_id: parentTenantId,
    p_include_inactive: includeInactive,
  });
  if (error) throw error;
  return (data as StockLocation[] | null) ?? [];
};

const upsertStockLocation = async (
  parentTenantId: number,
  payload: UpsertStockLocationPayload,
): Promise<StockLocation> => {
  const { data, error } = await db.rpc('upsert_stock_location', {
    p_parent_tenant_id: parentTenantId,
    p_code: payload.code,
    p_name: payload.name,
    p_kind: payload.kind,
    p_parent_location_id: payload.parent_location_id ?? null,
    p_is_pickable: payload.is_pickable,
    p_sort_order: payload.sort_order,
    p_is_active: payload.is_active,
    p_is_default: payload.is_default ?? false,
    p_id: payload.id ?? null,
  });
  if (error) throw error;
  return data as StockLocation;
};

const setDefaultStockLocation = async (id: number): Promise<StockLocation> => {
  const { data, error } = await db.rpc('set_default_stock_location', { p_id: id });
  if (error) throw error;
  return data as StockLocation;
};

const deleteStockLocation = async (id: number): Promise<void> => {
  const { error } = await db.rpc('delete_stock_location', { p_id: id });
  if (error) throw error;
};

export const stockLocationRepository = {
  listStockLocations,
  upsertStockLocation,
  setDefaultStockLocation,
  deleteStockLocation,
};
