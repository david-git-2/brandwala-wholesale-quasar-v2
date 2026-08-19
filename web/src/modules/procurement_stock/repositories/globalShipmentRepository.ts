import { supabase } from 'src/boot/supabase';
import { globalShipmentCostEntryRepository } from './globalShipmentCostEntryRepository';
import { globalShipmentBoxRepository, type GlobalShipmentBox } from './globalShipmentBoxRepository';
import type { ShipmentSection } from '../types/shipmentSection';
import type { GlobalShipmentCostEntry } from '../types/shipmentCostEntry';
import {
  calculateShipmentCostSummary,
  costingShipmentFromEntries,
} from 'src/shared/shipment-engine';
import {
  isShipmentCostFinalized,
  sumProductEntryAmount,
} from '../utils/costEntriesCosting';

const db = supabase as any;

export interface ShipmentProgressTag {
  id: number;
  name: string;
  slug: string;
  group_name: string | null;
  sort_order: number | null;
  color?: string | null | undefined;
  is_active?: boolean | undefined;
}

export interface ShipmentProgressFlow {
  id: number;
  tenant_id: number;
  name: string;
  slug: string;
  is_active: boolean;
  is_default: boolean;
  created_at?: string | undefined;
  stage_count?: number | undefined;
}


export interface ShipmentProgressFlowStage {
  flow_stage_id: number;
  flow_id: number;
  tag_id: number;
  sort_order: number;
  name: string;
  slug: string;
  color: string | null;
  is_active: boolean;
}

export interface GlobalShipment {
  id: number;
  parent_tenant_id: number;
  vendor_id: number;
  cargo_company_id: number | null;
  name: string;
  type: 'international' | 'local' | 'transfer';
  status: string;
  assigned_child_tenant_id?: number | null;
  shipment_purchase_currency_id: number | null;
  shipment_cost_currency_id: number | null;
  cargo_invoice_total: number | null;
  purchase_invoice_total: number | null;
  /** Live column — dual-written with total_weight_kg */
  received_weight: number | null;
  /** Plan name for cargo invoice weight (kg) */
  total_weight_kg?: number | null;
  received_date: string | null;
  /** Live column — dual-written with inventory_added */
  stock_ready: boolean;
  /** Plan name for stock posted */
  inventory_added?: boolean;
  progress_flow_id?: number | null;
  progress_flow?: ShipmentProgressFlow | null;
  progress_tag_id?: number | null;
  progress_tag?: ShipmentProgressTag | null;
  public_tracking_token?: string | null;
  created_at: string;
  updated_at: string;
}

export interface GlobalShipmentItem {
  id: number;
  shipment_id: number;
  product_id: number | null;
  vendor_id: number | null;
  name: string;
  ordered_quantity: number;
  received_quantity?: number | null;
  image_url: string | null;
  add_method: 'order' | 'costing' | 'manual';
  purchase_price: number;
  product_weight: number;
  package_weight: number;
  barcode: string | null;
  product_code: string | null;
  source_child_tenant_id: number | null;
  source_type: string | null;
  source_id: number | null;
  /** Stamped on finalize/revise — null while draft. */
  landed_cost_bdt?: number | null;
  sort_order?: number;
  section_id?: number | null;
  created_at: string;
  updated_at: string;
}

export interface PaginationMeta {
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

export interface PaginatedResult<T> {
  data: T[];
  meta: PaginationMeta;
}

const normalizeShipment = (row: GlobalShipment & Record<string, unknown>): GlobalShipment => {
  const total =
    (row.total_weight_kg as number | null | undefined) ??
    (row.received_weight as number | null | undefined) ??
    null;
  const inventory =
    (row.inventory_added as boolean | undefined) ??
    (row.stock_ready as boolean | undefined) ??
    false;
  const progressRaw = row.progress_tag as ShipmentProgressTag | null | undefined;
  const progressFlowRaw = row.progress_flow as ShipmentProgressFlow | null | undefined;
  return {
    ...row,
    total_weight_kg: total,
    received_weight: (row.received_weight as number | null | undefined) ?? total,
    inventory_added: inventory,
    stock_ready: (row.stock_ready as boolean | undefined) ?? inventory,
    progress_flow: progressFlowRaw ?? null,
    progress_tag: progressRaw ?? null,
  };
};

export interface ShipmentOverviewDetailsPayload {
  shipment: GlobalShipment;
  sections: ShipmentSection[];
  items: GlobalShipmentItem[];
  boxes: GlobalShipmentBox[];
  cost_entries: GlobalShipmentCostEntry[];
  flow_stages: ShipmentProgressFlowStage[];
}

const getShipmentOverviewDetails = async (
  shipmentId: number,
): Promise<ShipmentOverviewDetailsPayload> => {
  const { data, error } = await supabase.rpc('get_shipment_overview_details', {
    p_shipment_id: shipmentId,
  });

  if (error) throw error;
  if (!data) throw new Error('Shipment not found');

  const raw = data as any;
  const shipment = normalizeShipment(raw.shipment);

  return {
    shipment,
    sections: (raw.sections ?? []) as ShipmentSection[],
    items: (raw.items ?? []) as GlobalShipmentItem[],
    boxes: (raw.boxes ?? []) as GlobalShipmentBox[],
    cost_entries: (raw.cost_entries ?? []) as GlobalShipmentCostEntry[],
    flow_stages: (raw.flow_stages ?? []) as ShipmentProgressFlowStage[],
  };
};

const getById = async (id: number): Promise<GlobalShipment> => {
  const { data, error } = await db
    .from('global_shipments')
    .select(
      '*, progress_flow:shipment_progress_flows!global_shipments_progress_flow_id_fkey(*), progress_tag:tags!global_shipments_progress_tag_id_fkey(*)',
    )
    .eq('id', id)
    .single();

  if (error) {
    throw error;
  }

  const row = data as GlobalShipment & {
    progress_flow?: ShipmentProgressFlow | null;
    progress_tag?: (ShipmentProgressTag & { color?: string | null }) | null;
  };
  const tag = row.progress_tag;
  const flow = row.progress_flow;
  return normalizeShipment({
    ...row,
    progress_flow: flow?.id
      ? {
          id: flow.id,
          tenant_id: flow.tenant_id,
          name: flow.name,
          slug: flow.slug,
          is_active: flow.is_active,
          is_default: flow.is_default,
          created_at: flow.created_at,
        }
      : null,
    progress_tag: tag?.id
      ? {
          id: tag.id,
          name: tag.name,
          slug: tag.slug,
          group_name: tag.group_name ?? 'shipment_progress',
          sort_order: tag.sort_order ?? null,
          color: tag.color ?? null,
        }
      : null,
  });
};

const listPaginated = async (
  tenantId: number,
  page: number = 1,
  pageSize: number = 20,
  search?: string,
  status?: string,
): Promise<PaginatedResult<GlobalShipment>> => {
  const { data, error } = await db.rpc('list_global_shipments_paginated', {
    p_tenant_id: tenantId,
    p_page: page,
    p_page_size: pageSize,
    p_search: search || null,
    p_status: status || null,
  });

  if (error) {
    throw error;
  }

  const result = data as {
    data: GlobalShipment[];
    meta: {
      total: number;
      page: number;
      page_size: number;
      total_pages: number;
    };
  };

  return {
    data: (result.data || []).map((row) =>
      normalizeShipment(row as GlobalShipment & Record<string, unknown>),
    ),
    meta: {
      total: result.meta?.total || 0,
      page: result.meta?.page || page,
      pageSize: result.meta?.page_size || pageSize,
      totalPages: result.meta?.total_pages || 1,
    },
  };
};

const createShipment = async (
  tenantId: number,
  payload: {
    name: string;
    type: 'international' | 'local' | 'transfer';
    shipment_purchase_currency_id: number | null;
    shipment_cost_currency_id: number | null;
  },
): Promise<GlobalShipment> => {
  const draft = await createShipmentDraft(tenantId, {
    name: payload.name,
    type: payload.type,
  });

  if (
    payload.shipment_purchase_currency_id == null &&
    payload.shipment_cost_currency_id == null
  ) {
    return draft;
  }

  return updateShipment(draft.id, {
    shipment_purchase_currency_id: payload.shipment_purchase_currency_id,
    shipment_cost_currency_id: payload.shipment_cost_currency_id,
  });
};

const createShipmentDraft = async (
  tenantId: number,
  payload: {
    name: string;
    type: 'international' | 'local' | 'transfer';
    vendor_id?: number | null;
    cargo_company_id?: number | null;
  },
): Promise<GlobalShipment> => {
  const { data, error } = await db.rpc('create_shipment_draft', {
    p_parent_tenant_id: tenantId,
    p_name: payload.name.trim(),
    p_type: payload.type,
    p_vendor_id: payload.vendor_id ?? null,
    p_cargo_company_id: payload.cargo_company_id ?? null,
  });

  if (error) throw error;
  return normalizeShipment(data as GlobalShipment & Record<string, unknown>);
};

const listCargoCompaniesForTenant = async (
  tenantId: number,
): Promise<Array<{ id: number; name: string; code: string; is_default: boolean }>> => {
  const { data, error } = await db
    .from('cargo_companies')
    .select('id, name, code, is_default')
    .or(`parent_tenant_id.eq.${tenantId},tenant_id.eq.${tenantId}`)
    .eq('is_active', true)
    .order('is_default', { ascending: false })
    .order('name', { ascending: true });

  if (error) throw error;
  return (
    (data as Array<{ id: number; name: string; code: string; is_default: boolean }> | null) ?? []
  );
};

const updateShipment = async (
  id: number,
  payload: Partial<Omit<GlobalShipment, 'id' | 'created_at' | 'updated_at' | 'parent_tenant_id'>>,
): Promise<GlobalShipment> => {
  const { data, error } = await db
    .from('global_shipments')
    .update(payload)
    .eq('id', id)
    .select()
    .single();

  if (error) throw error;
  return normalizeShipment(data as GlobalShipment & Record<string, unknown>);
};

const deleteShipment = async (id: number): Promise<void> => {
  const { error } = await db.from('global_shipments').delete().eq('id', id);
  if (error) throw error;
};

const listShipmentItems = async (shipmentId: number): Promise<GlobalShipmentItem[]> => {
  const { data, error } = await db
    .from('global_shipment_items')
    .select('*')
    .eq('shipment_id', shipmentId)
    .order('sort_order', { ascending: true })
    .order('id', { ascending: true });

  if (error) throw error;
  return (data as GlobalShipmentItem[] | null) ?? [];
};

const listShipmentItemsBatch = async (
  shipmentIds: number[],
): Promise<
  Record<
    number,
    Array<{
      id: number;
      purchase_price: number;
      product_weight: number;
      package_weight: number;
      ordered_quantity: number;
      landed_cost_bdt: number | null;
    }>
  >
> => {
  if (!shipmentIds.length) return {};
  const { data, error } = await db
    .from('global_shipment_items')
    .select(
      'id, shipment_id, purchase_price, product_weight, package_weight, ordered_quantity, landed_cost_bdt',
    )
    .in('shipment_id', shipmentIds)
    .order('sort_order', { ascending: true })
    .order('id', { ascending: true });

  if (error) throw error;

  const results: Record<
    number,
    Array<{
      id: number;
      purchase_price: number;
      product_weight: number;
      package_weight: number;
      ordered_quantity: number;
      landed_cost_bdt: number | null;
    }>
  > = {};
  for (const item of (data || []) as {
    id: number;
    shipment_id: number;
    purchase_price: number;
    product_weight: number;
    package_weight: number;
    ordered_quantity: number;
    landed_cost_bdt: number | null;
  }[]) {
    const sId = Number(item.shipment_id);
    if (!results[sId]) {
      results[sId] = [];
    }
    results[sId].push({
      id: Number(item.id),
      purchase_price: Number(item.purchase_price),
      product_weight: Number(item.product_weight),
      package_weight: Number(item.package_weight),
      ordered_quantity: Number(item.ordered_quantity),
      landed_cost_bdt:
        item.landed_cost_bdt == null ? null : Number(item.landed_cost_bdt),
    });
  }
  return results;
};

const updateShipmentItemsOrder = async (
  items: { id: number; sort_order: number }[],
): Promise<void> => {
  const { error } = await db.rpc('update_global_shipment_items_order', {
    p_items: items,
  });

  if (error) throw error;
};

export interface ApplyWeightBalanceAdjustment {
  item_id: number;
  package_weight: number;
}

export interface ApplyWeightBalanceRpcResult {
  estimated_kg: number;
  actual_kg: number;
  delta_kg: number;
}

const applyWeightBalance = async (
  shipmentId: number,
  adjustments: ApplyWeightBalanceAdjustment[],
): Promise<ApplyWeightBalanceRpcResult> => {
  const { data, error } = await db.rpc('apply_global_shipment_weight_balance', {
    p_shipment_id: shipmentId,
    p_adjustments: adjustments,
  });

  if (error) throw error;
  return data as ApplyWeightBalanceRpcResult;
};

export interface ShipmentSummaryKPIs {
  total_lines: number;
  total_ordered_quantity: number;
  total_received_quantity: number;
  packaging_weight_kg: number;
  cargo_weight_kg: number;
  boxes_weight_kg: number;
  boxes_count: number;
  purchase_currency_symbol: string;
  cost_currency_symbol: string;
  goods_purchase_total: number;
  cargo_purchase_total: number;
  total_purchase_amount: number;
  goods_cost_bdt: number;
  cargo_cost_bdt: number;
  total_landed_cost_bdt: number;
  avg_cost_per_unit_bdt: number;
  effective_exchange_rate: number | null;
  has_cargo_weight: boolean;
  has_product_invoice: boolean;
  weight_matched: boolean;
  purchase_matched: boolean;
  weight_delta_kg: number;
  purchase_delta_amount: number;
  matched_invoices_ratio: string;
  is_cost_finalized: boolean;
}

const getShipmentSummary = async (shipmentId: number): Promise<ShipmentSummaryKPIs> => {
  const [shipment, items, costEntries, boxes] = await Promise.all([
    getById(shipmentId),
    listShipmentItems(shipmentId),
    globalShipmentCostEntryRepository.listByShipmentId(shipmentId),
    globalShipmentBoxRepository.listByShipmentId(shipmentId),
  ]);

  const totalLines = items.length;
  const totalOrderedQty = items.reduce((sum, it) => sum + (Number(it.ordered_quantity) || 0), 0);
  const totalReceivedQty = items.reduce((sum, it) => sum + (Number(it.received_quantity) || 0), 0);
  const packagingWeightKg = items.reduce(
    (sum, it) => sum + (Number(it.ordered_quantity) || 0) * (Number(it.package_weight) || 0),
    0,
  );
  const boxesWeightKg = boxes.reduce((sum, b) => sum + (Number(b.weight_kg) || 0), 0);
  const cargoWeightKg = Number(shipment.total_weight_kg ?? shipment.received_weight) || 0;
  const hasCargoWeight = cargoWeightKg > 0;

  const costingShipment = costingShipmentFromEntries(shipment, costEntries as any, items);
  const costSummary = calculateShipmentCostSummary(costingShipment, items);

  const productCostEntriesTotal = sumProductEntryAmount(costEntries as any);
  const hasProductInvoice = productCostEntriesTotal > 0;

  const weightDeltaKg = Math.round(Math.abs(packagingWeightKg - cargoWeightKg) * 100) / 100;
  const purchaseDeltaAmount =
    Math.round(Math.abs(productCostEntriesTotal - costSummary.goodsPurchase) * 100) / 100;

  const weightMatched = hasCargoWeight && weightDeltaKg <= 0.01;
  const purchaseMatched = hasProductInvoice && purchaseDeltaAmount <= 0.05;

  let matchCount = 0;
  if (weightMatched) matchCount++;
  if (purchaseMatched) matchCount++;

  const avgCost = totalOrderedQty > 0 ? costSummary.totalCost / totalOrderedQty : 0;

  return {
    total_lines: totalLines,
    total_ordered_quantity: totalOrderedQty,
    total_received_quantity: totalReceivedQty,
    packaging_weight_kg: Math.round(packagingWeightKg * 100) / 100,
    cargo_weight_kg: Math.round(cargoWeightKg * 100) / 100,
    boxes_weight_kg: Math.round(boxesWeightKg * 100) / 100,
    boxes_count: boxes.length,
    purchase_currency_symbol: '£',
    cost_currency_symbol: '৳',
    goods_purchase_total: costSummary.goodsPurchase,
    cargo_purchase_total: costSummary.cargoPurchase,
    total_purchase_amount: costSummary.totalPurchase,
    goods_cost_bdt: costSummary.goodsCost,
    cargo_cost_bdt: costSummary.cargoCost,
    total_landed_cost_bdt: costSummary.totalCost,
    avg_cost_per_unit_bdt: Math.round(avgCost * 100) / 100,
    effective_exchange_rate: costSummary.transactionRate,
    has_cargo_weight: hasCargoWeight,
    has_product_invoice: hasProductInvoice,
    weight_matched: weightMatched,
    purchase_matched: purchaseMatched,
    weight_delta_kg: weightDeltaKg,
    purchase_delta_amount: purchaseDeltaAmount,
    matched_invoices_ratio: `${matchCount}/2`,
    is_cost_finalized: isShipmentCostFinalized(shipment),
  };
};

export interface ApplyPurchaseBalanceAdjustment {
  item_id: number;
  purchase_price: number;
}

export interface ApplyPurchaseBalanceRpcResult {
  estimated_total: number;
  actual_total: number;
  delta_total: number;
}

const applyPurchaseBalance = async (
  shipmentId: number,
  adjustments: ApplyPurchaseBalanceAdjustment[],
): Promise<ApplyPurchaseBalanceRpcResult> => {
  const { data, error } = await db.rpc('apply_global_shipment_purchase_balance', {
    p_shipment_id: shipmentId,
    p_adjustments: adjustments,
  });

  if (error) throw error;
  return data as ApplyPurchaseBalanceRpcResult;
};

const createShipmentItem = async (
  payload: Omit<GlobalShipmentItem, 'id' | 'created_at' | 'updated_at'>,
): Promise<GlobalShipmentItem> => {
  const { data, error } = await db
    .from('global_shipment_items')
    .insert([payload])
    .select()
    .single();

  if (error) throw error;
  return data as GlobalShipmentItem;
};

const updateShipmentItem = async (
  id: number,
  payload: Partial<Omit<GlobalShipmentItem, 'id' | 'created_at' | 'updated_at' | 'shipment_id'>>,
): Promise<GlobalShipmentItem> => {
  const { data, error } = await db
    .from('global_shipment_items')
    .update(payload)
    .eq('id', id)
    .select()
    .single();

  if (error) throw error;
  return data as GlobalShipmentItem;
};

const createShipmentItemsBulk = async (
  shipmentId: number,
  items: Omit<GlobalShipmentItem, 'id' | 'created_at' | 'updated_at'>[],
): Promise<GlobalShipmentItem[]> => {
  if (items.length === 0) return [];
  const { data, error } = await db.rpc('bulk_add_global_shipment_items', {
    p_shipment_id: shipmentId,
    p_items: items as any,
  });

  if (error) throw error;
  return (data as GlobalShipmentItem[] | null) ?? [];
};

const updateShipmentItemsBulk = async (
  shipmentId: number,
  updates: Array<{
    id: number;
    payload: Partial<
      Omit<GlobalShipmentItem, 'id' | 'created_at' | 'updated_at' | 'shipment_id'>
    >;
  }>,
): Promise<GlobalShipmentItem[]> => {
  if (updates.length === 0) return [];
  const formattedUpdates = updates.map((u) => ({
    id: u.id,
    ...u.payload,
  }));

  const { data, error } = await db.rpc('bulk_update_global_shipment_items', {
    p_shipment_id: shipmentId,
    p_updates: formattedUpdates as any,
  });

  if (error) throw error;
  return (data as GlobalShipmentItem[] | null) ?? [];
};

const deleteShipmentItem = async (id: number): Promise<void> => {
  const { error } = await db.from('global_shipment_items').delete().eq('id', id);
  if (error) throw error;
};

const deleteShipmentItemsBulk = async (
  shipmentId: number,
  ids: number[],
): Promise<number> => {
  if (ids.length === 0) return 0;
  const { data, error } = await supabase.rpc('bulk_delete_global_shipment_items', {
    p_shipment_id: shipmentId,
    p_item_ids: ids,
  });
  if (error) throw error;
  return Number(data) || 0;
};

const checkShipmentInvoiceReferences = async (shipmentId: number): Promise<string[]> => {
  // First get all items of this shipment
  const items = await listShipmentItems(shipmentId);
  if (!items.length) return [];

  const itemIds = items.map((i) => i.id);
  const { data, error } = await db
    .from('sales_invoice_items')
    .select('invoice_id, sales_invoices(invoice_no)')
    .in('shipment_item_id', itemIds);

  if (error) throw error;

  const invoiceNos = new Set<string>();
  if (data) {
    for (const row of data) {
      const inv = row.sales_invoices as any;
      if (inv && inv.invoice_no) {
        invoiceNos.add(inv.invoice_no);
      }
    }
  }
  return Array.from(invoiceNos);
};

const checkShipmentStockReferences = async (shipmentId: number): Promise<boolean> => {
  // First get all items of this shipment
  const items = await listShipmentItems(shipmentId);
  if (!items.length) return false;

  const itemIds = items.map((i) => i.id);
  const { data, error } = await db
    .from('global_stocks')
    .select('id')
    .in('shipment_item_id', itemIds)
    .limit(1);

  if (error) throw error;
  return (data && data.length > 0) || false;
};

const checkShipmentItemStockReferences = async (itemId: number): Promise<boolean> => {
  const { data, error } = await db
    .from('global_stocks')
    .select('id')
    .eq('shipment_item_id', itemId)
    .limit(1);

  if (error) throw error;
  return (data && data.length > 0) || false;
};

const listChildProcurementLines = async (
  parentTenantId: number,
  childTenantId?: number | null,
  search?: string | null,
  limit: number = 100,
  offset: number = 0,
) => {
  const { data, error } = await db.rpc('list_child_procurement_lines', {
    p_parent_tenant_id: parentTenantId,
    p_child_tenant_id: childTenantId || null,
    p_search: search || null,
    p_limit: limit,
    p_offset: offset,
  });

  if (error) throw error;
  return data;
};

const addChildLineToParentShipment = async (
  parentShipmentId: number,
  sourceType: string,
  sourceId: number,
) => {
  const { data, error } = await db.rpc('add_child_line_to_parent_shipment', {
    p_parent_shipment_id: parentShipmentId,
    p_source_type: sourceType,
    p_source_id: sourceId,
  });

  if (error) throw error;
  return data;
};

export interface FinalizeShipmentStockRow {
  shipment_item_id: number;
  stock_type_id?: number;
  availability?: 'sellable' | 'held' | 'unsellable';
  quantity: number;
  is_usable?: boolean;
  location_id?: number | null;
}

export interface FinalizeShipmentResult {
  shipment_id: number;
  items_stamped: number;
  stock_rows_posted: number;
  stock_ready: boolean;
  wallet_posted: boolean;
  movement_id?: number;
}

/** Stamp landed costs + optional stock post. Never posts wallet ledger. */
const finalizeShipment = async (
  shipmentId: number,
  stockRows?: FinalizeShipmentStockRow[] | null,
): Promise<FinalizeShipmentResult> => {
  const { data, error } = await db.rpc('finalize_global_shipment', {
    p_shipment_id: shipmentId,
    p_stock_rows: stockRows ?? null,
  });
  if (error) throw error;
  return data as FinalizeShipmentResult;
};

const normalizeProgressTag = (t: Record<string, unknown>): ShipmentProgressTag => ({
  id: t.id as number,
  name: t.name as string,
  slug: t.slug as string,
  group_name: (t.group_name as string | null) ?? 'shipment_progress',
  sort_order: (t.sort_order as number | null) ?? null,
  color: (t.color as string | null) ?? null,
  is_active: (t.is_active as boolean | undefined) ?? true,
});

const normalizeProgressFlow = (row: Record<string, unknown>): ShipmentProgressFlow => ({
  id: row.id as number,
  tenant_id: row.tenant_id as number,
  name: row.name as string,
  slug: row.slug as string,
  is_active: (row.is_active as boolean | undefined) ?? true,
  is_default: (row.is_default as boolean | undefined) ?? false,
  created_at: row.created_at as string | undefined,
  stage_count: row.stage_count as number | undefined,
});

const normalizeProgressFlowStage = (
  row: Record<string, unknown>,
): ShipmentProgressFlowStage => ({
  flow_stage_id: row.flow_stage_id as number,
  flow_id: row.flow_id as number,
  tag_id: row.tag_id as number,
  sort_order: row.sort_order as number,
  name: row.name as string,
  slug: row.slug as string,
  color: (row.color as string | null) ?? null,
  is_active: (row.is_active as boolean | undefined) ?? true,
});

const ensureShipmentProgressTags = async (tenantId: number): Promise<ShipmentProgressTag[]> => {
  const { data, error } = await db.rpc('ensure_shipment_progress_tags', {
    p_tenant_id: tenantId,
  });
  if (error) throw error;
  return ((data as Record<string, unknown>[] | null) ?? []).map(normalizeProgressTag);
};

const setShipmentProgressTag = async (
  shipmentId: number,
  tagId: number | null,
): Promise<ShipmentProgressTag | null> => {
  const { data, error } = await db.rpc('set_shipment_progress_stage', {
    p_shipment_id: shipmentId,
    p_tag_id: tagId,
  });
  if (error) throw error;
  const result = data as { progress_tag?: ShipmentProgressTag | null };
  return result?.progress_tag ?? null;
};

const assignShipmentToChild = async (
  parentTenantId: number,
  childTenantId: number | null,
  shipmentId: number,
): Promise<{ shipment_id: number; assigned_child_tenant_id: number | null }> => {
  const { data, error } = await db.rpc('assign_shipment_to_child', {
    p_parent_tenant_id: parentTenantId,
    p_child_tenant_id: childTenantId,
    p_shipment_id: shipmentId,
  });
  if (error) throw error;
  return data;
};

export interface ReturnShipmentItemQty {
  shipment_item_id: number;
  quantity: number;
}

export interface ReturnShipmentToVendorResult {
  shipment_id: number;
  outcome: string;
  return_processed: boolean;
}

const returnShipmentToVendor = async (
  shipmentId: number,
  itemsQty: ReturnShipmentItemQty[],
  outcome: 'cash_refund' | 'store_credit',
): Promise<ReturnShipmentToVendorResult> => {
  const { data, error } = await db.rpc('return_shipment_to_vendor', {
    p_shipment_id: shipmentId,
    p_items_qty: itemsQty,
    p_outcome: outcome,
  });
  if (error) throw error;
  return data as ReturnShipmentToVendorResult;
};

export interface SettleShipmentPayeeParams {
  shipmentId: number;
  entityType: 'vendor' | 'cargo_company';
  entityId: number;
  action: 'pay' | 'record_credit' | 'use_credit';
  amount: number;
  exchangeRate?: number | null;
}

export interface PayeeSettlementSummary {
  entity_type: 'vendor' | 'cargo_company';
  entity_id: number;
  available_bdt: number;
  paid_bdt: number;
  credited_bdt: number;
  used_bdt: number;
  recent_events: Array<{
    id: string;
    created_at: string;
    action: string;
    type: string;
    amount_input: number;
    exchange_rate: number;
    base_amount: number;
  }>;
}

export interface ListShipmentPayeeSettlementsResult {
  vendor: PayeeSettlementSummary | null;
  cargo_company: PayeeSettlementSummary | null;
}

const settleShipmentPayee = async (
  params: SettleShipmentPayeeParams,
): Promise<{ success: boolean; action: string; amount_bdt: number }> => {
  const { data, error } = await db.rpc('settle_shipment_payee', {
    p_shipment_id: params.shipmentId,
    p_entity_type: params.entityType,
    p_entity_id: params.entityId,
    p_action: params.action,
    p_amount: params.amount,
    p_exchange_rate: params.exchangeRate ?? null,
  });
  if (error) throw error;
  return data;
};

const listShipmentPayeeSettlements = async (
  shipmentId: number,
): Promise<ListShipmentPayeeSettlementsResult> => {
  const { data, error } = await db.rpc('list_shipment_payee_settlements', {
    p_shipment_id: shipmentId,
  });
  if (error) throw error;
  return data as ListShipmentPayeeSettlementsResult;
};

const generateTrackingToken = async (shipmentId: number): Promise<string> => {
  const { data, error } = await db.rpc('generate_shipment_tracking_token', {
    p_shipment_id: shipmentId,
  });
  if (error) throw error;
  return data as string;
};

const revokeTrackingToken = async (shipmentId: number): Promise<void> => {
  const { error } = await db.rpc('revoke_shipment_tracking_token', {
    p_shipment_id: shipmentId,
  });
  if (error) throw error;
};

const listShipmentProgressFlows = async (
  tenantId: number,
  includeArchived = false,
): Promise<ShipmentProgressFlow[]> => {
  const { data, error } = await db.rpc('list_shipment_progress_flows', {
    p_tenant_id: tenantId,
    p_include_archived: includeArchived,
  });
  if (error) throw error;
  return ((data as Record<string, unknown>[] | null) ?? []).map(normalizeProgressFlow);
};

const createShipmentProgressFlow = async (
  tenantId: number,
  name: string,
): Promise<ShipmentProgressFlow> => {
  const { data, error } = await db.rpc('create_shipment_progress_flow', {
    p_tenant_id: tenantId,
    p_name: name,
  });
  if (error) throw error;
  return normalizeProgressFlow(data as Record<string, unknown>);
};

const updateShipmentProgressFlow = async (
  flowId: number,
  name: string,
): Promise<ShipmentProgressFlow> => {
  const { data, error } = await db.rpc('update_shipment_progress_flow', {
    p_flow_id: flowId,
    p_name: name,
  });
  if (error) throw error;
  return normalizeProgressFlow(data as Record<string, unknown>);
};

const archiveShipmentProgressFlow = async (
  flowId: number,
  archive: boolean,
): Promise<ShipmentProgressFlow> => {
  const { data, error } = await db.rpc('archive_shipment_progress_flow', {
    p_flow_id: flowId,
    p_archive: archive,
  });
  if (error) throw error;
  return normalizeProgressFlow(data as Record<string, unknown>);
};

const setDefaultShipmentProgressFlow = async (
  flowId: number,
): Promise<ShipmentProgressFlow> => {
  const { data, error } = await db.rpc('set_default_shipment_progress_flow', {
    p_flow_id: flowId,
  });
  if (error) throw error;
  return normalizeProgressFlow(data as Record<string, unknown>);
};

const listShipmentProgressFlowStages = async (
  flowId: number,
  includeArchived = true,
): Promise<ShipmentProgressFlowStage[]> => {
  const { data, error } = await db.rpc('list_shipment_progress_flow_stages', {
    p_flow_id: flowId,
    p_include_archived: includeArchived,
  });
  if (error) throw error;
  return ((data as Record<string, unknown>[] | null) ?? []).map(normalizeProgressFlowStage);
};

const createShipmentProgressFlowStage = async (
  flowId: number,
  name: string,
  color?: string | null,
  sortOrder?: number | null,
): Promise<ShipmentProgressFlowStage> => {
  const { data, error } = await db.rpc('create_shipment_progress_flow_stage', {
    p_flow_id: flowId,
    p_name: name,
    p_color: color ?? '#64748b',
    p_sort_order: sortOrder ?? null,
  });
  if (error) throw error;
  const rows = (data as Record<string, unknown>[] | null) ?? [];
  return normalizeProgressFlowStage(rows[0] ?? {});
};

const updateShipmentProgressFlowStage = async (
  flowStageId: number,
  fields: { name?: string; color?: string | null },
): Promise<ShipmentProgressFlowStage> => {
  const { data, error } = await db.rpc('update_shipment_progress_flow_stage', {
    p_flow_stage_id: flowStageId,
    p_name: fields.name ?? null,
    p_color: fields.color ?? null,
  });
  if (error) throw error;
  const rows = (data as Record<string, unknown>[] | null) ?? [];
  return normalizeProgressFlowStage(rows[0] ?? {});
};

const archiveShipmentProgressFlowStage = async (
  flowStageId: number,
  archive: boolean,
): Promise<ShipmentProgressFlowStage> => {
  const { data, error } = await db.rpc('archive_shipment_progress_flow_stage', {
    p_flow_stage_id: flowStageId,
    p_archive: archive,
  });
  if (error) throw error;
  const rows = (data as Record<string, unknown>[] | null) ?? [];
  return normalizeProgressFlowStage(rows[0] ?? {});
};

const reorderShipmentProgressFlowStages = async (
  flowId: number,
  flowStageIds: number[],
): Promise<void> => {
  const { error } = await db.rpc('reorder_shipment_progress_flow_stages', {
    p_flow_id: flowId,
    p_flow_stage_ids: flowStageIds,
  });
  if (error) throw error;
};

const setShipmentProgressFlow = async (
  shipmentId: number,
  flowId: number,
): Promise<{ shipment_id: number; progress_flow_id: number }> => {
  const { data, error } = await db.rpc('set_shipment_progress_flow', {
    p_shipment_id: shipmentId,
    p_flow_id: flowId,
  });
  if (error) throw error;
  return data as { shipment_id: number; progress_flow_id: number };
};

const listShipmentProgressTags = async (
  tenantId: number,
  includeArchived = false,
): Promise<ShipmentProgressTag[]> => {
  const { data, error } = await db.rpc('list_shipment_progress_tags', {
    p_tenant_id: tenantId,
    p_include_archived: includeArchived,
  });
  if (error) throw error;
  return ((data as Record<string, unknown>[] | null) ?? []).map(normalizeProgressTag);
};

const createShipmentProgressTag = async (
  tenantId: number,
  name: string,
  color?: string | null,
  sortOrder?: number | null,
): Promise<ShipmentProgressTag> => {
  const { data, error } = await db.rpc('create_shipment_progress_tag', {
    p_tenant_id: tenantId,
    p_name: name,
    p_color: color ?? '#64748b',
    p_sort_order: sortOrder ?? null,
  });
  if (error) throw error;
  return normalizeProgressTag(data as Record<string, unknown>);
};

const updateShipmentProgressTag = async (
  tagId: number,
  fields: { name?: string; color?: string; sort_order?: number },
): Promise<ShipmentProgressTag> => {
  const { data, error } = await db.rpc('update_shipment_progress_tag', {
    p_tag_id: tagId,
    p_name: fields.name ?? null,
    p_color: fields.color ?? null,
    p_sort_order: fields.sort_order ?? null,
  });
  if (error) throw error;
  return normalizeProgressTag(data as Record<string, unknown>);
};

const archiveShipmentProgressTag = async (
  tagId: number,
  archive: boolean,
): Promise<ShipmentProgressTag> => {
  const { data, error } = await db.rpc('archive_shipment_progress_tag', {
    p_tag_id: tagId,
    p_archive: archive,
  });
  if (error) throw error;
  return normalizeProgressTag(data as Record<string, unknown>);
};

const reorderShipmentProgressTags = async (
  tenantId: number,
  tagIds: number[],
): Promise<void> => {
  const { error } = await db.rpc('reorder_shipment_progress_tags', {
    p_tenant_id: tenantId,
    p_tag_ids: tagIds,
  });
  if (error) throw error;
};

export const globalShipmentRepository = {
  getById,
  getShipmentOverviewDetails,
  listPaginated,
  createShipment,
  createShipmentDraft,
  listCargoCompaniesForTenant,
  updateShipment,
  deleteShipment,
  listShipmentItems,
  listShipmentItemsBatch,
  createShipmentItem,
  createShipmentItemsBulk,
  updateShipmentItem,
  updateShipmentItemsBulk,
  deleteShipmentItem,
  deleteShipmentItemsBulk,
  checkShipmentStockReferences,
  checkShipmentItemStockReferences,
  checkShipmentInvoiceReferences,
  updateShipmentItemsOrder,
  applyWeightBalance,
  applyPurchaseBalance,
  listChildProcurementLines,
  addChildLineToParentShipment,
  finalizeShipment,
  ensureShipmentProgressTags,
  setShipmentProgressTag,
  listShipmentProgressTags,
  createShipmentProgressTag,
  updateShipmentProgressTag,
  archiveShipmentProgressTag,
  reorderShipmentProgressTags,
  generateTrackingToken,
  revokeTrackingToken,
  listShipmentProgressFlows,
  createShipmentProgressFlow,
  updateShipmentProgressFlow,
  archiveShipmentProgressFlow,
  setDefaultShipmentProgressFlow,
  listShipmentProgressFlowStages,
  createShipmentProgressFlowStage,
  updateShipmentProgressFlowStage,
  archiveShipmentProgressFlowStage,
  reorderShipmentProgressFlowStages,
  setShipmentProgressFlow,
  assignShipmentToChild,
  returnShipmentToVendor,
  settleShipmentPayee,
  listShipmentPayeeSettlements,
  getShipmentSummary,
};

