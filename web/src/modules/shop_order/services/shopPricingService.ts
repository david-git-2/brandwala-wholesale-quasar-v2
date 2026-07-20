import { shopPricingRepository } from '../repositories/shopPricingRepository';
import type {
  ShopProductListing,
  CandidateAllocation,
  UpsertListingPayload,
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

export const shopPricingService = {
  listListings,
  upsertListing,
  listCandidateAllocations,
  listCurrencies,
  fetchPreviewProducts,
};

