import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import {
  listShopLoginGroups,
  type ShopLoginGroupRow,
} from '../utils/shopCustomerGroupSession';

export const shopLoginGroupsQueryKey = (tenantId: number, email: string) =>
  ['auth', 'shopLoginGroups', { tenantId, email }] as const;

export function useShopLoginGroupsQuery(
  tenantId: Ref<number | null>,
  email: Ref<string | null | undefined>,
) {
  return useQuery({
    queryKey: computed(() => {
      const id = tenantId.value;
      const em = email.value?.trim().toLowerCase() ?? '';
      return shopLoginGroupsQueryKey(id ?? 0, em);
    }),
    queryFn: async (): Promise<ShopLoginGroupRow[]> => {
      const id = tenantId.value;
      const em = email.value?.trim();
      if (id == null || !em) {
        return [];
      }
      return listShopLoginGroups(em, id);
    },
    staleTime: 5 * 60 * 1000,
    enabled: computed(() => tenantId.value != null && Boolean(email.value?.trim())),
  });
}
