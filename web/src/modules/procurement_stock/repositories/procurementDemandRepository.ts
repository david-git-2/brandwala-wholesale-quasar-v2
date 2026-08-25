import { supabase } from 'src/boot/supabase';

export type ProcurementDemandStatus = 'procuring' | 'ready_for_shipment' | 'delivered';

export type ProcurementDemandDocumentType = 'shop_order' | 'pbc_costing_file';

export type ProcurementDemandSourceType = 'shop_order_item' | 'pbc_costing_item';

export interface ProcurementDemandVendor {
  id: number | null;
  code: string | null;
  name: string | null;
}

export interface ProcurementPlacement {
  id: number;
  vendor_id: number | null;
  vendor_code: string | null;
  vendor_name: string | null;
  quantity: number;
  notes: string | null;
  placed_at: string;
  placed_by_user_id: string | null;
  global_shipment_item_id: number | null;
}

export interface ProcurementDemandItem {
  source_type: ProcurementDemandSourceType;
  source_id: number;
  product_id: number | null;
  name: string;
  image_url: string | null;
  barcode: string | null;
  product_code: string | null;
  quantity: number;
  need_quantity?: number;
  placed_quantity?: number;
  remaining_quantity?: number;
  placements?: ProcurementPlacement[];
}

export interface ProcurementDemandGroup {
  document_type: ProcurementDemandDocumentType;
  document_id: number;
  document_status: string;
  vendor: ProcurementDemandVendor | null;
  items: ProcurementDemandItem[];
}

export interface ProcurementDemandGroupsMeta {
  tenant_id: number;
  procurement_status: ProcurementDemandStatus;
  sources_included: Array<'shop_order' | 'pbc_costing'>;
  group_count: number;
  item_count: number;
  total_group_count: number;
  limit: number;
  offset: number;
  has_more: boolean;
}

export interface ProcurementDemandGroupsResponse {
  meta: ProcurementDemandGroupsMeta;
  groups: ProcurementDemandGroup[];
}

export interface ListProcurementDemandGroupsParams {
  tenantId: number;
  procurementStatus?: ProcurementDemandStatus;
  search?: string | null;
  childTenantId?: number | null;
  limit?: number;
  offset?: number;
}

export interface RecordProcurementPlacementParams {
  tenantId: number;
  sourceType: ProcurementDemandSourceType;
  sourceId: number;
  quantity: number;
  vendorId?: number | null;
  vendorCode?: string | null;
  notes?: string | null;
}

export interface ProcurementPlacementRow {
  id: number;
  tenant_id: number;
  source_type: ProcurementDemandSourceType;
  source_id: number;
  vendor_id: number | null;
  vendor_code: string | null;
  quantity: number;
  notes: string | null;
  placed_by_user_id: string | null;
  placed_at: string;
  status: string;
  global_shipment_item_id: number | null;
  created_at: string;
  updated_at: string;
}

const listProcurementDemandGroups = async (
  params: ListProcurementDemandGroupsParams,
): Promise<ProcurementDemandGroupsResponse> => {
  const { data, error } = await supabase.rpc('list_procurement_demand_groups', {
    p_tenant_id: params.tenantId,
    p_procurement_status: params.procurementStatus ?? 'procuring',
    p_search: params.search ?? null,
    p_child_tenant_id: params.childTenantId ?? null,
    p_limit: params.limit ?? 50,
    p_offset: params.offset ?? 0,
  });

  if (error) throw error;

  return (data ?? { meta: {}, groups: [] }) as ProcurementDemandGroupsResponse;
};

const recordProcurementPlacement = async (
  params: RecordProcurementPlacementParams,
): Promise<ProcurementPlacementRow> => {
  const { data, error } = await supabase.rpc('record_procurement_placement', {
    p_tenant_id: params.tenantId,
    p_source_type: params.sourceType,
    p_source_id: params.sourceId,
    p_quantity: params.quantity,
    p_vendor_id: params.vendorId ?? null,
    p_vendor_code: params.vendorCode ?? null,
    p_notes: params.notes ?? null,
  });

  if (error) throw error;

  return data as ProcurementPlacementRow;
};

const cancelProcurementPlacement = async (
  tenantId: number,
  placementId: number,
): Promise<ProcurementPlacementRow> => {
  const { data, error } = await supabase.rpc('cancel_procurement_placement', {
    p_tenant_id: tenantId,
    p_placement_id: placementId,
  });

  if (error) throw error;

  return data as ProcurementPlacementRow;
};

export const procurementDemandRepository = {
  listProcurementDemandGroups,
  recordProcurementPlacement,
  cancelProcurementPlacement,
};

export const getItemNeedQuantity = (item: ProcurementDemandItem): number =>
  item.need_quantity ?? item.quantity;

export const getItemPlacedQuantity = (item: ProcurementDemandItem): number =>
  item.placed_quantity ?? 0;

export const getItemRemainingQuantity = (item: ProcurementDemandItem): number =>
  item.remaining_quantity ?? Math.max(getItemNeedQuantity(item) - getItemPlacedQuantity(item), 0);
