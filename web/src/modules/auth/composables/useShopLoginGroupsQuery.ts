import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import type { ShopType } from 'src/modules/shop_order/types';
import {
  listShopLoginGroups,
  type ShopLoginGroupRow,
} from '../utils/shopCustomerGroupSession';

export const shopLoginGroupsQueryKey = (
  tenantId: number,
  email: string,
  shopType: ShopType | null,
) => ['auth', 'shopLoginGroups', { tenantId, email, shopType }] as const;

export function useShopLoginGroupsQuery(
  tenantId: Ref<number | null>,
  email: Ref<string | null | undefined>,
  shopType: Ref<ShopType | null>,
) {
  return useQuery({
    queryKey: computed(() => {
      const id = tenantId.value;
      const em = email.value?.trim().toLowerCase() ?? '';
      return shopLoginGroupsQueryKey(id ?? 0, em, shopType.value);
    }),
    queryFn: async (): Promise<ShopLoginGroupRow[]> => {
      const id = tenantId.value;
      const em = email.value?.trim();
      const type = shopType.value;
      if (id == null || !em || !type) {
        return [];
      }
      return listShopLoginGroups(em, id, type);
    },
    staleTime: 5 * 60 * 1000,
    enabled: computed(
      () => tenantId.value != null && Boolean(email.value?.trim()) && shopType.value != null,
    ),
  });
}
