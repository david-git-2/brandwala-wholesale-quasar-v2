import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopPricingRepository } from '../repositories/shopPricingRepository';

export function useShopPricingListingsQuery(shopId: Ref<number | null | undefined>) {
  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.pricingListings(shopId.value ?? 0)),
    queryFn: () => shopPricingRepository.listListings(shopId.value!),
    enabled: computed(() => !!shopId.value && shopId.value > 0),
    staleTime: 2 * 60 * 1000,
  });
}

export function useShopPricingCandidatesQuery(
  tenantId: Ref<number | null | undefined>,
  shopId: Ref<number | null | undefined>,
  enabled?: Ref<boolean>,
) {
  const enabledRef = enabled ?? computed(() => true);
  return useQuery({
    queryKey: computed(() =>
      shopOrderQueryKeys.pricingCandidates(tenantId.value ?? 0, shopId.value ?? 0)
    ),
    queryFn: () => shopPricingRepository.listCandidateAllocations(tenantId.value!, shopId.value!),
    enabled: computed(
      () =>
        enabledRef.value &&
        !!tenantId.value &&
        tenantId.value > 0 &&
        !!shopId.value &&
        shopId.value > 0
    ),
    staleTime: 2 * 60 * 1000,
  });
}

export function useShopCurrenciesQuery() {
  return useQuery({
    queryKey: shopOrderQueryKeys.currencies(),
    queryFn: () => shopPricingRepository.listCurrencies(),
    staleTime: 10 * 60 * 1000,
  });
}

export function useShopPricingRuleQuery(shopId: Ref<number | null | undefined>) {
  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.pricingRule(shopId.value ?? 0)),
    queryFn: () => shopPricingRepository.getPricingRule(shopId.value!),
    enabled: computed(() => !!shopId.value && shopId.value > 0),
    staleTime: 5 * 60 * 1000,
  });
}
