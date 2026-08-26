import {
  dropshipCartRepository,
  type DropshipCartData,
  type DropshipReviewCartData,
} from '../repositories/dropshipCartRepository';
import type { ShopServiceResult } from '../types';

const getDropshipShopCart = async (
  shopId: number,
): Promise<ShopServiceResult<DropshipCartData>> => {
  try {
    const data = await dropshipCartRepository.getDropshipShopCart(shopId);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load dropship cart.',
    };
  }
};

const getDropshipReviewCart = async (
  shopId: number,
): Promise<ShopServiceResult<DropshipReviewCartData>> => {
  try {
    const data = await dropshipCartRepository.getDropshipReviewCart(shopId);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load dropship review cart.',
    };
  }
};

export const dropshipCartService = {
  getDropshipShopCart,
  getDropshipReviewCart,
};
