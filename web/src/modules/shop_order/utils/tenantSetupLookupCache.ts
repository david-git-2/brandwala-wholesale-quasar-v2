import type { QueryClient } from '@tanstack/vue-query';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import type { ShopSetupTenantLookups } from '../types';

const TENANT_SETUP_TTL_MS = 20 * 60 * 1000;

type TenantSetupCacheEntry = ShopSetupTenantLookups & { fetchedAt: number };

const memoryByTenant = new Map<number, TenantSetupCacheEntry>();

export function readTenantSetupLookups(tenantId: number): ShopSetupTenantLookups | null {
  const hit = memoryByTenant.get(tenantId);
  if (!hit || Date.now() - hit.fetchedAt > TENANT_SETUP_TTL_MS) {
    return null;
  }
  return {
    categories: hit.categories,
    vendors: hit.vendors,
    brandsByVendor: hit.brandsByVendor,
  };
}

export function writeTenantSetupLookups(tenantId: number, lookups: ShopSetupTenantLookups) {
  memoryByTenant.set(tenantId, { ...lookups, fetchedAt: Date.now() });
}

export function seedTenantSetupLookups(
  queryClient: QueryClient,
  tenantId: number,
  lookups: ShopSetupTenantLookups,
) {
  writeTenantSetupLookups(tenantId, lookups);
  queryClient.setQueryData(shopOrderQueryKeys.categories(tenantId), lookups.categories);
  queryClient.setQueryData(shopOrderQueryKeys.vendorsList(tenantId), lookups.vendors);
  queryClient.setQueryData(shopOrderQueryKeys.tenantBrandsByVendor(tenantId), lookups.brandsByVendor);
}

export function invalidateTenantSetupLookups(queryClient: QueryClient, tenantId: number) {
  memoryByTenant.delete(tenantId);
  void queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.categories(tenantId) });
  void queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.vendorsList(tenantId) });
  void queryClient.invalidateQueries({ queryKey: shopOrderQueryKeys.tenantBrandsByVendor(tenantId) });
}
