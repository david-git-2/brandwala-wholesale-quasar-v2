import { storeRepository } from '../repositories/storeRepository'
import type {
  Store,
  StoreAccess,
  StoreAccessCreateInput,
  StoreAccessDeleteInput,
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
  storeId: number,
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
  checkStoreAccess,
}
