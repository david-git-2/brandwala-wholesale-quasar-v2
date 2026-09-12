import { supabase } from 'src/boot/supabase';

export type ProcurementDemandStatus = 'procuring' | 'ready_for_shipment' | 'delivered';

export type ProcurementDemandDocumentType = 'shop_order' | 'pbc_costing_file';

export type ProcurementDemandSourceType = 'shop_order_item' | 'pbc_costing_item';

export interface ProcurementDemandVendor {
  id: number | null;
  code: string | null;
  name: string | null;
}

export interface PreorderDemandStockPick {
  global_stock_id: number;
  quantity: number;
  shipment_name?: string | null;
  location_name?: string | null;
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
  preorder_demand_id?: number | null;
  vendor_id?: number | null;
  placed_quantity?: number;
  delivered_quantity?: number;
  remaining_quantity?: number;
  remaining_to_deliver?: number;
  stock_picks?: PreorderDemandStockPick[];
}

export interface ProcurementDemandGroup {
  document_type: ProcurementDemandDocumentType;
  document_id: number;
  document_status: string;
  customer_group_id?: number | null;
  customer_group_name?: string | null;
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

export interface UpsertPreorderDemandParams {
  tenantId: number;
  sourceType: ProcurementDemandSourceType;
  sourceId: number;
  vendorId?: number | null;
  placedQuantity?: number | null;
  stockPicks?: PreorderDemandStockPick[] | null;
  notes?: string | null;
}

export interface PreorderDemandRow {
  id: number;
  tenant_id: number;
  source_type: ProcurementDemandSourceType;
  source_id: number;
  vendor_id: number | null;
  placed_quantity: number;
  delivered_quantity: number;
  stock_picks: PreorderDemandStockPick[];
  notes: string | null;
  updated_by_user_id: string | null;
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

const upsertPreorderDemand = async (
  params: UpsertPreorderDemandParams,
): Promise<PreorderDemandRow> => {
  const { data, error } = await supabase.rpc('upsert_preorder_demand', {
    p_tenant_id: params.tenantId,
    p_source_type: params.sourceType,
    p_source_id: params.sourceId,
    p_vendor_id: params.vendorId ?? null,
    p_placed_quantity: params.placedQuantity ?? null,
    p_stock_picks: params.stockPicks ?? null,
    p_notes: params.notes ?? null,
  });

  if (error) throw error;

  return data as PreorderDemandRow;
};

export const procurementDemandRepository = {
  listProcurementDemandGroups,
  upsertPreorderDemand,
};

export const getItemNeedQuantity = (item: ProcurementDemandItem): number =>
  item.need_quantity ?? item.quantity;

export const getItemPlacedQuantity = (item: ProcurementDemandItem): number =>
  item.placed_quantity ?? 0;

export const getItemDeliveredQuantity = (item: ProcurementDemandItem): number =>
  item.delivered_quantity ?? 0;

export const getItemRemainingQuantity = (item: ProcurementDemandItem): number =>
  item.remaining_quantity ?? getItemNeedQuantity(item) - getItemPlacedQuantity(item);

export const getItemRemainingToDeliver = (item: ProcurementDemandItem): number =>
  item.remaining_to_deliver ??
  Math.max(getItemPlacedQuantity(item) - getItemDeliveredQuantity(item), 0);
