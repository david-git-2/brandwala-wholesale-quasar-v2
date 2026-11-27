import {
  dropshipCartRepository,
  type DropshipCartData,
  type DropshipReviewCartData,
  type SubmitDropshipOrderPayload,
  type SubmitDropshipOrderResult,
} from '../repositories/dropshipCartRepository';
import type { ShopServiceResult } from '../types';
import type { DropshipCartDeliveryDetails } from '../utils/dropshipCartDeliveryDetails';

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

const submitResellDiscountRequest = async (
  cartItemId: number,
  requestedPrice: number,
  reason: string,
): Promise<ShopServiceResult<DropshipReviewCartData>> => {
  try {
    const data = await dropshipCartRepository.submitResellDiscountRequest(
      cartItemId,
      requestedPrice,
      reason,
    );
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to submit discount request.',
    };
  }
};

const clearResellDiscountRequest = async (
  cartItemId: number,
): Promise<ShopServiceResult<DropshipReviewCartData>> => {
  try {
    const data = await dropshipCartRepository.clearResellDiscountRequest(cartItemId);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to remove discount request.',
    };
  }
};

const updateDeliveryDetails = async (
  shopId: number,
  deliveryDetails: DropshipCartDeliveryDetails,
): Promise<ShopServiceResult<DropshipReviewCartData>> => {
  try {
    const data = await dropshipCartRepository.updateDeliveryDetails(shopId, deliveryDetails);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to save delivery details.',
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
  submitResellDiscountRequest,
  clearResellDiscountRequest,
  updateDeliveryDetails,
  submitDropshipOrderFromCart,
};
