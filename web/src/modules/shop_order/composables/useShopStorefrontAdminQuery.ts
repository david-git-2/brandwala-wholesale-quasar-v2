import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopStorefrontAdminRepository } from '../repositories/shopStorefrontAdminRepository';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';

export function useShopStorefrontAdminListingsQuery(
  shopId: Ref<number | null | undefined>,
  search: Ref<string>,
  enabled?: Ref<boolean>,
) {
  const enabledRef = enabled ?? computed(() => true);
  const searchParam = computed(() => search.value.trim() || null);

  return useQuery({
    queryKey: computed(() =>
      shopOrderQueryKeys.storefrontAdminListings(shopId.value ?? 0, searchParam.value),
    ),
    queryFn: () =>
      shopStorefrontAdminRepository.listStorefrontAdminListings(shopId.value!, {
        search: searchParam.value,
      }),
    enabled: computed(
      () => enabledRef.value && !!shopId.value && shopId.value > 0,
    ),
    staleTime: 60 * 1000,
  });
}
