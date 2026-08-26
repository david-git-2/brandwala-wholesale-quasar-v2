import { useQuery } from '@tanstack/vue-query';
import { computed, ref, watch, type Ref } from 'vue';
import { productRepository } from 'src/modules/products/repositories/productRepository';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';

export function useShopStorefrontCatalogSearchQuery(
  tenantId: Ref<number | null | undefined>,
  search: Ref<string>,
  enabled: Ref<boolean>,
) {
  const debouncedSearch = ref('');

  let debounceTimer: ReturnType<typeof setTimeout> | undefined;

  watch(
    search,
    (value) => {
      if (debounceTimer) {
        clearTimeout(debounceTimer);
      }
      const trimmed = value.trim();
      if (!trimmed) {
        debouncedSearch.value = '';
        return;
      }
      debounceTimer = setTimeout(() => {
        debouncedSearch.value = trimmed;
      }, 300);
    },
    { immediate: true },
  );

  return useQuery({
    queryKey: computed(() =>
      shopOrderQueryKeys.storefrontCatalogSearch(
        tenantId.value ?? 0,
        debouncedSearch.value,
      ),
    ),
    queryFn: () =>
      productRepository.listProducts({
        tenantId: tenantId.value!,
        search: debouncedSearch.value,
        searchField: 'name',
        page: 1,
        pageSize: 20,
      }),
    enabled: computed(
      () =>
        enabled.value &&
        !!tenantId.value &&
        tenantId.value > 0 &&
        debouncedSearch.value.length > 0,
    ),
    staleTime: 30 * 1000,
  });
}
