import { useQuery, useQueryClient } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { productBasedCostingRepository } from '../repositories/productBasedCostingRepository';
import { productBasedCostingQueryKeys } from '../shared/queryKeys/productBasedCostingQueryKeys';
import type { PbcItemProductCatalog, ProductBasedCostingItem } from '../types';
import { readPbcProductCatalogFromDetailsBundleCache } from '../utils/pbcDetailsBundleCache';

export function usePbcItemProductCatalogMap(
  fileId: Ref<number>,
  costingItems: Ref<ProductBasedCostingItem[]>,
) {
  const queryClient = useQueryClient();

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

  const bundleCatalog = computed(() => {
    if (fileId.value <= 0) {
      return new Map<number, PbcItemProductCatalog>();
    }
    return readPbcProductCatalogFromDetailsBundleCache(queryClient, fileId.value);
  });

  const missingProductIds = computed(() =>
    productIds.value.filter((id) => !bundleCatalog.value.has(id)),
  );

  const fallbackQuery = useQuery({
    queryKey: computed(() =>
      productBasedCostingQueryKeys.itemProductCatalog(fileId.value, missingProductIds.value),
    ),
    queryFn: () => productBasedCostingRepository.listProductCatalogByIds(missingProductIds.value),
    staleTime: 2 * 60 * 1000,
    enabled: computed(() => fileId.value > 0 && missingProductIds.value.length > 0),
  });

  const catalogByProductId = computed(() => {
    const merged = new Map(bundleCatalog.value);
    const fallback = fallbackQuery.data.value;
    if (fallback) {
      for (const [id, row] of fallback) {
        merged.set(id, row);
      }
    }
    return merged;
  });

  return {
    catalogByProductId,
    isCatalogLoading: fallbackQuery.isLoading,
  };
}
