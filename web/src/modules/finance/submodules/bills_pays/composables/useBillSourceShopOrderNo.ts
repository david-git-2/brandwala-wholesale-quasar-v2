import { computed, type MaybeRefOrGetter, toValue } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import { supabase } from 'src/boot/supabase';

export function useBillSourceShopOrderNo(
  shopOrderId: MaybeRefOrGetter<number | null | undefined>,
  enabled: MaybeRefOrGetter<boolean> = true,
) {
  const resolvedId = computed(() => {
    const raw = toValue(shopOrderId);
    return raw != null && Number.isFinite(Number(raw)) && Number(raw) > 0 ? Number(raw) : null;
  });

  const isEnabled = computed(() => toValue(enabled) && resolvedId.value != null);

  const query = useQuery({
    queryKey: computed(() => ['bill-source-shop-order-no', resolvedId.value] as const),
    queryFn: async () => {
      const id = resolvedId.value!;
      const { data, error } = await supabase
        .from('shop_orders')
        .select('order_no')
        .eq('id', id)
        .maybeSingle();
      if (error) throw error;
      const no = (data?.order_no ?? '').trim();
      return no || null;
    },
    enabled: isEnabled,
    staleTime: 5 * 60 * 1000,
  });

  const shopOrderNo = computed(() => query.data.value ?? null);

  return { shopOrderNo, isLoading: query.isPending };
}