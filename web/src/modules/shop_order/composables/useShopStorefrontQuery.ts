import { useInfiniteQuery, keepPreviousData, useQueryClient } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopOrderService } from '../services/shopOrderService';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { ShopCatalogItem, Shop } from '../types';
import {
  seedCustomerShopPermissions,
  type CustomerShopPermissions,
} from './useCustomerShopPermissionsQuery';

export interface StorefrontQueryParams {
  shopSlug: string;
  search?: string | null;
  category?: string | null;
  brand?: string | null;
  pageSize?: number;
}

export function useShopStorefrontInfiniteQuery(params: Ref<StorefrontQueryParams>) {
  const authStore = useAuthStore();
  const queryClient = useQueryClient();
  const tenantId = computed(() => authStore.tenantId ?? 0);
  const query = useInfiniteQuery({
    queryKey: computed(() =>
      shopOrderQueryKeys.storefrontCatalog(tenantId.value, params.value.shopSlug, {
        search: params.value.search ?? null,
        category: params.value.category ?? null,
        brand: params.value.brand ?? null,
        limit: params.value.pageSize ?? 24,
      }),
    ),
    queryFn: async ({ pageParam = 0 }) => {
      const limit = params.value.pageSize ?? 24;

      const result = await shopOrderService.browseShopCatalog(tenantId.value, params.value.shopSlug, {
        search: params.value.search || null,
        category: params.value.category || null,
        brand: params.value.brand || null,
        limit,
        offset: pageParam as number,
      });

      if (!result.success) {
        throw new Error(result.error || 'Failed to fetch storefront catalog');
      }

      const meta = result.data?.meta ?? {};
      const data = result.data?.data ?? [];
      const shopDetails = meta.shop ?? null;

      if (shopDetails?.id && meta.permissions) {
        seedCustomerShopPermissions(queryClient, shopDetails.id, meta.permissions);
      }

      return {
        items: data as ShopCatalogItem[],
        shopDetails,
        permissions: (meta.permissions ?? null) as CustomerShopPermissions | null,
        total: meta.total ?? 0,
        pageSize: meta.page_size ?? limit,
        nextOffset: (pageParam as number) + data.length,
      };
    },
    getNextPageParam: (lastPage) => {
      if (lastPage.nextOffset < lastPage.total && lastPage.items.length > 0) {
        return lastPage.nextOffset;
      }
      return undefined;
    },
    initialPageParam: 0,
    staleTime: 2 * 60 * 1000,
    placeholderData: keepPreviousData,
    enabled: computed(() => tenantId.value > 0 && Boolean(params.value.shopSlug)),
  });

  const shopDetails = computed<Shop | null>(() => {
    const dataVal = query.data?.value;
    const pages = dataVal?.pages;
    return pages && pages.length > 0 ? pages[0]?.shopDetails ?? null : null;
  });

  const totalItems = computed(() => {
    const dataVal = query.data?.value;
    const pages = dataVal?.pages;
    return pages && pages.length > 0 ? pages[0]?.total ?? 0 : 0;
  });

  const catalogItems = computed(() => {
    const dataVal = query.data.value;
    const pages = dataVal?.pages;
    if (!pages) return [];




    const seen = new Set<string>();
    const items: ShopCatalogItem[] = [];

    for (const page of pages) {
      for (const item of page.items) {
        const key = `${item.product_id}-${item.global_stock_id || ''}`;
        if (!seen.has(key)) {
          seen.add(key);
          items.push(item);
        }
      }
    }
    return items;
  });

  const catalogPermissions = computed<CustomerShopPermissions | null>(() => {
    const pages = query.data.value?.pages;
    return pages?.[0]?.permissions ?? null;
  });

  return {
    ...query,
    shopDetails,
    totalItems,
    catalogItems,
    catalogPermissions,
  };
}
