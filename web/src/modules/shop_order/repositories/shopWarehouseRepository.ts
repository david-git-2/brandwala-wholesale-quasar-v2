import { supabase } from 'src/boot/supabase';
import type { ShopAllocatedStockResult } from '../types';

const listAllocatedStockForShop = async (
  shopId: number,
  opts: { search?: string | null; limit?: number; offset?: number } = {},
): Promise<ShopAllocatedStockResult> => {
  const { data, error } = await supabase.rpc('list_allocated_stock_for_shop', {
    p_shop_id: shopId,
    p_search: opts.search?.trim() || null,
    p_limit: opts.limit ?? 200,
    p_offset: opts.offset ?? 0,
  });

  if (error) {
    throw error;
  }

  const payload = (data ?? {}) as ShopAllocatedStockResult;
  return {
    data: payload.data ?? [],
    meta: payload.meta ?? {
      total: 0,
      page: 1,
      page_size: 0,
      total_pages: 1,
    },
  };
};

export const shopWarehouseRepository = {
  listAllocatedStockForShop,
};
