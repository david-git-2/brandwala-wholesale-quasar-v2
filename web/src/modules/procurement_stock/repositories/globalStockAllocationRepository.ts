import { supabase } from 'src/boot/supabase';
import type { PaginatedResult } from './globalShipmentRepository';

const db = supabase as any;

export interface GlobalStockAllocation {
  id: number;
  parent_tenant_id: number;
  child_tenant_id: number;
  stock_id: number;
  quantity: number;
  created_at: string;
  updated_at: string;

  // Joined fields
  child_tenant_name: string;
  pool_quantity: number;
  is_usable: boolean;
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
  stock_type_description: string;
  is_sellable: boolean;
}

export interface AllocatableStock {
  id: number;
  parent_tenant_id: number;
  shipment_item_id: number;
  stock_type_id: number;
  pool_quantity: number;
  is_usable: boolean;
  item_name: string;
  product_code: string | null;
  barcode: string | null;
  image_url: string | null;
  purchase_price: number;
  product_weight: number;
  package_weight: number;
  shipment_id: number;
  shipment_name: string;
  stock_type_description: string;
  is_sellable: boolean;
  allocated_qty: number;
  unallocated_qty: number;
}

export interface ChildAllocationSummary {
  child_tenant_id: number;
  child_tenant_name: string;
  allocation_id: number;
  allocated_qty: number;
}

export interface AllocationReconciliation {
  stock_id: number;
  global_qty: number;
  allocated_qty: number;
  unallocated_qty: number;
  is_reconciled: boolean;
}

const listPaginated = async (
  tenantId: number,
  page: number = 1,
  pageSize: number = 20,
  search?: string | null,
  childTenantId?: number | null,
  stockTypeId?: number | null,
): Promise<PaginatedResult<GlobalStockAllocation>> => {
  const { data, error } = await db.rpc('list_global_stock_allocations_paginated', {
    p_tenant_id: tenantId,
    p_page: page,
    p_page_size: pageSize,
    p_search: search || null,
    p_child_tenant_id: childTenantId || null,
    p_stock_type_id: stockTypeId || null,
  });

  if (error) {
    throw error;
  }

  const result = data as {
    data: GlobalStockAllocation[];
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

const listAllocatableStockPaginated = async (
  tenantId: number,
  page: number = 1,
  pageSize: number = 20,
  search?: string | null,
  shipmentId?: number | null,
  stockTypeId?: number | null,
): Promise<PaginatedResult<AllocatableStock>> => {
  const { data, error } = await db.rpc('list_allocatable_stock_paginated', {
    p_tenant_id: tenantId,
    p_page: page,
    p_page_size: pageSize,
    p_search: search || null,
    p_shipment_id: shipmentId || null,
    p_stock_type_id: stockTypeId || null,
  });

  if (error) {
    throw error;
  }

  const result = data as {
    data: AllocatableStock[];
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

const listChildAllocationSummary = async (stockId: number): Promise<ChildAllocationSummary[]> => {
  const { data, error } = await db.rpc('list_child_allocation_summary', {
    p_stock_id: stockId,
  });

  if (error) {
    throw error;
  }

  return (data as ChildAllocationSummary[]) || [];
};

const upsertGlobalStockAllocation = async (
  parentTenantId: number,
  childTenantId: number,
  stockId: number,
  quantity: number,
): Promise<any> => {
  const { data, error } = await db.rpc('upsert_global_stock_allocation', {
    p_parent_tenant_id: parentTenantId,
    p_child_tenant_id: childTenantId,
    p_stock_id: stockId,
    p_quantity: quantity,
  });

  if (error) {
    throw error;
  }

  return data;
};

const deleteGlobalStockAllocation = async (allocationId: number): Promise<void> => {
  const { error } = await db.rpc('delete_global_stock_allocation', {
    p_allocation_id: allocationId,
  });

  if (error) {
    throw error;
  }
};

const getAllocationReconciliation = async (stockId: number): Promise<AllocationReconciliation> => {
  const { data, error } = await db.rpc('get_allocation_reconciliation', {
    p_stock_id: stockId,
  });

  if (error) {
    throw error;
  }

  const rows = (data as AllocationReconciliation[]) || [];
  if (!rows.length) {
    return {
      stock_id: stockId,
      global_qty: 0,
      allocated_qty: 0,
      unallocated_qty: 0,
      is_reconciled: true,
    };
  }

  return rows[0]!;
};

export const globalStockAllocationRepository = {
  listPaginated,
  listAllocatableStockPaginated,
  listChildAllocationSummary,
  upsertGlobalStockAllocation,
  deleteGlobalStockAllocation,
  getAllocationReconciliation,
};
