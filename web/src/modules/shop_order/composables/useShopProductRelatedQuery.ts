import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopOrderService } from '../services/shopOrderService';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { ShopCatalogItem } from '../types';

export function useShopProductRelatedQuery(
  shopSlug: Ref<string>,
  productId: Ref<number | null>,
  limit = 4,
) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId ?? 0);

  const query = useQuery({
    queryKey: computed(() =>
      shopOrderQueryKeys.storefrontProductRelated(
        tenantId.value,
        shopSlug.value,
        productId.value ?? 0,
      ),
    ),
    queryFn: async () => {
      const id = productId.value;
      if (!id) throw new Error('Product not found.');

      const result = await shopOrderService.listRelatedShopCatalogProducts(
        tenantId.value,
        shopSlug.value,
        id,
        limit,
      );

      if (!result.success || !result.data) {
        throw new Error(result.error || 'Failed to fetch related products.');
      }

      return result.data;
    },
    enabled: computed(
      () => tenantId.value > 0 && Boolean(shopSlug.value) && (productId.value ?? 0) > 0,
    ),
    staleTime: 2 * 60 * 1000,
  });

  const relatedProducts = computed<ShopCatalogItem[]>(() => query.data.value?.data ?? []);
  const relatedCategory = computed(() => query.data.value?.meta?.category ?? null);

  return {
    ...query,
    relatedProducts,
    relatedCategory,
  };
}
