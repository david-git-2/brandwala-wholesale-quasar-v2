import { supabase } from 'src/boot/supabase';
import { productBasedCostingRepository } from 'src/modules/product_based_costing/repositories/productBasedCostingRepository';
import { shopOrderRepository } from 'src/modules/shop_order/repositories/shopOrderRepository';

export type ProcurementDemandStatus = 'procuring' | 'dispatch' | 'delivered' | 'closed';

/** Fulfill hub delivery-papers list filter (includes all papers). */
export type FulfillDeliveryPapersListStatus = ProcurementDemandStatus | 'all';

export type ProcurementDemandDocumentType = 'shop_order' | 'pbc_costing_file';

export type ProcurementDemandSourceType = 'shop_order_item' | 'pbc_costing_item';

export interface ProcurementDemandVendor {
  id: number | null;
  code: string | null;
  name: string | null;
}

export type PreorderDemandCloseAction = 'take' | 'condition' | 'return';

export interface PreorderVendorPlacement {
  vendor_code: string;
  quantity: number;
}

export interface PreorderDemandStockPick {
  global_stock_id: number;
  quantity: number;
  shipment_name?: string | null;
  location_name?: string | null;
  close_action?: PreorderDemandCloseAction | null;
  close_split?: boolean | null;
  initial_quantity?: number | null;
  invoice_id?: number | null;
  returned_at?: string | null;
}

export type ClosePreorderDemandDocumentResult = {
  success: boolean;
  created?: boolean;
  close_action?: PreorderDemandCloseAction;
  invoice_id?: number;
  invoice_no?: string;
  pick_count?: number;
  unit_count?: number;
  error?: string;
};

export type ApplyDeliveryPaperOutcomeAllocation = {
  preorder_demand_id: number;
  global_stock_id?: number | null;
  delivery_paper_line_id?: number;
  quantity: number;
  grade_tag_id?: number | null;
};

export interface ProcurementDemandItem {
  source_type: ProcurementDemandSourceType;
  source_id: number;
  product_id: number | null;
  name: string;
  image_url: string | null;
  barcode: string | null;
  product_code: string | null;
  vendor_code?: string | null;
  market_code?: string | null;
  brand?: string | null;
  category?: string | null;
  available_units?: number | null;
  languages?: string | null;
  country_of_origin?: string | null;
  quantity: number;
  need_quantity?: number;
  preorder_demand_id?: number | null;
  vendor_id?: number | null;
  placed_quantity?: number;
  vendor_placements?: PreorderVendorPlacement[];
  delivered_quantity?: number;
  remaining_quantity?: number;
  remaining_to_deliver?: number;
  stock_picks?: PreorderDemandStockPick[];
  /** Per-unit customer sell price (first offer or final offer on negotiable shop orders). */
  unit_sell_price_amount?: number | null;
  is_negotiable_snapshot?: boolean | null;
}

export interface ProcurementDemandBuyDocument {
  document_type: ProcurementDemandDocumentType;
  document_id: number;
  document_name?: string | null;
  shop_order_no?: string | null;
  document_status: string;
  customer_group_id?: number | null;
  customer_group_name?: string | null;
  profile_id?: number | null;
  profile_name?: string | null;
  vendor: ProcurementDemandVendor | null;
  invoice_id?: number | null;
  line_count: number;
  under_ordered_line_count: number;
  has_under_ordered_lines: boolean;
}

export interface ProcurementDemandBuyDocumentsMeta {
  tenant_id: number;
  document_count: number;
  line_count: number;
  total_document_count: number;
  limit: number;
  offset: number;
  has_more: boolean;
}

export interface ProcurementDemandBuyDocumentsResponse {
  meta: ProcurementDemandBuyDocumentsMeta;
  documents: ProcurementDemandBuyDocument[];
}

export interface ListProcurementDemandBuyDocumentsParams {
  tenantId: number;
  search?: string | null;
  childTenantId?: number | null;
  limit?: number;
  offset?: number;
}

export interface GetProcurementDemandBuyDocumentParams {
  tenantId: number;
  documentType: ProcurementDemandDocumentType;
  documentId: number;
  search?: string | null;
  limit?: number;
  cursor?: ProcurementDemandGroupItemsCursor | null;
}

export interface ProcurementDemandBuyDocumentResponse {
  document: ProcurementDemandBuyDocument;
  items: ProcurementDemandItem[];
  meta: ProcurementDemandGroupItemsMeta;
}

export interface ProcurementDemandGroup {
  document_type: ProcurementDemandDocumentType;
  document_id: number;
  document_name?: string | null;
  shop_order_no?: string | null;
  document_status: string;
  customer_group_id?: number | null;
  customer_group_name?: string | null;
  profile_id?: number | null;
  profile_name?: string | null;
  vendor: ProcurementDemandVendor | null;
  invoice_id?: number | null;
  invoice_status?: string | null;
  invoice_stale?: boolean;
  item_count: number;
  unallocated_item_count: number;
}

export interface ProcurementDemandGroupItemsCursor {
  source_id: number;
}

export interface ProcurementDemandGroupItemsMeta {
  document_type: ProcurementDemandDocumentType;
  document_id: number;
  limit: number;
  has_more: boolean;
  next_cursor: ProcurementDemandGroupItemsCursor | null;
}

export interface ProcurementDemandGroupItemsResponse {
  meta: ProcurementDemandGroupItemsMeta;
  items: ProcurementDemandItem[];
}

export interface ListProcurementDemandGroupItemsParams {
  tenantId: number;
  documentType: ProcurementDemandDocumentType;
  documentId: number;
  search?: string | null;
  limit?: number;
  cursor?: ProcurementDemandGroupItemsCursor | null;
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
  profileId?: number | null;
  limit?: number;
  offset?: number;
}

export interface ListProcurementFulfillGroupsParams {
  tenantId: number;
  procurementStatus?: ProcurementDemandStatus;
  search?: string | null;
  profileId?: number | null;
  limit?: number;
  offset?: number;
}

export interface UpsertPreorderDemandParams {
  tenantId: number;
  sourceType: ProcurementDemandSourceType;
  sourceId: number;
  vendorId?: number | null;
  placedQuantity?: number | null;
  vendorPlacements?: PreorderVendorPlacement[] | null;
  stockPicks?: PreorderDemandStockPick[] | null;
  notes?: string | null;
}

export interface FillPreorderDemandPlacedQuantitiesParams {
  tenantId: number;
  documentType: ProcurementDemandDocumentType;
  documentId: number;
}

export interface FillPreorderDemandPlacedQuantitiesResult {
  document_type: ProcurementDemandDocumentType;
  document_id: number;
  updated_count: number;
}

export interface FillPreorderDemandOldestStockParams {
  tenantId: number;
  documentType: ProcurementDemandDocumentType;
  documentId: number;
}

export interface FillPreorderDemandOldestStockResult {
  document_type: ProcurementDemandDocumentType;
  document_id: number;
  updated_count: number;
  skipped_count: number;
}

export interface SetPreorderDemandVendorParams {
  tenantId: number;
  documentType: ProcurementDemandDocumentType;
  documentId: number;
  vendorId: number;
}

export interface SetPreorderDemandVendorResult {
  document_type: ProcurementDemandDocumentType;
  document_id: number;
  vendor_id: number;
  updated_count: number;
}

export interface PreorderDemandRow {
  id: number;
  tenant_id: number;
  source_type: ProcurementDemandSourceType;
  source_id: number;
  vendor_id: number | null;
  placed_quantity: number;
  delivered_quantity: number;
  vendor_placements: PreorderVendorPlacement[];
  stock_picks: PreorderDemandStockPick[];
  notes: string | null;
  updated_by_user_id: string | null;
  created_at: string;
  updated_at: string;
}

export type DeliveryPaperStatus = 'draft' | 'packed' | 'dispatched' | 'delivered' | 'cancelled';

export interface DeliveryPaperSummary {
  id: number;
  status: DeliveryPaperStatus;
  created_at: string;
  updated_at: string;
  delivery_date: string | null;
  note: string | null;
  line_count: number;
}

export interface FulfillDeliveryPaperListItem extends DeliveryPaperSummary {
  source_type: ProcurementDemandDocumentType;
  source_id: number;
  shop_order_no: string | null;
  document_name: string | null;
  profile_id: number | null;
  profile_name: string | null;
}

export interface FulfillDeliveryPapersResponse {
  meta: {
    tenant_id: number;
    procurement_status: string;
    total_count: number;
    limit: number;
    offset: number;
    has_more: boolean;
  };
  papers: FulfillDeliveryPaperListItem[];
}

export interface ListFulfillDeliveryPapersParams {
  tenantId: number;
  procurementStatus?: FulfillDeliveryPapersListStatus;
  search?: string | null;
  limit?: number;
  offset?: number;
}

export interface DeliveryPaperHeader {
  id: number;
  status: DeliveryPaperStatus;
  source_type: ProcurementDemandDocumentType;
  source_id: number;
  profile_id: number | null;
  profile_name: string | null;
  document_name: string | null;
  shop_order_no: string | null;
  created_at: string;
  updated_at: string;
  delivery_date: string | null;
  note: string | null;
  close_bills?: DeliveryPaperCloseBill[];
}

export interface DeliveryPaperCloseBill {
  id: number;
  invoice_no: string | null;
  invoice_status: string | null;
  settlement_kind?: string | null;
}

export interface DeliveryPaperDetailItem extends ProcurementDemandItem {
  /** Packed on sibling delivery papers for the same document line (excludes this paper). */
  packed_on_other_delivery_papers?: number;
  /** Order remaining minus packed on other papers; cap for picks on this paper. */
  remaining_to_pack?: number;
  paper_picks?: Array<{
    line_id?: number;
    client_key?: string;
    global_stock_id: number;
    quantity: number;
    close_action?: string | null;
    line_status?: string;
    is_close_split?: boolean;
    shipment_name?: string | null;
    location_name?: string | null;
    invoice_id?: number | null;
    returned_at?: string | null;
    is_applied?: boolean;
  }>;
}

export interface DeliveryPaperDetailResponse {
  paper: DeliveryPaperHeader;
  items: DeliveryPaperDetailItem[];
  meta: Record<string, unknown>;
}

export interface SaveDeliveryPaperDetailItem {
  preorder_demand_id: number;
  splits: Array<{ quantity: number; status: string }>;
  picks?: Array<{ global_stock_id: number; quantity: number }>;
  note?: string | null;
}

const listProcurementDemandBuyDocuments = async (
  params: ListProcurementDemandBuyDocumentsParams,
): Promise<ProcurementDemandBuyDocumentsResponse> => {
  const { data, error } = await supabase.rpc('list_procurement_demand_buy_documents', {
    p_tenant_id: params.tenantId,
    p_search: params.search ?? null,
    p_child_tenant_id: params.childTenantId ?? null,
    p_limit: params.limit ?? 50,
    p_offset: params.offset ?? 0,
  });

  if (error) throw error;

  const payload = (data ?? { meta: {}, documents: [] }) as ProcurementDemandBuyDocumentsResponse;
  payload.documents = (payload.documents ?? []).map((doc) => ({
    ...doc,
    document_name: doc.document_name?.trim() || null,
    line_count: doc.line_count ?? 0,
    under_ordered_line_count: doc.under_ordered_line_count ?? 0,
    has_under_ordered_lines: Boolean(doc.has_under_ordered_lines),
  }));
  return payload;
};

const getProcurementDemandBuyDocument = async (
  params: GetProcurementDemandBuyDocumentParams,
): Promise<ProcurementDemandBuyDocumentResponse> => {
  const { data, error } = await supabase.rpc('get_procurement_demand_buy_document', {
    p_tenant_id: params.tenantId,
    p_document_type: params.documentType,
    p_document_id: params.documentId,
    p_search: params.search ?? null,
    p_limit: params.limit ?? 50,
    p_cursor_source_id: params.cursor?.source_id ?? null,
  });

  if (error) throw error;

  const payload = (data ?? {}) as ProcurementDemandBuyDocumentResponse;
  const meta = payload.meta ?? ({} as ProcurementDemandGroupItemsMeta);
  return {
    document: payload.document,
    items: payload.items ?? [],
    meta: {
      ...meta,
      next_cursor: parseDemandGroupItemsCursor(meta.next_cursor),
      has_more: Boolean(meta.has_more),
    },
  };
};

const listProcurementDemandGroups = async (
  params: ListProcurementDemandGroupsParams,
): Promise<ProcurementDemandGroupsResponse> => {
  const { data, error } = await supabase.rpc('list_procurement_demand_groups', {
    p_tenant_id: params.tenantId,
    p_procurement_status: params.procurementStatus ?? 'procuring',
    p_search: params.search ?? null,
    p_child_tenant_id: params.childTenantId ?? null,
    p_profile_id: params.profileId ?? null,
    p_limit: params.limit ?? 50,
    p_offset: params.offset ?? 0,
  });

  if (error) throw error;

  const payload = (data ?? { meta: {}, groups: [] }) as ProcurementDemandGroupsResponse;
  payload.groups = (payload.groups ?? []).map((group) => ({
    ...group,
    document_name: group.document_name?.trim() || null,
    item_count: group.item_count ?? 0,
    unallocated_item_count: group.unallocated_item_count ?? 0,
  }));
  return payload;
};

const listProcurementFulfillGroups = async (
  params: ListProcurementFulfillGroupsParams,
): Promise<ProcurementDemandGroupsResponse> => {
  const { data, error } = await supabase.rpc('list_procurement_fulfill_groups', {
    p_tenant_id: params.tenantId,
    p_procurement_status: params.procurementStatus ?? 'procuring',
    p_search: params.search ?? null,
    p_profile_id: params.profileId ?? null,
    p_limit: params.limit ?? 50,
    p_offset: params.offset ?? 0,
  });

  if (error) throw error;

  const payload = (data ?? { meta: {}, groups: [] }) as ProcurementDemandGroupsResponse;
  payload.groups = (payload.groups ?? []).map((group) => ({
    ...group,
    document_name: group.document_name?.trim() || null,
    item_count: group.item_count ?? 0,
    unallocated_item_count: group.unallocated_item_count ?? 0,
  }));
  return payload;
};

const parseDemandGroupItemsCursor = (
  raw: unknown,
): ProcurementDemandGroupItemsCursor | null => {
  if (!raw || typeof raw !== 'object') return null;
  const cursor = raw as { source_id?: unknown };
  const sourceId = Number(cursor.source_id);
  if (!Number.isFinite(sourceId)) return null;
  return { source_id: sourceId };
};

const listProcurementDemandGroupItems = async (
  params: ListProcurementDemandGroupItemsParams,
): Promise<ProcurementDemandGroupItemsResponse> => {
  const { data, error } = await supabase.rpc('list_procurement_demand_group_items', {
    p_tenant_id: params.tenantId,
    p_document_type: params.documentType,
    p_document_id: params.documentId,
    p_search: params.search ?? null,
    p_limit: params.limit ?? 50,
    p_cursor_source_id: params.cursor?.source_id ?? null,
  });

  if (error) throw error;

  const payload = (data ?? { meta: {}, items: [] }) as ProcurementDemandGroupItemsResponse;
  const meta = payload.meta ?? ({} as ProcurementDemandGroupItemsMeta);
  return {
    items: payload.items ?? [],
    meta: {
      ...meta,
      next_cursor: parseDemandGroupItemsCursor(meta.next_cursor),
      has_more: Boolean(meta.has_more),
    },
  };
};

const listProcurementFulfillGroupItems = async (
  params: ListProcurementDemandGroupItemsParams,
): Promise<ProcurementDemandGroupItemsResponse> => {
  const { data, error } = await supabase.rpc('list_procurement_fulfill_group_items', {
    p_tenant_id: params.tenantId,
    p_document_type: params.documentType,
    p_document_id: params.documentId,
    p_search: params.search ?? null,
    p_limit: params.limit ?? 50,
    p_cursor_source_id: params.cursor?.source_id ?? null,
  });

  if (error) throw error;

  const payload = (data ?? { meta: {}, items: [] }) as ProcurementDemandGroupItemsResponse;
  const meta = payload.meta ?? ({} as ProcurementDemandGroupItemsMeta);
  return {
    items: payload.items ?? [],
    meta: {
      ...meta,
      next_cursor: parseDemandGroupItemsCursor(meta.next_cursor),
      has_more: Boolean(meta.has_more),
    },
  };
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
    p_vendor_placements: params.vendorPlacements ?? null,
    p_stock_picks: params.stockPicks ?? null,
    p_notes: params.notes ?? null,
  });

  if (error) throw error;

  return data as PreorderDemandRow;
};

const fillPreorderDemandPlacedQuantitiesForDocument = async (
  params: FillPreorderDemandPlacedQuantitiesParams,
): Promise<FillPreorderDemandPlacedQuantitiesResult> => {
  const { data, error } = await supabase.rpc(
    'fill_preorder_demand_placed_quantities_for_document',
    {
      p_tenant_id: params.tenantId,
      p_document_type: params.documentType,
      p_document_id: params.documentId,
    },
  );

  if (error) throw error;

  return data as FillPreorderDemandPlacedQuantitiesResult;
};

const fillPreorderDemandOldestStockForDocument = async (
  params: FillPreorderDemandOldestStockParams,
): Promise<FillPreorderDemandOldestStockResult> => {
  const { data, error } = await supabase.rpc(
    'fill_preorder_demand_oldest_stock_for_document',
    {
      p_tenant_id: params.tenantId,
      p_document_type: params.documentType,
      p_document_id: params.documentId,
    },
  );

  if (error) throw error;

  return data as FillPreorderDemandOldestStockResult;
};

const setPreorderDemandVendorForDocument = async (
  params: SetPreorderDemandVendorParams,
): Promise<SetPreorderDemandVendorResult> => {
  const { data, error } = await supabase.rpc('set_preorder_demand_vendor_for_document', {
    p_tenant_id: params.tenantId,
    p_document_type: params.documentType,
    p_document_id: params.documentId,
    p_vendor_id: params.vendorId,
  });

  if (error) throw error;

  return data as SetPreorderDemandVendorResult;
};

const closePreorderDemandDocument = async (params: {
  tenantId: number;
  documentType: ProcurementDemandDocumentType;
  documentId: number;
  closeAction: PreorderDemandCloseAction;
}): Promise<ClosePreorderDemandDocumentResult> => {
  const { data, error } = await supabase.rpc('close_preorder_demand_document', {
    p_tenant_id: params.tenantId,
    p_document_type: params.documentType,
    p_document_id: params.documentId,
    p_close_action: params.closeAction,
  });

  if (error) throw error;

  const result = (data ?? {}) as ClosePreorderDemandDocumentResult;
  if (!result.success) {
    throw new Error(result.error || 'Failed to close delivery paper picks');
  }
  return result;
};

const markDemandGroupReadyForShipment = async (
  group: ProcurementDemandGroup,
): Promise<void> => {
  if (group.document_type === 'shop_order') {
    await shopOrderRepository.staffSetCatalogOrderedQty(group.document_id, []);
    return;
  }

  await productBasedCostingRepository.markPbcReadyForShipment(group.document_id);
};

const createDeliveryPaperForDocument = async (params: {
  tenantId: number;
  documentType: ProcurementDemandDocumentType;
  documentId: number;
}): Promise<{ id: number; status: DeliveryPaperStatus; created_at: string }> => {
  const { data, error } = await supabase.rpc('create_delivery_paper_for_document', {
    p_tenant_id: params.tenantId,
    p_document_type: params.documentType,
    p_document_id: params.documentId,
  });
  if (error) throw error;
  return data as { id: number; status: DeliveryPaperStatus; created_at: string };
};

const listDeliveryPapersForFulfillPage = async (
  params: ListFulfillDeliveryPapersParams,
): Promise<FulfillDeliveryPapersResponse> => {
  const { data, error } = await supabase.rpc('list_delivery_papers_for_fulfill_page', {
    p_tenant_id: params.tenantId,
    p_procurement_status: params.procurementStatus ?? 'procuring',
    p_search: params.search ?? null,
    p_limit: params.limit ?? 50,
    p_offset: params.offset ?? 0,
  });

  if (error) throw error;

  const payload = (data ?? { meta: {}, papers: [] }) as FulfillDeliveryPapersResponse;
  payload.papers = payload.papers ?? [];
  return payload;
};

const listDeliveryPapersForDocument = async (params: {
  tenantId: number;
  documentType: ProcurementDemandDocumentType;
  documentId: number;
}): Promise<DeliveryPaperSummary[]> => {
  const { data, error } = await supabase.rpc('list_delivery_papers_for_document', {
    p_tenant_id: params.tenantId,
    p_document_type: params.documentType,
    p_document_id: params.documentId,
  });
  if (error) throw error;
  const payload = (data ?? { papers: [] }) as { papers?: DeliveryPaperSummary[] };
  return payload.papers ?? [];
};

const getDeliveryPaperDetail = async (params: {
  tenantId: number;
  deliveryPaperId: number;
}): Promise<DeliveryPaperDetailResponse> => {
  const { data, error } = await supabase.rpc('get_delivery_paper_detail', {
    p_tenant_id: params.tenantId,
    p_delivery_paper_id: params.deliveryPaperId,
  });
  if (error) throw error;
  const payload = (data ?? {}) as DeliveryPaperDetailResponse;
  return {
    paper: payload.paper,
    items: payload.items ?? [],
    meta: payload.meta ?? {},
  };
};

const saveDeliveryPaperDetail = async (params: {
  tenantId: number;
  deliveryPaperId: number;
  items: SaveDeliveryPaperDetailItem[];
}): Promise<{ success: boolean; line_count: number; status: DeliveryPaperStatus }> => {
  const { data, error } = await supabase.rpc('save_delivery_paper_detail', {
    p_tenant_id: params.tenantId,
    p_delivery_paper_id: params.deliveryPaperId,
    p_items: params.items,
  });
  if (error) throw error;
  return (data ?? { success: false, line_count: 0, status: 'draft' }) as {
    success: boolean;
    line_count: number;
    status: DeliveryPaperStatus;
  };
};

const deleteDeliveryPaper = async (params: {
  tenantId: number;
  deliveryPaperId: number;
}): Promise<{ success: boolean; id: number }> => {
  const { data, error } = await supabase.rpc('delete_delivery_paper', {
    p_tenant_id: params.tenantId,
    p_delivery_paper_id: params.deliveryPaperId,
  });
  if (error) throw error;
  return (data ?? { success: false, id: params.deliveryPaperId }) as {
    success: boolean;
    id: number;
  };
};

const updateDeliveryPaperStatus = async (params: {
  tenantId: number;
  deliveryPaperId: number;
  status: DeliveryPaperStatus;
}): Promise<{ success: boolean; status: DeliveryPaperStatus }> => {
  const { data, error } = await supabase.rpc('update_delivery_paper_status', {
    p_tenant_id: params.tenantId,
    p_delivery_paper_id: params.deliveryPaperId,
    p_status: params.status,
  });
  if (error) throw error;
  return (data ?? { success: false, status: params.status }) as {
    success: boolean;
    status: DeliveryPaperStatus;
  };
};

const applyDeliveryPaperOutcome = async (params: {
  tenantId: number;
  deliveryPaperId: number;
  closeAction: PreorderDemandCloseAction;
  allocations: ApplyDeliveryPaperOutcomeAllocation[];
}): Promise<ClosePreorderDemandDocumentResult> => {
  const { data, error } = await supabase.rpc('apply_delivery_paper_outcome', {
    p_tenant_id: params.tenantId,
    p_delivery_paper_id: params.deliveryPaperId,
    p_close_action: params.closeAction,
    p_allocations: params.allocations,
  });
  if (error) throw error;
  const result = (data ?? {}) as ClosePreorderDemandDocumentResult;
  if (!result.success) {
    throw new Error(result.error || 'Failed to apply delivery paper outcome');
  }
  return result;
};

export const procurementDemandRepository = {
  listProcurementDemandBuyDocuments,
  getProcurementDemandBuyDocument,
  listProcurementDemandGroups,
  listProcurementDemandGroupItems,
  listProcurementFulfillGroups,
  listDeliveryPapersForFulfillPage,
  listProcurementFulfillGroupItems,
  upsertPreorderDemand,
  fillPreorderDemandPlacedQuantitiesForDocument,
  fillPreorderDemandOldestStockForDocument,
  setPreorderDemandVendorForDocument,
  markDemandGroupReadyForShipment,
  closePreorderDemandDocument,
  createDeliveryPaperForDocument,
  listDeliveryPapersForDocument,
  getDeliveryPaperDetail,
  saveDeliveryPaperDetail,
  deleteDeliveryPaper,
  updateDeliveryPaperStatus,
  applyDeliveryPaperOutcome,
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
  Math.max(getItemNeedQuantity(item) - getItemDeliveredQuantity(item), 0);
