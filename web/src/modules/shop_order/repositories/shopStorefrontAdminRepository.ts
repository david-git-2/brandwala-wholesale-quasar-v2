import { supabase } from 'src/boot/supabase';
import type { ShopStorefrontAdminListing, ShopStorefrontAdminListingsResult } from '../types';

const listStorefrontAdminListings = async (
  shopId: number,
  opts: { search?: string | null; limit?: number; offset?: number } = {},
): Promise<ShopStorefrontAdminListingsResult> => {
  const { data, error } = await supabase.rpc('list_shop_storefront_listings_for_admin', {
    p_shop_id: shopId,
    p_search: opts.search?.trim() || null,
    p_limit: opts.limit ?? 200,
    p_offset: opts.offset ?? 0,
  });

  if (error) {
    throw error;
  }

  const payload = (data ?? {}) as ShopStorefrontAdminListingsResult;
  return {
    data: payload.data ?? [],
    meta: payload.meta ?? {
      total: 0,
      page: 1,
      page_size: 0,
      total_pages: 1,
      shop: null,
    },
  };
};

export const shopStorefrontAdminRepository = {
  listStorefrontAdminListings,
};

export type { ShopStorefrontAdminListing };
