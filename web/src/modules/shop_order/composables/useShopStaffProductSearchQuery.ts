import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { productRepository } from 'src/modules/products/repositories/productRepository';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { shopStorefrontAdminRepository } from '../repositories/shopStorefrontAdminRepository';
import { shopWarehouseRepository } from '../repositories/shopWarehouseRepository';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';

const MIN_SEARCH_LENGTH = 2;

export type ShopStaffProductSearchScope = 'shop_listings' | 'tenant_products' | 'warehouse_stock';

export interface ShopStaffProductSearchHit {
  product_id: number;
  product_name: string;
  available_atp?: number;
  product_code?: string | null;
  image_url?: string | null;
  unit_cost_amount?: number;
}

export function useShopStaffProductSearchQuery(
  submittedSearch: Ref<string>,
  options: {
    shopId: Ref<number | null | undefined>;
    scope: Ref<ShopStaffProductSearchScope>;
  },
  limit = 20,
) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId ?? 0);
  const trimmedSearch = computed(() => submittedSearch.value.trim());

  const query = useQuery({
    queryKey: computed(() =>
      shopOrderQueryKeys.staffProductSearch({
        tenantId: tenantId.value,
        shopId: options.shopId.value ?? 0,
        scope: options.scope.value,
        search: trimmedSearch.value,
        limit,
      }),
    ),
    queryFn: async (): Promise<ShopStaffProductSearchHit[]> => {
      if (options.scope.value === 'tenant_products') {
        const page = await productRepository.listProducts({
          tenantId: tenantId.value,
          search: trimmedSearch.value,
          pageSize: limit,
        });
        return (page.data ?? []).map((p) => ({
          product_id: p.id,
          product_name: p.name,
        }));
      }

      if (options.scope.value === 'warehouse_stock') {
        const result = await shopWarehouseRepository.listAllocatedStockForShop(
          options.shopId.value!,
          { search: trimmedSearch.value, limit },
        );
        const byProduct = new Map<number, ShopStaffProductSearchHit>();
        for (const row of result.data ?? []) {
          const prev = byProduct.get(row.product_id);
          if (prev && (prev.available_atp ?? 0) >= row.available_atp) continue;
          byProduct.set(row.product_id, {
            product_id: row.product_id,
            product_name: row.item_name,
            available_atp: row.available_atp,
            product_code: row.product_code,
            image_url: row.image_url,
            unit_cost_amount: row.unit_cost_amount,
          });
        }
        return [...byProduct.values()];
      }

      const result = await shopStorefrontAdminRepository.listStorefrontAdminListings(
        options.shopId.value!,
        { search: trimmedSearch.value, limit, offset: 0 },
      );
      return (result.data ?? []).map((row) => ({
        product_id: row.product_id,
        product_name: row.product_name,
      }));
    },
    enabled: computed(() => {
      if (tenantId.value <= 0 || trimmedSearch.value.length < MIN_SEARCH_LENGTH) {
        return false;
      }
      if (options.scope.value === 'shop_listings' || options.scope.value === 'warehouse_stock') {
        return (options.shopId.value ?? 0) > 0;
      }
      return true;
    }),
    staleTime: 30 * 1000,
  });

  const results = computed(() => query.data.value ?? []);

  return {
    ...query,
    results,
    minSearchLength: MIN_SEARCH_LENGTH,
  };
}
