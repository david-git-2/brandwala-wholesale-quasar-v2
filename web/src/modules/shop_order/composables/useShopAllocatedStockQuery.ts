import { useQuery } from '@tanstack/vue-query';
import { computed, ref, watch, type Ref } from 'vue';
import { shopWarehouseRepository } from '../repositories/shopWarehouseRepository';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';

export function useShopAllocatedStockQuery(
  shopId: Ref<number | null | undefined>,
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
      debounceTimer = setTimeout(() => {
        debouncedSearch.value = value.trim();
      }, 300);
    },
    { immediate: true },
  );

  return useQuery({
    queryKey: computed(() =>
      shopOrderQueryKeys.shopAllocatedStock(shopId.value ?? 0, debouncedSearch.value),
    ),
    queryFn: () =>
      shopWarehouseRepository.listAllocatedStockForShop(shopId.value!, {
        search: debouncedSearch.value || null,
      }),
    enabled: computed(
      () => enabled.value && !!shopId.value && shopId.value > 0,
    ),
    staleTime: 30 * 1000,
  });
}
