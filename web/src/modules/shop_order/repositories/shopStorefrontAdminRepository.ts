import { supabase } from 'src/boot/supabase';
import type {
  ShopStorefrontAdminListing,
  ShopStorefrontAdminListingsResult,
  ShopStorefrontListingPriceCalculation,
} from '../types';

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

const getStorefrontListingPriceCalculation = async (
  shopId: number,
  listingId: number,
): Promise<ShopStorefrontListingPriceCalculation> => {
  const { data, error } = await supabase.rpc('get_shop_storefront_listing_price_calculation', {
    p_shop_id: shopId,
    p_listing_id: listingId,
  });

  if (error) {
    throw error;
  }

  return data as ShopStorefrontListingPriceCalculation;
};

export const shopStorefrontAdminRepository = {
  listStorefrontAdminListings,
  getStorefrontListingPriceCalculation,
};

export type { ShopStorefrontAdminListing };
