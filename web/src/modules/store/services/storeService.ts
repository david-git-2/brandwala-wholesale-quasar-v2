import { storeRepository } from '../repositories/storeRepository'
import type {
  Store,
  StoreAccess,
  StoreAccessCreateInput,
  StoreAccessDeleteInput,
  StoreCart,
  StoreCartCreateInput,
  StoreCartDeleteInput,
  StoreCartDetailedPayload,
  StoreCartItem,
  StoreCartItemCreateInput,
  StoreCartItemDeleteInput,
  StoreCartItemUpdateInput,
  StoreCartPayload,
  StoreCartUpdateInput,
  StoreProductsPage,
  StoreProductsQueryInput,
  StoreAccessUpdateInput,
  StoreCreateInput,
  StoreDeleteInput,
  StoreServiceResult,
  StoreUpdateInput,
} from '../types'

const getStoresAdmin = async (tenantId: number): Promise<StoreServiceResult<Store[]>> => {
  try {
    const data = await storeRepository.getStoresAdmin(tenantId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load stores.',
    }
  }
}

const createStore = async (payload: StoreCreateInput): Promise<StoreServiceResult<Store>> => {
  try {
    const data = await storeRepository.createStore(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create store.',
    }
  }
}

const updateStore = async (payload: StoreUpdateInput): Promise<StoreServiceResult<Store>> => {
  try {
    const data = await storeRepository.updateStore(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update store.',
    }
  }
}

const deleteStore = async (
  payload: StoreDeleteInput,
): Promise<StoreServiceResult<void>> => {
  try {
    await storeRepository.deleteStore(payload)
    return { success: true }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete store.',
    }
  }
}

const getStoreAccessAdmin = async (
  storeId?: number | null,
): Promise<StoreServiceResult<StoreAccess[]>> => {
  try {
    const data = await storeRepository.getStoreAccessAdmin(storeId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load store access.',
    }
  }
}

const createStoreAccess = async (
  payload: StoreAccessCreateInput,
): Promise<StoreServiceResult<StoreAccess>> => {
  try {
    const data = await storeRepository.createStoreAccess(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create store access.',
    }
  }
}

const updateStoreAccess = async (
  payload: StoreAccessUpdateInput,
): Promise<StoreServiceResult<StoreAccess>> => {
  try {
    const data = await storeRepository.updateStoreAccess(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update store access.',
    }
  }
}

const deleteStoreAccess = async (
  payload: StoreAccessDeleteInput,
): Promise<StoreServiceResult<void>> => {
  try {
    await storeRepository.deleteStoreAccess(payload)
    return { success: true }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete store access.',
    }
  }
}

const getStoresForCustomer = async (): Promise<StoreServiceResult<Store[]>> => {
  try {
    const data = await storeRepository.getStoresForCustomer()
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load customer stores.',
    }
  }
}

const getStoreProductBrands = async (
  storeId: number,
): Promise<StoreServiceResult<string[]>> => {
  try {
    const data = await storeRepository.getStoreProductBrands(storeId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load brands.',
    }
  }
}

const getStoreProductCategories = async (
  storeId: number,
): Promise<StoreServiceResult<string[]>> => {
  try {
    const data = await storeRepository.getStoreProductCategories(storeId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load categories.',
    }
  }
}

const checkStoreAccess = async (
  storeId: number,
): Promise<StoreServiceResult<boolean>> => {
  try {
    const data = await storeRepository.checkStoreAccess(storeId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to check store access.',
    }
  }
}

const checkStorePriceAccess = async (
  storeId: number,
): Promise<StoreServiceResult<boolean>> => {
  try {
    const data = await storeRepository.checkStorePriceAccess(storeId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to check store price access.',
    }
  }
}

const listStoreProducts = async (
  payload: StoreProductsQueryInput,
): Promise<StoreServiceResult<StoreProductsPage>> => {
  try {
    const data = await storeRepository.listStoreProducts(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load store products.',
    }
  }
}

const getCart = async (cartId: number): Promise<StoreServiceResult<StoreCartPayload>> => {
  try {
    const data = await storeRepository.getCart(cartId)
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
): Promise<StoreServiceResult<StoreCartDetailedPayload>> => {
  try {
    const data = await storeRepository.getCartDetails(cartId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to load cart details.',
    }
  }
}

const createCart = async (
  payload: StoreCartCreateInput,
): Promise<StoreServiceResult<StoreCart>> => {
  try {
    const data = await storeRepository.createCart(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create cart.',
    }
  }
}

const updateCart = async (
  payload: StoreCartUpdateInput,
): Promise<StoreServiceResult<StoreCart>> => {
  try {
    const data = await storeRepository.updateCart(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update cart.',
    }
  }
}

const deleteCart = async (
  payload: StoreCartDeleteInput,
): Promise<StoreServiceResult<StoreCart>> => {
  try {
    const data = await storeRepository.deleteCart(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete cart.',
    }
  }
}

const createCartItem = async (
  payload: StoreCartItemCreateInput,
): Promise<StoreServiceResult<StoreCartItem>> => {
  try {
    const data = await storeRepository.createCartItem(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create cart item.',
    }
  }
}

const updateCartItem = async (
  payload: StoreCartItemUpdateInput,
): Promise<StoreServiceResult<StoreCartItem>> => {
  try {
    const data = await storeRepository.updateCartItem(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update cart item.',
    }
  }
}

const deleteCartItem = async (
  payload: StoreCartItemDeleteInput,
): Promise<StoreServiceResult<StoreCartItem>> => {
  try {
    const data = await storeRepository.deleteCartItem(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete cart item.',
    }
  }
}

export const storeService = {
  getStoresAdmin,
  createStore,
  updateStore,
  deleteStore,
  getStoreAccessAdmin,
  createStoreAccess,
  updateStoreAccess,
  deleteStoreAccess,
  getStoresForCustomer,
  getStoreProductBrands,
  getStoreProductCategories,
  checkStoreAccess,
  checkStorePriceAccess,
  listStoreProducts,
  getCart,
  getCartDetails,
  createCart,
  updateCart,
  deleteCart,
  createCartItem,
  updateCartItem,
  deleteCartItem,
}
