import { cartRepository } from '../repositories/cartRepository'
import type {
  AddItemToCartInput,
  AddItemToCartResult,
  Cart,
  CartCreateInput,
  CartDeleteInput,
  CartItem,
  CartItemCreateInput,
  CartItemDeleteInput,
  CartItemUpdateInput,
  CartServiceResult,
  CartUpdateInput,
  CartWithItemDetails,
  CartWithItems,
} from '../types'

const listCarts = async (): Promise<CartServiceResult<Cart[]>> => {
  try {
    const data = await cartRepository.listCarts()
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load carts.',
    }
  }
}

const findCart = async (payload: {
  tenant_id: number
  store_id?: number | null
  customer_group_id?: number | null
}): Promise<CartServiceResult<Cart | null>> => {
  try {
    const data = await cartRepository.findCart(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to find cart.',
    }
  }
}

const createCart = async (payload: CartCreateInput): Promise<CartServiceResult<Cart>> => {
  try {
    const data = await cartRepository.createCart(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create cart.',
    }
  }
}

const updateCart = async (payload: CartUpdateInput): Promise<CartServiceResult<Cart>> => {
  try {
    const data = await cartRepository.updateCart(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update cart.',
    }
  }
}

const deleteCart = async (
  payload: CartDeleteInput,
): Promise<CartServiceResult<Cart>> => {
  try {
    const data = await cartRepository.deleteCart(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete cart.',
    }
  }
}

const listCartItems = async (cartId: number): Promise<CartServiceResult<CartItem[]>> => {
  try {
    const data = await cartRepository.listCartItems(cartId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load cart items.',
    }
  }
}

const findCartItemByProduct = async (payload: {
  cart_id: number
  product_id: number
}): Promise<CartServiceResult<CartItem | null>> => {
  try {
    const data = await cartRepository.findCartItemByProduct(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to find cart item.',
    }
  }
}

const createCartItem = async (
  payload: CartItemCreateInput,
): Promise<CartServiceResult<CartItem>> => {
  try {
    const data = await cartRepository.createCartItem(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create cart item.',
    }
  }
}

const updateCartItem = async (
  payload: CartItemUpdateInput,
): Promise<CartServiceResult<CartItem>> => {
  try {
    const data = await cartRepository.updateCartItem(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update cart item.',
    }
  }
}

const deleteCartItem = async (
  payload: CartItemDeleteInput,
): Promise<CartServiceResult<CartItem>> => {
  try {
    const data = await cartRepository.deleteCartItem(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete cart item.',
    }
  }
}

const deleteCartItemsBulk = async (
  itemIds: number[],
): Promise<CartServiceResult<CartItem[]>> => {
  try {
    const data = await cartRepository.deleteCartItemsBulk(itemIds)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete cart items.',
    }
  }
}

const getCart = async (cartId: number): Promise<CartServiceResult<CartWithItems>> => {
  try {
    const data = await cartRepository.getCart(cartId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load cart.',
    }
  }
}

const getCartDetails = async (
  cartId: number,
): Promise<CartServiceResult<CartWithItemDetails>> => {
  try {
    const data = await cartRepository.getCartDetails(cartId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load cart details.',
    }
  }
}

const addItemToCart = async (
  payload: AddItemToCartInput,
): Promise<CartServiceResult<AddItemToCartResult>> => {
  try {
    const data = await cartRepository.addItemToCart(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to add item to cart.',
    }
  }
}

export const cartService = {
  listCarts,
  findCart,
  createCart,
  updateCart,
  deleteCart,
  listCartItems,
  findCartItemByProduct,
  createCartItem,
  updateCartItem,
  deleteCartItem,
  deleteCartItemsBulk,
  getCart,
  getCartDetails,
  addItemToCart,
}
