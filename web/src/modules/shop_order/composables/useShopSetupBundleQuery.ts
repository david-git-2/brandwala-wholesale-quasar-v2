import { useQuery, useQueryClient, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import { seedTenantSetupLookups } from '../utils/tenantSetupLookupCache';
import type { Shop } from '../types';

export function useShopSetupBundleQuery(tenantId: Ref<number>, shopId: Ref<number>) {
  const queryClient = useQueryClient();

  const query = useQuery({
    queryKey: computed(() => shopOrderQueryKeys.shopSetupBundle(tenantId.value, shopId.value)),
    queryFn: async () => {
      const bundle = await shopOrderRepository.getShopSetupBundle(shopId.value, tenantId.value);
      seedTenantSetupLookups(queryClient, bundle.shop.tenant_id, {
        categories: bundle.categories,
        vendors: bundle.vendors,
        brandsByVendor: bundle.brandsByVendor,
      });
      queryClient.setQueryData(
        shopOrderQueryKeys.shopDetail(tenantId.value, shopId.value),
        bundle.shop,
      );
      return bundle;
    },
    staleTime: 20 * 60 * 1000,
    placeholderData: keepPreviousData,
    refetchOnWindowFocus: false,
    enabled: computed(() => tenantId.value > 0 && shopId.value > 0),
  });

  const shop = computed<Shop | undefined>(() => query.data.value?.shop);
  const setupLookups = computed(() => {
    const data = query.data.value;
    if (!data) return undefined;
    return {
      categories: data.categories,
      vendors: data.vendors,
      brandsByVendor: data.brandsByVendor,
    };
  });

  const refresh = async () => {
    await queryClient.resetQueries({
      queryKey: shopOrderQueryKeys.shopSetupBundle(tenantId.value, shopId.value),
      exact: true,
    });
  };

  const isRefreshing = computed(
    () => query.isFetching.value && !query.isLoading.value && !!query.data.value,
  );

  return {
    ...query,
    shop,
    setupLookups,
    refresh,
    isRefreshing,
  };
}
