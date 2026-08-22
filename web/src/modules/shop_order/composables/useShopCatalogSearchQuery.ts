import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopOrderService } from '../services/shopOrderService';
import { useAuthStore } from 'src/modules/auth/stores/authStore';

const MIN_SEARCH_LENGTH = 2;

export function useShopCatalogSearchQuery(submittedSearch: Ref<string>, limit = 15) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId ?? 0);
  const trimmedSearch = computed(() => submittedSearch.value.trim());

  const query = useQuery({
    queryKey: computed(() =>
      shopOrderQueryKeys.catalogSearch(tenantId.value, trimmedSearch.value, limit),
    ),
    queryFn: async () => {
      const result = await shopOrderService.searchShopCatalog(
        tenantId.value,
        trimmedSearch.value,
        { limit },
      );
      if (!result.success) {
        throw new Error(result.error || 'Failed to search products');
      }
      return result.data ?? { data: [], meta: { total: 0, page: 1, page_size: limit, total_pages: 1 } };
    },
    enabled: computed(
      () => tenantId.value > 0 && trimmedSearch.value.length >= MIN_SEARCH_LENGTH,
    ),
    staleTime: 30 * 1000,
  });

  const results = computed(() => query.data.value?.data ?? []);

  return {
    ...query,
    results,
    minSearchLength: MIN_SEARCH_LENGTH,
  };
}
