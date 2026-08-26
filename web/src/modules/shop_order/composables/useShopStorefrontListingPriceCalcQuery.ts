import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopStorefrontAdminRepository } from '../repositories/shopStorefrontAdminRepository';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';

export function useShopStorefrontListingPriceCalcQuery(
  shopId: Ref<number | null | undefined>,
  listingId: Ref<number | null | undefined>,
  enabled: Ref<boolean>,
) {
  return useQuery({
    queryKey: computed(() =>
      shopOrderQueryKeys.storefrontListingPriceCalc(shopId.value ?? 0, listingId.value ?? 0),
    ),
    queryFn: () =>
      shopStorefrontAdminRepository.getStorefrontListingPriceCalculation(
        shopId.value!,
        listingId.value!,
      ),
    enabled: computed(
      () =>
        enabled.value &&
        !!shopId.value &&
        shopId.value > 0 &&
        !!listingId.value &&
        listingId.value > 0,
    ),
    staleTime: 30 * 1000,
  });
}
