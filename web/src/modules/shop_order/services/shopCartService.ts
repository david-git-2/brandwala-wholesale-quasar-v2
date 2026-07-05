import { shopCartRepository, type CartData } from '../repositories/shopCartRepository'
import type { ShopServiceResult } from '../types'

const getOrCreateCart = async (shopId: number): Promise<ShopServiceResult<CartData>> => {
  try {
    const data = await shopCartRepository.getOrCreateCart(shopId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to retrieve or create cart.',
    }
  }
}

const addToCart = async (
  shopId: number,
  productId: number,
  globalStockAllocationId: number | null,
  quantity: number,
  customerSellPriceAmount?: number | null,
  customerSellPriceCurrencyId?: number | null,
): Promise<ShopServiceResult<CartData>> => {
  try {
    const data = await shopCartRepository.addToCart(
      shopId,
      productId,
      globalStockAllocationId,
      quantity,
      customerSellPriceAmount,
      customerSellPriceCurrencyId,
    )
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to add item to cart.',
    }
  }
}

const updateCartItemQty = async (cartItemId: number, quantity: number): Promise<ShopServiceResult<CartData>> => {
  try {
    const data = await shopCartRepository.updateCartItemQty(cartItemId, quantity)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update item quantity.',
    }
  }
}

const removeCartItem = async (cartItemId: number): Promise<ShopServiceResult<CartData>> => {
  try {
    const data = await shopCartRepository.removeCartItem(cartItemId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to remove item from cart.',
    }
  }
}

export const shopCartService = {
  getOrCreateCart,
  addToCart,
  updateCartItemQty,
  removeCartItem,
}
