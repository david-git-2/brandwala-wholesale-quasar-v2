import { commerceCartRepository } from '../repositories/commerceCartRepository'
import type { AddCommerceItemInput, CommerceCartItem, CommerceCartServiceResult } from '../types'

const listCartItems = async (
  tenantId: number,
  customerGroupId: number,
  storeId: number | null,
): Promise<CommerceCartServiceResult<CommerceCartItem[]>> => {
  try {
    const data = await commerceCartRepository.listCartItems(tenantId, customerGroupId, storeId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to list commerce cart items.',
    }
  }
}

const addToCommerceCart = async (
  payload: AddCommerceItemInput,
): Promise<CommerceCartServiceResult<CommerceCartItem>> => {
  try {
    const data = await commerceCartRepository.addToCommerceCart(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to add item to commerce cart.',
    }
  }
}

const updateCommerceCartQty = async (payload: {
  id: number
  quantity: number
}): Promise<CommerceCartServiceResult<{ id: number; quantity: number }>> => {
  try {
    const data = await commerceCartRepository.updateCommerceCartQty(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update commerce cart quantity.',
    }
  }
}

const deleteCommerceCartItem = async (payload: {
  id: number
}): Promise<CommerceCartServiceResult<void>> => {
  try {
    await commerceCartRepository.deleteCommerceCartItem(payload)
    return { success: true }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete commerce cart item.',
    }
  }
}

const clearCommerceCart = async (payload: {
  tenant_id: number
  customer_group_id: number
}): Promise<CommerceCartServiceResult<void>> => {
  try {
    await commerceCartRepository.clearCommerceCart(payload)
    return { success: true }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to clear commerce cart.',
    }
  }
}

export const commerceCartService = {
  listCartItems,
  addToCommerceCart,
  updateCommerceCartQty,
  deleteCommerceCartItem,
  clearCommerceCart,
}
