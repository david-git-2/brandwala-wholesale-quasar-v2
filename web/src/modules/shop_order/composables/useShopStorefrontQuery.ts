import { useInfiniteQuery, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopOrderService } from '../services/shopOrderService';
import { supabase } from 'src/boot/supabase';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { ShopCatalogItem } from '../types';

export interface StorefrontQueryParams {
  shopSlug: string;
  search?: string | null;
  category?: string | null;
  brand?: string | null;
  pageSize?: number;
}

export function useShopStorefrontInfiniteQuery(params: Ref<StorefrontQueryParams>) {
  const authStore = useAuthStore();
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
      let permissions = meta.permissions ?? null;
      const shopDetails = meta.shop ?? null;

      // Reuse permissions from previous page if already loaded and missing in meta
      const pages = query.data?.value?.pages;
      if (!permissions && pageParam > 0 && pages && pages.length > 0) {
        permissions = pages[0]?.permissions ?? null;
      }

      if (!permissions && shopDetails?.id) {
        const { data: permData } = await supabase.rpc('get_shop_permissions_for_customer', {
          p_shop_id: shopDetails.id,
        });
        if (permData && permData.length > 0) {
          permissions = permData[0];
        }
      }

      return {
        items: data,
        shopDetails,
        permissions,
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

  const shopDetails = computed(() => {
    const dataVal = query.data?.value;
    const pages = dataVal?.pages;
    return pages && pages.length > 0 ? pages[0]?.shopDetails ?? null : null;
  });

  const permissions = computed(() => {
    const dataVal = query.data?.value;
    const pages = dataVal?.pages;
    return pages && pages.length > 0 ? pages[0]?.permissions ?? null : null;
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

  return {
    ...query,
    shopDetails,
    permissions,
    totalItems,
    catalogItems,
  };
}
