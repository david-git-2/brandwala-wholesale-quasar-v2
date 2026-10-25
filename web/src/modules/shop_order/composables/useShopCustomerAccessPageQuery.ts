import { useQuery, useQueryClient, keepPreviousData } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import {
  BOOKS_CUSTOMER_GROUPS_STALE_MS,
  seedBooksCustomerGroups,
} from '../utils/booksCustomerGroupsCache';
import { resolveBooksTenantId } from 'src/modules/tenant/utils/resolveBooksTenantId';

export function useShopCustomerAccessPageQuery(
  tenantId: Ref<number>,
  shopId: Ref<number>,
  parentTenantId: Ref<number | null | undefined>,
) {
  const queryClient = useQueryClient();
  const booksTenantId = computed(() =>
    resolveBooksTenantId(tenantId.value, parentTenantId.value),
  );

  const query = useQuery({
    queryKey: computed(() =>
      shopOrderQueryKeys.shopCustomerAccessPage(tenantId.value, shopId.value),
    ),
    queryFn: async () => {
      const bundle = await shopOrderRepository.getShopCustomerAccessPage(
        shopId.value,
        tenantId.value,
      );
      seedBooksCustomerGroups(queryClient, booksTenantId.value, bundle.customer_groups);
      return bundle;
    },
    staleTime: BOOKS_CUSTOMER_GROUPS_STALE_MS,
    placeholderData: keepPreviousData,
    refetchOnWindowFocus: false,
    enabled: computed(() => tenantId.value > 0 && shopId.value > 0),
  });

  const refresh = async () => {
    await queryClient.resetQueries({
      queryKey: shopOrderQueryKeys.shopCustomerAccessPage(tenantId.value, shopId.value),
      exact: true,
    });
  };

  const isRefreshing = computed(
    () => query.isFetching.value && !query.isLoading.value && !!query.data.value,
  );

  return {
    ...query,
    booksTenantId,
    refresh,
    isRefreshing,
  };
}
