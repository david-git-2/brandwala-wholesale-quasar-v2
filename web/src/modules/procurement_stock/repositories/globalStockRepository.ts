import { supabase } from 'src/boot/supabase';
import type { PaginatedResult } from './globalShipmentRepository';

const db = supabase as any;

export interface GlobalStock {
  id: number;
  parent_tenant_id: number;
  shipment_item_id: number;
  shipment_id: number;
  stock_type_id: number;
  quantity: number;
  is_usable: boolean;
  created_at: string;
  updated_at: string;
  ordered_quantity: number;

  // Joined fields
  item_name: string;
  product_code: string | null;
  barcode: string | null;
  image_url: string | null;
  purchase_price: number;
  product_weight: number;
  package_weight: number;
  shipment_name: string;
  shipment_type: 'domestic' | 'international';
  shipment_status: string;
  product_conversion_rate: number;
  cargo_conversion_rate: number;
  cargo_rate: number;
  received_weight: number | null;
  transaction_rate: number | null;
  stock_type_description: string;
  is_sellable: boolean;
}

const listPaginated = async (
  tenantId: number,
  page: number = 1,
  pageSize: number = 20,
  search?: string,
  stockTypeId?: number | null,
  isSellable?: boolean | null,
  shipmentStatus?: string | null,
  hideZeroStock: boolean = true,
): Promise<PaginatedResult<GlobalStock>> => {
  const { data, error } = await db.rpc('list_global_stocks_paginated', {
    p_tenant_id: tenantId,
    p_page: page,
    p_page_size: pageSize,
    p_search: search || null,
    p_stock_type_id: stockTypeId || null,
    p_is_sellable: isSellable === undefined ? null : isSellable,
    p_shipment_status: shipmentStatus || null,
    p_hide_zero_stock: hideZeroStock,
  });

  if (error) {
    throw error;
  }

  const result = data as {
    data: GlobalStock[];
    meta: {
      total: number;
      page: number;
      page_size: number;
      total_pages: number;
    };
  };

  return {
    data: result.data || [],
    meta: {
      total: result.meta?.total || 0,
      page: result.meta?.page || page,
      pageSize: result.meta?.page_size || pageSize,
      totalPages: result.meta?.total_pages || 1,
    },
  };
};

const fetchStocksByShipmentItem = async (shipmentItemId: number): Promise<GlobalStock[]> => {
  const { data, error } = await supabase
    .from('global_stocks')
    .select('*')
    .eq('shipment_item_id', shipmentItemId);

  if (error) {
    throw error;
  }
  return data as any[];
};

const saveStockSplits = async (
  stockRows: Array<{
    parent_tenant_id: number;
    shipment_item_id: number;
    stock_type_id: number;
    quantity: number;
    is_usable: boolean;
  }>,
): Promise<void> => {
  const { error } = await supabase
    .from('global_stocks')
    .upsert(stockRows, { onConflict: 'shipment_item_id,stock_type_id,is_usable' });

  if (error) {
    throw error;
  }
};

export const globalStockRepository = {
  listPaginated,
  fetchStocksByShipmentItem,
  saveStockSplits,
};
