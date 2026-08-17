import { supabase } from 'src/boot/supabase';

export interface ChildStockAtpRow {
  shipment_id: number;
  shipment_name: string;
  tenant_shipment_id?: number | null;
  parent_tenant_id?: number;
  status: string;
  received_date: string | null;
  total_ordered_qty: number;
  total_sellable_qty?: number;
  atp_qty: number;
}

export interface ChildStockAtpResult {
  data: ChildStockAtpRow[];
  total: number;
}

const listChildStockAtp = async (
  childTenantId: number,
  search?: string | null,
  limit = 50,
  offset = 0,
): Promise<ChildStockAtpResult> => {
  const { data, error } = await supabase.rpc('list_child_stock_atp', {
    p_child_tenant_id: childTenantId,
    p_search: search || null,
    p_limit: limit,
    p_offset: offset,
  });

  if (error) throw error;

  const result = data as { data?: ChildStockAtpRow[]; total?: number } | null;
  return {
    data: result?.data ?? [],
    total: result?.total ?? 0,
  };
};

export const childStockRepository = {
  listChildStockAtp,
};
