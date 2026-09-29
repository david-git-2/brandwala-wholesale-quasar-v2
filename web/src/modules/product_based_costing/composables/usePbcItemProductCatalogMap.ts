import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { productBasedCostingRepository } from '../repositories/productBasedCostingRepository';
import { productBasedCostingQueryKeys } from '../shared/queryKeys/productBasedCostingQueryKeys';
import type { ProductBasedCostingItem } from '../types';

export function usePbcItemProductCatalogMap(
  fileId: Ref<number>,
  costingItems: Ref<ProductBasedCostingItem[]>,
) {
  const productIds = computed(() => {
    const ids = new Set<number>();
    for (const item of costingItems.value) {
      const id = item.product_id;
      if (id != null && Number.isFinite(id) && id > 0) {
        ids.add(id);
      }
    }
    return [...ids].sort((a, b) => a - b);
  });

  const query = useQuery({
    queryKey: computed(() =>
      productBasedCostingQueryKeys.itemProductCatalog(fileId.value, productIds.value),
    ),
    queryFn: () => productBasedCostingRepository.listProductCatalogByIds(productIds.value),
    staleTime: 2 * 60 * 1000,
    enabled: computed(() => fileId.value > 0 && productIds.value.length > 0),
  });

  const catalogByProductId = computed(() => query.data.value ?? new Map());

  return {
    catalogByProductId,
    isCatalogLoading: query.isLoading,
  };
}
