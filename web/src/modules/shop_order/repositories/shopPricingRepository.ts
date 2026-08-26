import { supabase } from 'src/boot/supabase';
import type {
  ShopProductListing,
  CandidateAllocation,
  UpsertListingPayload,
  ShopPricingRule,
  UpsertShopPricingRulePayload,
} from '../types';


interface Currency {
  id: number;
  code: string;
  name: string;
}

const listListings = async (shopId: number): Promise<ShopProductListing[]> => {
  const { data, error } = await supabase.rpc('list_shop_product_listings', {
    p_shop_id: shopId,
  });

  if (error) {
    throw error;
  }

  return (data as ShopProductListing[] | null) ?? [];
};

const upsertListing = async (payload: UpsertListingPayload): Promise<ShopProductListing> => {
  const minPriceAmount =
    payload.minimum_sell_price_amount !== null && payload.minimum_sell_price_amount !== undefined
      ? Number(payload.minimum_sell_price_amount)
      : null;
  const minPriceCurrencyId =
    minPriceAmount !== null ? (payload.minimum_sell_price_currency_id ?? null) : null;

  const { data, error } = await supabase.rpc('upsert_shop_product_listing', {
    p_tenant_id: payload.tenant_id,
    p_shop_id: payload.shop_id,
    p_global_stock_allocation_id: null,
    p_global_stock_id: payload.global_stock_id ?? null,
    p_sell_price_amount: payload.sell_price_amount,
    p_sell_price_currency_id: payload.sell_price_currency_id,
    p_minimum_sell_price_amount: minPriceAmount,
    p_minimum_sell_price_currency_id: minPriceCurrencyId,
    p_show_quantity: payload.show_quantity ?? null,
    p_display_quantity_override: payload.display_quantity_override ?? null,
    p_is_active: payload.is_active ?? null,
    p_id: payload.id ?? null,
    p_is_price_locked: payload.is_price_locked ?? null,
    p_is_quantity_locked: payload.is_quantity_locked ?? null,
    p_quantity_override_type: payload.quantity_override_type ?? null,
    p_product_id: payload.product_id ?? null,
  });

  if (error) {
    throw error;
  }

  if (!data || (Array.isArray(data) && data.length === 0)) {
    throw new Error('Listing was not saved.');
  }

  return (Array.isArray(data) ? data[0] : data) as ShopProductListing;
};

const listCandidateAllocations = async (
  _tenantId: number,
  shopId: number,
): Promise<CandidateAllocation[]> => {
  const { data, error } = await supabase.rpc('list_listable_stock_for_shop', {
    p_shop_id: shopId,
  });

  if (error) {
    throw error;
  }

  const rawRows = (data as any)?.data ?? [];
  return rawRows.map((r: any) => ({
    allocation_id: r.global_stock_id,
    global_stock_id: r.global_stock_id,
    stock_id: r.global_stock_id,
    product_id: r.product_id,
    product_name: r.item_name,
    product_image_url: r.image_url,
    product_barcode: r.barcode,
    product_code: r.product_code,
    product_brand: null,
    product_category: null,
    allocated_quantity: r.available_atp,
    unit_cost_amount: r.unit_cost_amount,
    shipment_item_id: r.shipment_item_id,
    shipment_id: r.shipment_id,
    stock_grade: r.stock_grade ?? null,
  }));
};

import { globalReferenceRepository } from 'src/modules/global_reference/repositories/globalReferenceRepository';

const listCurrencies = async (): Promise<Currency[]> => {
  return globalReferenceRepository.listCurrencies();
};

const fetchPreviewProducts = async (
  vendorFilters: Array<{ vendor_code: string; brands: string[] }>
): Promise<any[]> => {
  if (!vendorFilters || vendorFilters.length === 0) {
    const { data, error } = await supabase
      .from('products')
      .select('*')
      .limit(12);

    if (error) {
      throw error;
    }
    return data ?? [];
  }

  const vendorCodes = vendorFilters.map(f => f.vendor_code);
  const { data, error } = await supabase
    .from('products')
    .select('*')
    .in('vendor_code', vendorCodes)
    .limit(100);

  if (error) {
    throw error;
  }

  const products = data ?? [];
  const filtered = products.filter(product => {
    const filterConfig = vendorFilters.find(
      f => f.vendor_code.toUpperCase() === product.vendor_code?.toUpperCase()
    );
    if (!filterConfig) return false;
    if (!filterConfig.brands || filterConfig.brands.length === 0) return true;
    return filterConfig.brands.some(
      b => b.toLowerCase() === product.brand?.toLowerCase()
    );
  });

  if (filtered.length === 0) {
    const { data: fallbackData } = await supabase
      .from('products')
      .select('*')
      .limit(12);
    return fallbackData ?? [];
  }

  return filtered.slice(0, 12);
};

const getPricingRule = async (shopId: number): Promise<ShopPricingRule | null> => {
  const { data, error } = await supabase
    .from('shop_pricing_rules')
    .select('*')
    .eq('shop_id', shopId)
    .maybeSingle();

  if (error) {
    throw error;
  }

  return (data as ShopPricingRule | null) ?? null;
};

const upsertPricingRule = async (
  payload: UpsertShopPricingRulePayload
): Promise<ShopPricingRule> => {
  const { data, error } = await supabase.rpc('upsert_shop_pricing_rule', {
    p_shop_id: payload.shop_id,
    p_markup_percentage: payload.markup_percentage,
    p_is_auto_publish: payload.is_auto_publish,
    p_default_show_quantity: payload.default_show_quantity ?? true,
    p_default_add_quantity: payload.default_add_quantity ?? 0,
    p_dropship_markup_percentage: payload.dropship_markup_percentage ?? 0,
  });

  if (error) {
    throw error;
  }

  if (!data || (Array.isArray(data) && data.length === 0)) {
    throw new Error('Pricing rule was not saved.');
  }

  return (Array.isArray(data) ? data[0] : data) as ShopPricingRule;
};

const bulkApplyMarkup = async (
  shopId: number,
  markupAmount?: number,
  markupType: 'percentage' | 'fixed' = 'percentage',
  targetPrice: 'sell_price' | 'min_sell_price' = 'sell_price',
  listingIds?: number[]
): Promise<number> => {
  const { data, error } = await supabase.rpc('bulk_apply_shop_markup', {
    p_shop_id: shopId,
    p_markup_amount: markupAmount ?? null,
    p_markup_type: markupType,
    p_target_price: targetPrice,
    p_listing_ids: listingIds ?? null,
  });

  if (error) {
    throw error;
  }

  return (data as number) ?? 0;
};

const deleteListing = async (listingId: number, tenantId: number): Promise<boolean> => {
  const { data, error } = await supabase.rpc('delete_shop_product_listing', {
    p_listing_id: listingId,
    p_tenant_id: tenantId,
  });

  if (error) {
    throw error;
  }

  return (data as boolean) ?? true;
};

export const shopPricingRepository = {
  listListings,
  upsertListing,
  deleteListing,
  listCandidateAllocations,
  listCurrencies,
  fetchPreviewProducts,
  getPricingRule,
  upsertPricingRule,
  bulkApplyMarkup,
};


