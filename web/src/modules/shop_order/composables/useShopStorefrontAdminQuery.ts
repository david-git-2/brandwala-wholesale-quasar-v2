import { useInfiniteQuery, keepPreviousData, useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopStorefrontAdminRepository } from '../repositories/shopStorefrontAdminRepository';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import type { ShopStorefrontAdminListing, ShopStorefrontAdminListingsResult } from '../types';

export const STOREFRONT_ADMIN_LISTINGS_PAGE_SIZE = 20;

export type ShopStorefrontAdminListingsPage = {
  listings: ShopStorefrontAdminListing[];
  meta: ShopStorefrontAdminListingsResult['meta'];
  nextOffset: number;
  total: number;
};

export function useShopStorefrontAdminListingsInfiniteQuery(
  shopId: Ref<number | null | undefined>,
  search: Ref<string>,
  enabled?: Ref<boolean>,
) {
  const enabledRef = enabled ?? computed(() => true);
  const searchParam = computed(() => search.value.trim() || null);

  return useInfiniteQuery({
    queryKey: computed(() =>
      shopOrderQueryKeys.storefrontAdminListings(shopId.value ?? 0, searchParam.value),
    ),
    queryFn: async ({ pageParam = 0 }) => {
      const result = await shopStorefrontAdminRepository.listStorefrontAdminListings(
        shopId.value!,
        {
          search: searchParam.value,
          limit: STOREFRONT_ADMIN_LISTINGS_PAGE_SIZE,
          offset: pageParam as number,
        },
      );

      const listings = result.data;
      const total = result.meta.total ?? listings.length;

      return {
        listings,
        meta: result.meta,
        nextOffset: (pageParam as number) + listings.length,
        total,
      } satisfies ShopStorefrontAdminListingsPage;
    },
    getNextPageParam: (lastPage) => {
      if (lastPage.nextOffset < lastPage.total && lastPage.listings.length > 0) {
        return lastPage.nextOffset;
      }
      return undefined;
    },
    initialPageParam: 0,
    staleTime: 60 * 1000,
    placeholderData: keepPreviousData,
    enabled: computed(
      () => enabledRef.value && !!shopId.value && shopId.value > 0,
    ),
  });
}

/** @deprecated Use useShopStorefrontAdminListingsInfiniteQuery */
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
        limit: STOREFRONT_ADMIN_LISTINGS_PAGE_SIZE,
        offset: 0,
      }),
    enabled: computed(
      () => enabledRef.value && !!shopId.value && shopId.value > 0,
    ),
    staleTime: 60 * 1000,
  });
}
