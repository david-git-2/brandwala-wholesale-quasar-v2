import { useQuery, useQueryClient } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopLoginGroupsQueryKey } from 'src/modules/auth/composables/useShopLoginGroupsQuery';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import {
  shopCustomerShellRepository,
  type ShopCustomerShellBundle,
} from '../repositories/shopCustomerShellRepository';

export function useShopCustomerShellQuery(
  tenantId: Ref<number | null>,
  email: Ref<string | null | undefined>,
) {
  const queryClient = useQueryClient();

  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.customerShell(tenantId.value ?? 0)),
    queryFn: async (): Promise<ShopCustomerShellBundle> => {
      const id = tenantId.value!;
      const bundle = await shopCustomerShellRepository.getBundle(id);

      queryClient.setQueryData(shopOrderQueryKeys.activeCarts(id), bundle.active_carts);
      queryClient.setQueryData(shopOrderQueryKeys.customerShops(id), bundle.customer_shops);

      const em = email.value?.trim().toLowerCase() ?? '';
      if (em) {
        queryClient.setQueryData(shopLoginGroupsQueryKey(id, em), bundle.login_groups);
      }

      return bundle;
    },
    staleTime: 60 * 1000,
    enabled: computed(() => tenantId.value != null),
  });
}
