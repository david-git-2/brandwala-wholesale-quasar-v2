import { shopPermissionsRepository } from '../repositories/shopPermissionsRepository'
import type {
  CustomerGroupShopProfile,
  ShopCustomerGroupAccess,
  UpsertProfilePayload,
  UpsertAccessPayload,
  ShopServiceResult,
} from '../types'

interface CustomerGroup {
  id: number
  name: string
  is_active: boolean
}

interface Currency {
  id: number
  code: string
  name: string
}

const listCustomerGroups = async (tenantId: number): Promise<ShopServiceResult<CustomerGroup[]>> => {
  try {
    const data = await shopPermissionsRepository.listCustomerGroups(tenantId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to list customer groups.',
    }
  }
}

const getProfile = async (tenantId: number, customerGroupId: number): Promise<ShopServiceResult<CustomerGroupShopProfile | null>> => {
  try {
    const data = await shopPermissionsRepository.getProfile(tenantId, customerGroupId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to get customer group profile.',
    }
  }
}

const upsertProfile = async (payload: UpsertProfilePayload): Promise<ShopServiceResult<CustomerGroupShopProfile>> => {
  try {
    const data = await shopPermissionsRepository.upsertProfile(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to save customer group profile.',
    }
  }
}

const listAccessOverrides = async (shopId: number): Promise<ShopServiceResult<ShopCustomerGroupAccess[]>> => {
  try {
    const data = await shopPermissionsRepository.listAccessOverrides(shopId)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to list shop access overrides.',
    }
  }
}

const upsertAccessOverride = async (payload: UpsertAccessPayload): Promise<ShopServiceResult<ShopCustomerGroupAccess>> => {
  try {
    const data = await shopPermissionsRepository.upsertAccessOverride(payload)
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to save shop access override.',
    }
  }
}

const listCurrencies = async (): Promise<ShopServiceResult<Currency[]>> => {
  try {
    const data = await shopPermissionsRepository.listCurrencies()
    return { success: true, data }
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to list currencies.',
    }
  }
}

export const shopPermissionsService = {
  listCustomerGroups,
  getProfile,
  upsertProfile,
  listAccessOverrides,
  upsertAccessOverride,
  listCurrencies,
}
