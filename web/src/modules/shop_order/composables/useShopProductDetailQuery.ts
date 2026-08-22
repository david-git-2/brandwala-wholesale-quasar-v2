import { useQuery, useQueryClient } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopOrderService } from '../services/shopOrderService';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { Shop, ShopCatalogProductDetail } from '../types';
import { seedCustomerShopPermissions } from './useCustomerShopPermissionsQuery';

export function useShopProductDetailQuery(
  shopSlug: Ref<string>,
  productId: Ref<number | null>,
) {
  const authStore = useAuthStore();
  const queryClient = useQueryClient();
  const tenantId = computed(() => authStore.tenantId ?? 0);

  const query = useQuery({
    queryKey: computed(() =>
      shopOrderQueryKeys.storefrontProduct(
        tenantId.value,
        shopSlug.value,
        productId.value ?? 0,
      ),
    ),
    queryFn: async () => {
      const id = productId.value;
      if (!id) throw new Error('Product not found.');

      const result = await shopOrderService.getShopCatalogProduct(
        tenantId.value,
        shopSlug.value,
        id,
      );

      if (!result.success || !result.data) {
        throw new Error(result.error || 'Failed to fetch product.');
      }

      const shopDetails = (result.data.meta?.shop ?? null) as Shop | null;
      if (shopDetails?.id && result.data.meta?.permissions) {
        seedCustomerShopPermissions(queryClient, shopDetails.id, result.data.meta.permissions);
      }

      return {
        product: result.data.data as ShopCatalogProductDetail,
        shopDetails,
        permissions: result.data.meta?.permissions ?? null,
      };
    },
    enabled: computed(
      () => tenantId.value > 0 && Boolean(shopSlug.value) && (productId.value ?? 0) > 0,
    ),
    staleTime: 2 * 60 * 1000,
  });

  const product = computed(() => query.data.value?.product ?? null);
  const shopDetails = computed(() => query.data.value?.shopDetails ?? null);
  const permissions = computed(() => query.data.value?.permissions ?? null);

  return {
    ...query,
    product,
    shopDetails,
    permissions,
  };
}
