import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopOrderRepository } from '../repositories/shopOrderRepository';
import { supabase } from 'src/boot/supabase';

export function useCustomerOrdersQuery(shopId: Ref<number>) {
  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.customerOrders(shopId.value)),
    queryFn: () => shopOrderRepository.listShopOrdersForCustomer(shopId.value),
    enabled: computed(() => shopId.value > 0),
    staleTime: 60 * 1000,
  });
}

export function useCustomerDashboardOrdersQuery(shops: Ref<Array<{ id: number; name: string; slug: string }>>) {
  const shopIds = computed(() => shops.value.map((s) => s.id));
  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.customerDashboardOrders(shopIds.value)),
    queryFn: async () => {
      if (shops.value.length === 0) return [];
      const ordersPromises = shops.value.map((shop) =>
        shopOrderRepository.listShopOrdersForCustomer(shop.id, { limit: 5 }),
      );
      const ordersResults = await Promise.all(ordersPromises);

      const allOrders: any[] = [];
      ordersResults.forEach((orders, index) => {
        const shop = shops.value[index];
        (orders || []).forEach((order) => {
          allOrders.push({
            ...order,
            shop_name: shop?.name || 'Shop',
            shop_slug: shop?.slug || '',
          });
        });
      });

      allOrders.sort(
        (a, b) =>
          (new Date(b.created_at || 0).getTime() - new Date(a.created_at || 0).getTime()) ||
          ((Number(b.id) || 0) - (Number(a.id) || 0)),
      );

      return allOrders.slice(0, 3);
    },
    enabled: computed(() => shops.value.length > 0),
    staleTime: 60 * 1000,
  });
}

export function useShopCurrenciesMapQuery(shopIds: Ref<number[]>) {
  return useQuery({
    queryKey: computed(() => shopOrderQueryKeys.shopCurrenciesMap(shopIds.value)),
    queryFn: async (): Promise<Record<number, number>> => {
      if (!shopIds.value || shopIds.value.length === 0) return {};
      const { data: shopsData, error } = await supabase
        .from('shops')
        .select('id, sell_currency_id')
        .in('id', shopIds.value);
      if (error) throw error;
      const map: Record<number, number> = {};
      (shopsData || []).forEach((s: { id: number; sell_currency_id: number | null }) => {
        if (s.sell_currency_id) map[s.id] = s.sell_currency_id;
      });
      return map;
    },
    enabled: computed(() => shopIds.value.length > 0),
    staleTime: 5 * 60 * 1000,
  });
}
