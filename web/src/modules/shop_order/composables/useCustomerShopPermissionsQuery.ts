import { useQuery, useQueryClient } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { supabase } from 'src/boot/supabase';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';

export interface CustomerShopPermissions {
  can_browse?: boolean;
  see_price?: boolean;
  can_add_to_cart?: boolean;
  can_place_order?: boolean;
  can_negotiate?: boolean;
  can_view_quantity?: boolean;
  can_set_dropship_price?: boolean;
}

export function useCustomerShopPermissionsQuery(shopId: Ref<number | null>) {
  const queryClient = useQueryClient();
  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.customerShopPermissions(shopId.value ?? 0)),
    queryFn: async () => {
      const id = shopId.value!;
      const { data, error } = await supabase.rpc('get_shop_permissions_for_customer', { p_shop_id: id });
      if (error) throw error;
      return (data?.[0] ?? null) as CustomerShopPermissions | null;
    },
    enabled: computed(() => !!shopId.value),
    staleTime: 2 * 60 * 1000,
    initialData: () => {
      const id = shopId.value;
      if (!id) return undefined;
      return queryClient.getQueryData<CustomerShopPermissions | null>(
        shopOrderQueryKeys.customerShopPermissions(id),
      );
    },
  });
}

/** Call after browse catalog loads to seed permissions cache from meta. */
export function seedCustomerShopPermissions(
  queryClient: ReturnType<typeof useQueryClient>,
  shopId: number,
  permissions: CustomerShopPermissions | null,
) {
  if (!permissions) return;
  queryClient.setQueryData(shopOrderQueryKeys.customerShopPermissions(shopId), permissions);
}
