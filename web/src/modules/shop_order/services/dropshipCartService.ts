import {
  dropshipCartRepository,
  type DropshipCartData,
  type DropshipReviewCartData,
  type SubmitDropshipOrderPayload,
  type SubmitDropshipOrderResult,
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

const submitDropshipOrderFromCart = async (
  payload: SubmitDropshipOrderPayload,
): Promise<ShopServiceResult<SubmitDropshipOrderResult>> => {
  try {
    const data = await dropshipCartRepository.submitDropshipOrderFromCart(payload);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to place dropship order.',
    };
  }
};

export const dropshipCartService = {
  getDropshipShopCart,
  getDropshipReviewCart,
  submitDropshipOrderFromCart,
};
