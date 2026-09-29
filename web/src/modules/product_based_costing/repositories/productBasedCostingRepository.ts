import { supabase } from 'src/boot/supabase';

import type {
  ProductBasedCostingFile,
  ProductBasedCostingFileListInput,
  ProductBasedCostingFileListPage,
  ProductBasedCostingFileCreateInput,
  ProductBasedCostingFileUpdateInput,
  ProductBasedCostingItem,
  ProductBasedCostingItemCreateInput,
  ProductBasedCostingItemListInput,
  ProductBasedCostingItemListPage,
  ProductBasedCostingItemUpdateInput,
} from '../types';

const normalizeText = (value: string | null | undefined) => {
  if (typeof value !== 'string') {
    return value ?? null;
  }

  const trimmed = value.trim();

  return trimmed.length > 0 ? trimmed : null;
};

const buildProductBasedCostingFileCreatePayload = (
  payload: ProductBasedCostingFileCreateInput,
) => ({
  tenant_id: payload.tenant_id ?? null,
  name: normalizeText(payload.name),
  order_for: normalizeText(payload.order_for),
  customer_group_id: payload.customer_group_id ?? null,
  note: normalizeText(payload.note),
  vendor_code: normalizeText(payload.vendor_code),
  market_code: normalizeText(payload.market_code),
  cargo_rate_kg_gbp: payload.cargo_rate_kg_gbp ?? null,
  profit_rate: payload.profit_rate ?? null,
  vat_rate: payload.vat_rate ?? null,
  offer_pricing_mode: payload.offer_pricing_mode ?? null,
  conversion_rate: payload.conversion_rate ?? null,
  status: normalizeText(payload.status),
  default_shipment_id: payload.default_shipment_id ?? null,
  buy_currency_id: payload.buy_currency_id ?? null,
  sell_currency_id: payload.sell_currency_id ?? null,
});

const buildProductBasedCostingFileUpdatePayload = (
  payload: Omit<ProductBasedCostingFileUpdateInput, 'id'>,
) => {
  const updatePayload: Record<string, unknown> = {};

  if (payload.tenant_id !== undefined) {
    updatePayload.tenant_id = payload.tenant_id;
  }

  if (payload.name !== undefined) {
    updatePayload.name = normalizeText(payload.name);
  }

  if (payload.order_for !== undefined) {
    updatePayload.order_for = normalizeText(payload.order_for);
  }

  if (payload.customer_group_id !== undefined) {
    updatePayload.customer_group_id = payload.customer_group_id;
  }

  if (payload.note !== undefined) {
    updatePayload.note = normalizeText(payload.note);
  }

  if (payload.vendor_code !== undefined) {
    updatePayload.vendor_code = normalizeText(payload.vendor_code);
  }

  if (payload.market_code !== undefined) {
    updatePayload.market_code = normalizeText(payload.market_code);
  }

  if (payload.cargo_rate_kg_gbp !== undefined) {
    updatePayload.cargo_rate_kg_gbp = payload.cargo_rate_kg_gbp;
  }

  if (payload.profit_rate !== undefined) {
    updatePayload.profit_rate = payload.profit_rate;
  }

  if (payload.vat_rate !== undefined) {
    updatePayload.vat_rate = payload.vat_rate;
  }

  if (payload.offer_pricing_mode !== undefined) {
    updatePayload.offer_pricing_mode = payload.offer_pricing_mode;
  }

  if (payload.conversion_rate !== undefined) {
    updatePayload.conversion_rate = payload.conversion_rate;
  }

  if (payload.status !== undefined) {
    updatePayload.status = normalizeText(payload.status);
  }

  if (payload.default_shipment_id !== undefined) {
    updatePayload.default_shipment_id = payload.default_shipment_id;
  }

  if (payload.buy_currency_id !== undefined) {
    updatePayload.buy_currency_id = payload.buy_currency_id;
  }

  if (payload.sell_currency_id !== undefined) {
    updatePayload.sell_currency_id = payload.sell_currency_id;
  }

  return updatePayload;
};

const buildProductBasedCostingItemCreatePayload = (
  payload: ProductBasedCostingItemCreateInput,
) => ({
  product_based_costing_file_id: payload.product_based_costing_file_id ?? null,
  name: normalizeText(payload.name),
  image_url: normalizeText(payload.image_url),
  note: normalizeText(payload.note),
  quantity: payload.quantity ?? null,
  barcode: normalizeText(payload.barcode),
  product_code: normalizeText(payload.product_code),
  brand: normalizeText(payload.brand),
  vendor_code: normalizeText(payload.vendor_code),
  market_code: normalizeText(payload.market_code),
  web_link: normalizeText(payload.web_link),
  price_gbp: payload.price_gbp ?? null,
  product_weight: payload.product_weight ?? null,
  package_weight: payload.package_weight ?? null,
  offer_price: payload.offer_price ?? null,
  is_offer_price_manual: payload.is_offer_price_manual ?? false,
  product_id: payload.product_id,
  input_type: normalizeText(payload.input_type),
  assigned_shipment_id: payload.assigned_shipment_id ?? null,
});

const sanitizeNumeric = (value: unknown): number | null => {
  if (value === null || value === undefined || value === '') return null;
  const num = Number(value);
  return Number.isFinite(num) ? num : null;
};

const buildProductBasedCostingItemUpdatePayload = (
  payload: Omit<ProductBasedCostingItemUpdateInput, 'id'>,
) => {
  const updatePayload: Record<string, unknown> = {};

  if (payload.product_based_costing_file_id !== undefined) {
    updatePayload.product_based_costing_file_id = payload.product_based_costing_file_id;
  }

  if (payload.name !== undefined) {
    updatePayload.name = normalizeText(payload.name);
  }

  if (payload.image_url !== undefined) {
    updatePayload.image_url = normalizeText(payload.image_url);
  }

  if (payload.note !== undefined) {
    updatePayload.note = normalizeText(payload.note);
  }

  if (payload.quantity !== undefined) {
    updatePayload.quantity = sanitizeNumeric(payload.quantity);
  }

  if (payload.barcode !== undefined) {
    updatePayload.barcode = normalizeText(payload.barcode);
  }

  if (payload.product_code !== undefined) {
    updatePayload.product_code = normalizeText(payload.product_code);
  }

  if (payload.brand !== undefined) {
    updatePayload.brand = normalizeText(payload.brand);
  }

  if (payload.vendor_code !== undefined) {
    updatePayload.vendor_code = normalizeText(payload.vendor_code);
  }

  if (payload.market_code !== undefined) {
    updatePayload.market_code = normalizeText(payload.market_code);
  }

  if (payload.web_link !== undefined) {
    updatePayload.web_link = normalizeText(payload.web_link);
  }

  if (payload.price_gbp !== undefined) {
    updatePayload.price_gbp = sanitizeNumeric(payload.price_gbp);
  }

  if (payload.product_weight !== undefined) {
    updatePayload.product_weight = sanitizeNumeric(payload.product_weight);
  }

  if (payload.package_weight !== undefined) {
    updatePayload.package_weight = sanitizeNumeric(payload.package_weight);
  }

  if (payload.confirmed_quantity !== undefined) {
    updatePayload.confirmed_quantity = sanitizeNumeric(payload.confirmed_quantity);
  }

  if (payload.offer_price !== undefined) {
    updatePayload.offer_price = sanitizeNumeric(payload.offer_price);
  }

  if (payload.is_offer_price_manual !== undefined) {
    updatePayload.is_offer_price_manual = payload.is_offer_price_manual;
  }

  if (payload.input_type !== undefined) {
    updatePayload.input_type = normalizeText(payload.input_type);
  }

  if (payload.assigned_shipment_id !== undefined) {
    updatePayload.assigned_shipment_id = payload.assigned_shipment_id;
  }

  return updatePayload;
};

const parseFilesListCursor = (
  raw: unknown,
): ProductBasedCostingFileListPage['meta']['next_cursor'] => {
  if (!raw || typeof raw !== 'object') return null;
  const cursor = raw as { created_at?: unknown; id?: unknown };
  const id = Number(cursor.id);
  if (!cursor.created_at || typeof cursor.created_at !== 'string' || !Number.isFinite(id)) {
    return null;
  }
  return { created_at: cursor.created_at, id };
};

const listProductBasedCostingFiles = async (
  payload: ProductBasedCostingFileListInput = {},
): Promise<ProductBasedCostingFileListPage> => {
  const limit = Math.max(1, Number(payload.limit ?? 20) || 20);
  const cursor = payload.cursor ?? null;
  const { data, error } = await supabase.rpc('list_product_based_costing_files', {
    p_search: payload.search?.trim() || null,
    p_status: payload.status?.trim() || null,
    p_tenant_id: null,
    p_limit: limit,
    p_cursor_created_at: cursor?.created_at ?? undefined,
    p_cursor_id: cursor?.id ?? undefined,
  });

  if (error) {
    throw error;
  }

  const envelope =
    (data as { data?: ProductBasedCostingFile[]; meta?: Record<string, unknown> } | null) ?? {};
  const rows = (envelope.data ?? []) as ProductBasedCostingFile[];
  const meta = envelope.meta ?? {};

  return {
    data: rows,
    meta: {
      has_more: Boolean(meta.has_more),
      next_cursor: parseFilesListCursor(meta.next_cursor),
      limit: Number(meta.limit ?? limit) || limit,
    },
  };
};

const createProductBasedCostingFile = async (
  payload: ProductBasedCostingFileCreateInput,
): Promise<ProductBasedCostingFile> => {
  const { data, error } = await supabase
    .from('product_based_costing_files')
    .insert([buildProductBasedCostingFileCreatePayload(payload)])
    .select()
    .single();

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error('Product based costing file was not created.');
  }

  return data as ProductBasedCostingFile;
};

const updateProductBasedCostingFile = async (
  payload: ProductBasedCostingFileUpdateInput,
): Promise<ProductBasedCostingFile> => {
  const { id, ...rest } = payload;

  const { data, error } = await supabase
    .from('product_based_costing_files')
    .update(buildProductBasedCostingFileUpdatePayload(rest))
    .eq('id', id)
    .select()
    .single();

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error('Product based costing file was not updated.');
  }

  return data as ProductBasedCostingFile;
};

const deleteProductBasedCostingFile = async (id: number): Promise<ProductBasedCostingFile> => {
  const { data, error } = await supabase
    .from('product_based_costing_files')
    .delete()
    .eq('id', id)
    .select()
    .single();

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error('Product based costing file was not deleted.');
  }

  return data as ProductBasedCostingFile;
};

const getProductBasedCostingFileById = async (id: number): Promise<ProductBasedCostingFile> => {
  const { data, error } = await supabase
    .from('product_based_costing_files')
    .select('*')
    .eq('id', id)
    .single();

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error('Product based costing file not found.');
  }

  return data as ProductBasedCostingFile;
};

const getProductBasedCostingFileSummary = async (
  fileId: number,
  rates: {
    conversion_rate?: number | null;
    cargo_rate_kg_gbp?: number | null;
    profit_rate?: number | null;
    vat_rate?: number | null;
    offer_pricing_mode?: string | null;
  } = {},
) => {
  const { data, error } = await supabase.rpc('get_product_based_costing_file_summary', {
    p_file_id: fileId,
    p_conversion_rate: rates.conversion_rate ?? null,
    p_cargo_rate_kg_gbp: rates.cargo_rate_kg_gbp ?? null,
    p_profit_rate: rates.profit_rate ?? null,
    p_vat_rate: rates.vat_rate ?? null,
    p_offer_pricing_mode: rates.offer_pricing_mode ?? null,
  });

  if (error) {
    throw error;
  }

  return (data ?? null) as Record<string, unknown> | null;
};

const listProductBasedCostingItems = async (
  productBasedCostingFileId: number,
): Promise<ProductBasedCostingItem[]> => {
  const { data, error } = await supabase
    .from('product_based_costing_items')
    .select('*')
    .eq('product_based_costing_file_id', productBasedCostingFileId)
    .order('sort_order', { ascending: true })
    .order('id', { ascending: true });

  if (error) {
    throw error;
  }

  return (data as ProductBasedCostingItem[] | null) ?? [];
};

const parseItemsListCursor = (
  raw: unknown,
): ProductBasedCostingItemListPage['meta']['next_cursor'] => {
  if (!raw || typeof raw !== 'object') return null;
  const cursor = raw as { sort_order?: unknown; id?: unknown };
  const sortOrder = Number(cursor.sort_order);
  const id = Number(cursor.id);
  if (!Number.isFinite(sortOrder) || !Number.isFinite(id)) {
    return null;
  }
  return { sort_order: sortOrder, id };
};

const listProductBasedCostingItemsPaginated = async (
  productBasedCostingFileId: number,
  payload: ProductBasedCostingItemListInput = {},
): Promise<ProductBasedCostingItemListPage> => {
  const limit = Math.max(1, Number(payload.limit ?? 25) || 25);
  const cursor = payload.cursor ?? null;
  const { data, error } = await supabase.rpc('list_product_based_costing_items', {
    p_file_id: productBasedCostingFileId,
    p_limit: limit,
    p_cursor_sort_order: cursor?.sort_order ?? undefined,
    p_cursor_id: cursor?.id ?? undefined,
  });

  if (error) {
    throw error;
  }

  const envelope =
    (data as { data?: ProductBasedCostingItem[]; meta?: Record<string, unknown> } | null) ?? {};
  const rows = (envelope.data ?? []) as ProductBasedCostingItem[];
  const meta = envelope.meta ?? {};

  return {
    data: rows,
    meta: {
      has_more: Boolean(meta.has_more),
      next_cursor: parseItemsListCursor(meta.next_cursor),
      limit: Number(meta.limit ?? limit) || limit,
    },
  };
};

const reorderProductBasedCostingItemToPosition = async (
  productBasedCostingFileId: number,
  itemId: number,
  targetPosition: number,
): Promise<void> => {
  const { data, error } = await supabase
    .from('product_based_costing_items')
    .select('id')
    .eq('product_based_costing_file_id', productBasedCostingFileId)
    .order('sort_order', { ascending: true })
    .order('id', { ascending: true });

  if (error) {
    throw error;
  }

  const items = data ?? [];
  const total = items.length;
  if (targetPosition < 1 || targetPosition > total) {
    throw new Error(`Position must be between 1 and ${total}.`);
  }

  const currentIndex = items.findIndex((row) => row.id === itemId);
  if (currentIndex === -1) {
    throw new Error('Product based costing item not found.');
  }

  const targetIndex = targetPosition - 1;
  if (currentIndex === targetIndex) {
    return;
  }

  const ordered = [...items];
  const [removed] = ordered.splice(currentIndex, 1);
  ordered.splice(targetIndex, 0, removed);

  await updateProductBasedCostingItemsOrder(
    ordered.map((row, idx) => ({
      id: row.id,
      sort_order: idx * 10,
    })),
  );
};

const createProductBasedCostingItem = async (
  payload: ProductBasedCostingItemCreateInput,
): Promise<ProductBasedCostingItem> => {
  const { data, error } = await supabase
    .from('product_based_costing_items')
    .insert([buildProductBasedCostingItemCreatePayload(payload)])
    .select()
    .single();

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error('Product based costing item was not created.');
  }

  return data as ProductBasedCostingItem;
};

const updateProductBasedCostingItem = async (
  payload: ProductBasedCostingItemUpdateInput,
): Promise<ProductBasedCostingItem> => {
  const { id, ...rest } = payload;

  const { data, error } = await supabase
    .from('product_based_costing_items')
    .update(buildProductBasedCostingItemUpdatePayload(rest))
    .eq('id', id)
    .select()
    .single();

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error('Product based costing item was not updated.');
  }

  return data as ProductBasedCostingItem;
};

const deleteProductBasedCostingItem = async (id: number): Promise<ProductBasedCostingItem> => {
  const { data, error } = await supabase
    .from('product_based_costing_items')
    .delete()
    .eq('id', id)
    .select()
    .single();

  if (error) {
    throw error;
  }

  if (!data) {
    throw new Error('Product based costing item was not deleted.');
  }

  return data as ProductBasedCostingItem;
};

const updateProductBasedCostingItemsByFileId = async (
  fileId: number,
  payload: Partial<ProductBasedCostingItem>,
): Promise<ProductBasedCostingItem[]> => {
  const { data, error } = await supabase
    .from('product_based_costing_items')
    .update(payload)
    .eq('product_based_costing_file_id', fileId)
    .select();

  if (error) {
    throw error;
  }

  return (data || []) as ProductBasedCostingItem[];
};

const getProductBasedCostingItemById = async (
  id: number,
): Promise<ProductBasedCostingItem | null> => {
  const { data, error } = await supabase
    .from('product_based_costing_items')
    .select('*')
    .eq('id', id)
    .maybeSingle();

  if (error) {
    throw error;
  }

  if (!data) {
    return null;
  }

  return data as ProductBasedCostingItem;
};

const recalculateProductBasedCostingFileOfferPrices = async (fileId: number): Promise<void> => {
  const { error } = await supabase.rpc('recalculate_product_based_costing_file_offer_prices', {
    p_file_id: fileId,
  });

  if (error) {
    throw error;
  }
};

const deleteProductBasedCostingItemsBulk = async (
  ids: number[],
): Promise<ProductBasedCostingItem[]> => {
  if (!ids.length) {
    return [];
  }

  const { data, error } = await supabase
    .from('product_based_costing_items')
    .delete()
    .in('id', ids)
    .select();

  if (error) {
    throw error;
  }

  return (data || []) as ProductBasedCostingItem[];
};

const updateProductBasedCostingItemsOrder = async (
  items: { id: number; sort_order: number }[],
): Promise<void> => {
  const { error } = await supabase.rpc('update_product_based_costing_items_order', {
    p_items: items,
  });

  if (error) {
    throw error;
  }
};

const addCostingItemToShipment = async (
  shipmentId: number,
  costingItemId: number,
): Promise<unknown> => {
  const { data, error } = await supabase.rpc('add_child_line_to_parent_shipment', {
    p_parent_shipment_id: shipmentId,
    p_source_type: 'costing_item',
    p_source_id: costingItemId,
  });

  if (error) {
    throw error;
  }

  return data;
};

const markPbcReadyForShipment = async (fileId: number) => {
  const { data, error } = await supabase.rpc('staff_mark_pbc_ready_for_shipment', {
    p_file_id: fileId,
  });

  if (error) {
    throw error;
  }

  return data;
};

export const productBasedCostingRepository = {
  listProductBasedCostingFiles,
  createProductBasedCostingFile,
  updateProductBasedCostingFile,
  deleteProductBasedCostingFile,
  getProductBasedCostingFileById,
  getProductBasedCostingFileSummary,

  listProductBasedCostingItems,
  listProductBasedCostingItemsPaginated,
  reorderProductBasedCostingItemToPosition,
  createProductBasedCostingItem,
  updateProductBasedCostingItem,
  updateProductBasedCostingItemsByFileId,
  deleteProductBasedCostingItem,
  deleteProductBasedCostingItemsBulk,
  updateProductBasedCostingItemsOrder,
  getProductBasedCostingItemById,
  recalculateProductBasedCostingFileOfferPrices,
  addCostingItemToShipment,
  markPbcReadyForShipment,
};
