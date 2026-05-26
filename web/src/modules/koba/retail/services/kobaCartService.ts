import { kobaCartRepository } from '../repositories/kobaCartRepository'
import type { KobaCart, KobaCartItem, KobaCartSnapshot } from '../repositories/kobaCartRepository'

export interface KobaCartServiceResult<T> {
  success: boolean
  data?: T
  error?: string
}

const getCart = async (tenantId: number, marketId: string | null): Promise<KobaCartServiceResult<KobaCartSnapshot | null>> => {
  try {
    const data = await kobaCartRepository.getCart(tenantId, marketId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load Koba cart.',
    }
  }
}

const createCart = async (tenantId: number, userEmail: string, marketId: string | null): Promise<KobaCartServiceResult<KobaCart>> => {
  try {
    const data = await kobaCartRepository.createCart(tenantId, userEmail, marketId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create Koba cart.',
    }
  }
}

const createCartItem = async (payload: Partial<KobaCartItem>): Promise<KobaCartServiceResult<KobaCartItem>> => {
  try {
    const data = await kobaCartRepository.createCartItem(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to add item to Koba cart.',
    }
  }
}

const updateCartItem = async (itemId: number, payload: Partial<KobaCartItem>): Promise<KobaCartServiceResult<KobaCartItem>> => {
  try {
    const data = await kobaCartRepository.updateCartItem(itemId, payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update Koba cart item.',
    }
  }
}

const deleteCartItem = async (itemId: number): Promise<KobaCartServiceResult<KobaCartItem>> => {
  try {
    const data = await kobaCartRepository.deleteCartItem(itemId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete Koba cart item.',
    }
  }
}

const clearCartItems = async (cartId: number): Promise<KobaCartServiceResult<void>> => {
  try {
    await kobaCartRepository.clearCartItems(cartId)
    return { success: true }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to clear Koba cart.',
    }
  }
}

export const kobaCartService = {
  getCart,
  createCart,
  createCartItem,
  updateCartItem,
  deleteCartItem,
  clearCartItems,
}
