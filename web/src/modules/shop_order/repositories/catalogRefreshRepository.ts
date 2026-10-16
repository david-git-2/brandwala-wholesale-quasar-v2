import { supabase } from 'src/boot/supabase';
import type { CatalogRefreshLogRow } from '../utils/catalogRefreshByVendor';

export async function listCatalogRefreshLog(
  parentTenantId: number,
  limit = 200,
): Promise<CatalogRefreshLogRow[]> {
  const { data, error } = await supabase.rpc('list_catalog_refresh_log', {
    p_parent_tenant_id: parentTenantId,
    p_limit: limit,
  });
  if (error) {
    throw error;
  }
  return (data ?? []) as CatalogRefreshLogRow[];
}
