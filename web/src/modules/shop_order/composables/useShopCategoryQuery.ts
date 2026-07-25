import { useQuery, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopCategoryRepository } from '../repositories/shopCategoryRepository';

export interface ShopCategoryQueryParams {
  tenantId: number;
}

export function useShopCategoryListQuery(params: Ref<ShopCategoryQueryParams>) {
  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.categories(params.value.tenantId)),
    queryFn: () => shopCategoryRepository.listCategories(params.value.tenantId),
    staleTime: 5 * 60 * 1000,
    placeholderData: keepPreviousData,
    enabled: computed(() => !!params.value.tenantId),
  });
}
