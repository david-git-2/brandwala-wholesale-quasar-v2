import { appQueryClient } from 'src/query/queryClient';
import { shopPermissionsRepository } from '../repositories/shopPermissionsRepository';
import { fetchBooksCustomerGroupsCached } from '../utils/booksCustomerGroupsCache';
import type {
  CustomerGroupShopProfile,
  ShopCustomerGroupAccess,
  UpsertProfilePayload,
  UpsertAccessPayload,
  ShopServiceResult,
} from '../types';

interface CustomerGroup {
  id: number;
  name: string;
  is_active: boolean;
  accent_color: string | null;
}

const listCustomerGroups = async (
  booksTenantId: number,
): Promise<ShopServiceResult<CustomerGroup[]>> => {
  try {
    const data = await fetchBooksCustomerGroupsCached(appQueryClient, booksTenantId);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to list customer groups.',
    };
  }
};

const getProfile = async (
  tenantId: number,
  customerGroupId: number,
): Promise<ShopServiceResult<CustomerGroupShopProfile | null>> => {
  try {
    const data = await shopPermissionsRepository.getProfile(tenantId, customerGroupId);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to get customer group profile.',
    };
  }
};

const upsertProfile = async (
  payload: UpsertProfilePayload,
): Promise<ShopServiceResult<CustomerGroupShopProfile>> => {
  try {
    const data = await shopPermissionsRepository.upsertProfile(payload);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to save customer group profile.',
    };
  }
};

const listAccessOverrides = async (
  shopId: number,
): Promise<ShopServiceResult<ShopCustomerGroupAccess[]>> => {
  try {
    const data = await shopPermissionsRepository.listAccessOverrides(shopId);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to list shop access overrides.',
    };
  }
};

const upsertAccessOverride = async (
  payload: UpsertAccessPayload,
): Promise<ShopServiceResult<ShopCustomerGroupAccess>> => {
  try {
    const data = await shopPermissionsRepository.upsertAccessOverride(payload);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Failed to save shop access override.',
    };
  }
};

export const shopPermissionsService = {
  listCustomerGroups,
  getProfile,
  upsertProfile,
  listAccessOverrides,
  upsertAccessOverride,
};
