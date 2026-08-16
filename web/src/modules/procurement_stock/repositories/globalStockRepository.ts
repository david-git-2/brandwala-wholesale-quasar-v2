import { supabase } from 'src/boot/supabase';
import type { Database } from 'src/types/database.types';
import type { PaginatedResult } from './globalShipmentRepository';

const db = supabase as any;

export interface GlobalStock {
  id: number;
  parent_tenant_id: number;
  shipment_item_id: number;
  shipment_id: number;
  stock_type_id?: number | null;
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
  shipment_type: 'international' | 'local' | 'transfer';
  shipment_status: string;
  received_weight?: number | null;
  availability?: Database['public']['Enums']['stock_availability'] | null;
  location_id?: number | null;
  location_name?: string | null;
  grade_tag_id?: number | null;
  grade_name?: string | null;
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
  locationId?: number | null,
  availability?: Database['public']['Enums']['stock_availability'] | null,
  shipmentId?: number | null,
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
    p_location_id: locationId || null,
    p_availability: availability || null,
    p_shipment_id: shipmentId || null,
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
    stock_type_id?: number;
    availability?: Database['public']['Enums']['stock_availability'];
    location_id?: number;
    quantity: number;
    is_usable: boolean;
  }>,
): Promise<void> => {
  const { error } = await supabase
    .from('global_stocks')
    .upsert(stockRows, { onConflict: 'shipment_item_id,availability,location_id' });

  if (error) {
    throw error;
  }
};

const createAndPostMovement = async (payload: {
  tenantId: number;
  stockId: number;
  quantity: number;
  toLocationId?: number | null;
  toAvailability?: Database['public']['Enums']['stock_availability'] | null;
  toGradeTagId?: number | null;
  movementType?: Database['public']['Enums']['stock_movement_type'];
  notes?: string | null;
}): Promise<{ success: boolean; movement_id: number; movement_no: string }> => {
  const { data, error } = await db.rpc('create_and_post_stock_movement', {
    p_tenant_id: payload.tenantId,
    p_stock_id: payload.stockId,
    p_quantity: payload.quantity,
    p_to_location_id: payload.toLocationId || null,
    p_to_availability: payload.toAvailability || null,
    p_to_grade_tag_id: payload.toGradeTagId || null,
    p_movement_type: payload.movementType || 'grade_change',
    p_notes: payload.notes || null,
  });

  if (error) {
    throw error;
  }
  return data;
};

export const globalStockRepository = {
  listPaginated,
  fetchStocksByShipmentItem,
  saveStockSplits,
  createAndPostMovement,
};
