import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopCartService } from '../services/shopCartService';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { supabase } from 'src/boot/supabase';

export function useShopCartQuery(shopId: Ref<number | null>) {
  const authStore = useAuthStore();
  const tenantId = computed(() => authStore.tenantId ?? 0);

  const query = useQuery({
    queryKey: computed(() => shopOrderQueryKeys.cart(tenantId.value, shopId.value ?? 0)),
    queryFn: async () => {
      if (!shopId.value) return null;
      const res = await shopCartService.getOrCreateCart(shopId.value);
      if (!res.success) {
        throw new Error(res.error || 'Failed to fetch cart');
      }

      let permissions = null;
      try {
        const { data: permData } = await supabase.rpc('get_shop_permissions_for_customer', {
          p_shop_id: shopId.value,
        });
        if (permData && permData.length > 0) {
          permissions = permData[0];
        }
      } catch {
        // Fallback if RPC fails
      }

      const rawItems = res.data?.items ?? [];
      const productIds = Array.from(new Set(rawItems.map((i) => i.product_id).filter(Boolean)));
      const moqMap: Record<number, number> = {};

      if (productIds.length > 0) {
        try {
          const { data: prodData } = await supabase
            .from('products')
            .select('id, minimum_order_quantity')
            .in('id', productIds);
          if (prodData) {
            prodData.forEach((p) => {
              if (p.minimum_order_quantity && p.minimum_order_quantity > 1) {
                moqMap[p.id] = p.minimum_order_quantity;
              }
            });
          }
        } catch {
          // Fallback if fetch fails
        }
      }

      const enrichedItems = rawItems.map((i) => {
        const moq = moqMap[i.product_id] || i.minimum_quantity || 1;
        return {
          ...i,
          minimum_quantity: moq,
          minimum_order_quantity: moq,
        };
      });

      return {
        ...res.data,
        items: enrichedItems,
        permissions,
      };
    },
    staleTime: 15 * 1000,
    enabled: computed(() => !!tenantId.value && !!shopId.value),
  });

  const cart = computed(() => query.data.value?.cart ?? null);
  const items = computed(() => (query.data.value?.items ?? []).slice().sort((a, b) => a.id - b.id));
  const permissions = computed(() => query.data.value?.permissions ?? null);

  const itemCount = computed(() => items.value.reduce((sum, item) => sum + item.quantity, 0));

  const cartTotal = computed(() => {
    return items.value.reduce((sum, item) => {
      const price =
        item.customer_sell_price_amount ??
        item.unit_sell_price_amount ??
        item.unit_list_price_amount ??
        0;
      return sum + price * item.quantity;
    }, 0);
  });

  const buyerCartTotal = computed(() => {
    return items.value.reduce((sum, item) => {
      const price = item.unit_sell_price_amount ?? item.unit_list_price_amount ?? 0;
      return sum + price * item.quantity;
    }, 0);
  });

  const chargeTotal = computed(() => {
    if (!cart.value) return 0;
    const cod = Number(cart.value.cod_charge_amount || 0);
    const delivery = Number(cart.value.delivery_charge_amount || 0);
    const print = Number(cart.value.print_charge_amount || 0);
    const packing = Number(cart.value.packing_charge_amount || 0);
    return cod + delivery + print + packing;
  });

  const recipientGrandTotal = computed(() => {
    const subtotal = cartTotal.value;
    if (!cart.value) return subtotal;
    const cod = Number(cart.value.cod_charge_amount || 0);
    const delivery = Number(cart.value.delivery_charge_amount || 0);
    const print = Number(cart.value.print_charge_amount || 0);
    const packing = Number(cart.value.packing_charge_amount || 0);
    const discount = Number(cart.value.discount_amount || 0);
    return subtotal + cod + delivery + print + packing - discount;
  });

  const estimatedProfit = computed(() => {
    const subtotal = cartTotal.value;
    const buyerTotal = buyerCartTotal.value;
    if (!cart.value) return subtotal - buyerTotal;
    const cod = Number(cart.value.cod_charge_amount || 0);
    const delivery = Number(cart.value.delivery_charge_amount || 0);
    const print = Number(cart.value.print_charge_amount || 0);
    const packing = Number(cart.value.packing_charge_amount || 0);
    const discount = Number(cart.value.discount_amount || 0);
    const grandTotal = subtotal + cod + delivery + print + packing - discount;
    const buyerCost = buyerTotal + delivery + print + packing;
    return grandTotal - buyerCost;
  });

  return {
    ...query,
    cart,
    items,
    itemCount,
    cartTotal,
    buyerCartTotal,
    chargeTotal,
    recipientGrandTotal,
    estimatedProfit,
    permissions,
  };
}
