import { supabase } from 'src/boot/supabase';

const db = supabase as any;

export interface ShipmentProgressTag {
  id: number;
  name: string;
  slug: string;
  group_name: string | null;
  sort_order: number | null;
  color?: string | null;
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
  progress_tag_id?: number | null;
  progress_tag?: ShipmentProgressTag | null;
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
  return {
    ...row,
    total_weight_kg: total,
    received_weight: (row.received_weight as number | null | undefined) ?? total,
    inventory_added: inventory,
    stock_ready: (row.stock_ready as boolean | undefined) ?? inventory,
    progress_tag: progressRaw ?? null,
  };
};

const getById = async (id: number): Promise<GlobalShipment> => {
  const { data, error } = await db
    .from('global_shipments')
    .select('*, progress_tag:tags!global_shipments_progress_tag_id_fkey(*)')
    .eq('id', id)
    .single();

  if (error) {
    throw error;
  }

  const row = data as GlobalShipment & {
    progress_tag?: (ShipmentProgressTag & { color?: string | null }) | null;
  };
  const tag = row.progress_tag;
  return normalizeShipment({
    ...row,
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

const checkShipmentInvoiceReferences = async (shipmentId: number): Promise<string[]> => {
  // First get all items of this shipment
  const items = await listShipmentItems(shipmentId);
  if (!items.length) return [];

  const itemIds = items.map((i) => i.id);
  const { data, error } = await db
    .from('global_invoice_items')
    .select('invoice_id, global_invoices(invoice_no)')
    .in('shipment_item_id', itemIds);

  if (error) throw error;

  const invoiceNos = new Set<string>();
  if (data) {
    for (const row of data) {
      const inv = row.global_invoices as any;
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

const ensureShipmentProgressTags = async (tenantId: number): Promise<ShipmentProgressTag[]> => {
  const { data, error } = await db.rpc('ensure_shipment_progress_tags', {
    p_tenant_id: tenantId,
  });
  if (error) throw error;
  return ((data as ShipmentProgressTag[] | null) ?? []).map((t) => ({
    id: t.id,
    name: t.name,
    slug: t.slug,
    group_name: t.group_name ?? 'shipment_progress',
    sort_order: t.sort_order ?? null,
    color: (t as ShipmentProgressTag).color ?? null,
  }));
};

const setShipmentProgressTag = async (
  shipmentId: number,
  tagId: number | null,
): Promise<ShipmentProgressTag | null> => {
  const { data, error } = await db.rpc('set_global_shipment_progress_tag', {
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

export interface PaySettleShipmentCostsResult {
  shipment_id: number;
  settled_entries_count: number;
  wallet_posted: boolean;
}

const paySettleShipmentCosts = async (
  shipmentId: number,
  costEntryIds?: number[] | null,
): Promise<PaySettleShipmentCostsResult> => {
  const { data, error } = await db.rpc('pay_settle_shipment_costs', {
    p_shipment_id: shipmentId,
    p_cost_entry_ids: costEntryIds ?? null,
  });
  if (error) throw error;
  return data as PaySettleShipmentCostsResult;
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

export const globalShipmentRepository = {
  getById,
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
  assignShipmentToChild,
  paySettleShipmentCosts,
  returnShipmentToVendor,
  settleShipmentPayee,
  listShipmentPayeeSettlements,
};

