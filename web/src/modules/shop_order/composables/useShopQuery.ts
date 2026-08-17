import { useQuery, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import { vendorRepository } from 'src/modules/vendor/repositories/vendorRepository';

export interface ShopListQueryParams {
  tenantId: number;
  search?: string | null;
  active?: boolean | null;
}

export function useShopDetailQuery(tenantId: Ref<number>, shopId: Ref<number>) {
  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.shopDetail(tenantId.value, shopId.value)),
    queryFn: () => shopOrderRepository.getShop(shopId.value, tenantId.value),
    staleTime: 2 * 60 * 1000,
    enabled: computed(() => !!tenantId.value && !!shopId.value),
  });
}

export function useShopListQuery(params: Ref<ShopListQueryParams>) {
  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.shopsList(params.value)),
    queryFn: () =>
      shopOrderRepository.listShops(params.value.tenantId, {
        search: params.value.search ?? null,
        active: params.value.active ?? null,
      }),
    staleTime: 2 * 60 * 1000,
    placeholderData: keepPreviousData,
    enabled: computed(() => !!params.value.tenantId),
  });
}

export function useVendorListQuery(tenantId: Ref<number>) {
  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.vendorsList(tenantId.value)),
    queryFn: () => vendorRepository.listVendors(tenantId.value),
    staleTime: 5 * 60 * 1000,
    enabled: computed(() => !!tenantId.value),
  });
}

export function useCustomerShopsQuery(tenantId: Ref<number | null>) {
  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.customerShops(tenantId.value)),
    queryFn: () => {
      if (!tenantId.value) return Promise.resolve([]);
      return shopOrderRepository.listCustomerShops(tenantId.value);
    },
    staleTime: 2 * 60 * 1000,
    enabled: computed(() => !!tenantId.value),
  });
}
