import { shopPricingRepository } from '../repositories/shopPricingRepository';
import type {
  ShopProductListing,
  CandidateAllocation,
  UpsertListingPayload,
  ShopPricingRule,
  UpsertShopPricingRulePayload,
  ShopServiceResult,
} from '../types';

interface Currency {
  id: number;
  code: string;
  name: string;
}

const listListings = async (shopId: number): Promise<ShopServiceResult<ShopProductListing[]>> => {
  try {
    const data = await shopPricingRepository.listListings(shopId);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to list product listings.',
    };
  }
};

const upsertListing = async (
  payload: UpsertListingPayload,
): Promise<ShopServiceResult<ShopProductListing>> => {
  try {
    const data = await shopPricingRepository.upsertListing(payload);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to save product listing.',
    };
  }
};

const listCandidateAllocations = async (
  tenantId: number,
  shopId: number,
): Promise<ShopServiceResult<CandidateAllocation[]>> => {
  try {
    const data = await shopPricingRepository.listCandidateAllocations(tenantId, shopId);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to list candidate stock allocations.',
    };
  }
};

const listCurrencies = async (): Promise<ShopServiceResult<Currency[]>> => {
  try {
    const data = await shopPricingRepository.listCurrencies();
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to list currencies.',
    };
  }
};

const fetchPreviewProducts = async (
  vendorFilters: Array<{ vendor_code: string; brands: string[] }>
): Promise<ShopServiceResult<any[]>> => {
  try {
    const data = await shopPricingRepository.fetchPreviewProducts(vendorFilters);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to fetch preview products.',
    };
  }
};

const getPricingRule = async (shopId: number): Promise<ShopServiceResult<ShopPricingRule | null>> => {
  try {
    const data = await shopPricingRepository.getPricingRule(shopId);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to fetch pricing rule.',
    };
  }
};

const savePricingRule = async (
  payload: UpsertShopPricingRulePayload
): Promise<ShopServiceResult<ShopPricingRule>> => {
  try {
    const data = await shopPricingRepository.upsertPricingRule(payload);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to save pricing rule.',
    };
  }
};

const bulkApplyMarkup = async (
  shopId: number,
  markupAmount?: number,
  markupType: 'percentage' | 'fixed' = 'percentage',
  targetPrice: 'sell_price' | 'min_sell_price' = 'sell_price',
  listingIds?: number[]
): Promise<ShopServiceResult<number>> => {
  try {
    const data = await shopPricingRepository.bulkApplyMarkup(shopId, markupAmount, markupType, targetPrice, listingIds);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to bulk apply markup.',
    };
  }
};

export const shopPricingService = {
  listListings,
  upsertListing,
  listCandidateAllocations,
  listCurrencies,
  fetchPreviewProducts,
  getPricingRule,
  savePricingRule,
  bulkApplyMarkup,
};


