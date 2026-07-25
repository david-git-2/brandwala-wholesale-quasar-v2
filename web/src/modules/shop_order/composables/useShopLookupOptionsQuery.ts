import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { productService } from 'src/modules/products/services/productService';

export interface ShopLookupParams {
  vendorCode?: string | null;
  tenantId?: number | null;
  enabled?: boolean;
}

export function useShopBrandOptionsQuery(params: Ref<ShopLookupParams>) {
  const query = useQuery({
    queryKey: computed(() =>
      shopOrderQueryKeys.brandOptions({
        vendorCode: params.value.vendorCode ?? null,
        tenantId: params.value.tenantId ?? null,
      }),
    ),
    queryFn: async () => {
      const res = await productService.listBrands({
        vendorCode: params.value.vendorCode ?? null,
        tenantId: params.value.tenantId ?? null,
      });
      if (!res.success) {
        throw new Error(res.error || 'Failed to load brand options');
      }
      return res.data ?? [];
    },
    enabled: computed(() => params.value.enabled ?? true),
    staleTime: 5 * 60 * 1000,
  });

  return {
    ...query,
    brands: computed(() => query.data.value ?? []),
  };
}

export function useShopCategoryOptionsQuery(params: Ref<ShopLookupParams>) {
  const query = useQuery({
    queryKey: computed(() =>
      shopOrderQueryKeys.categoryOptions({
        vendorCode: params.value.vendorCode ?? null,
        tenantId: params.value.tenantId ?? null,
      }),
    ),
    queryFn: async () => {
      const res = await productService.listCategories({
        vendorCode: params.value.vendorCode ?? null,
        tenantId: params.value.tenantId ?? null,
      });
      if (!res.success) {
        throw new Error(res.error || 'Failed to load category options');
      }
      return res.data ?? [];
    },
    enabled: computed(() => params.value.enabled ?? true),
    staleTime: 5 * 60 * 1000,
  });

  return {
    ...query,
    categories: computed(() => query.data.value ?? []),
  };
}

