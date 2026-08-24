import { supabase } from 'src/boot/supabase';

export type ProcurementDemandStatus = 'procuring' | 'ready_for_shipment' | 'delivered';

export type ProcurementDemandDocumentType = 'shop_order' | 'pbc_costing_file';

export type ProcurementDemandSourceType = 'shop_order_item' | 'pbc_costing_item';

export interface ProcurementDemandVendor {
  id: number | null;
  code: string | null;
  name: string | null;
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

export const procurementDemandRepository = {
  listProcurementDemandGroups,
};
