import { useQuery, useQueryClient } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { shopCartService } from '../services/shopCartService';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { resolveShopCartItemMoq } from '../utils/cartQuantityUtils';
import { seedCustomerShopPermissions } from './useCustomerShopPermissionsQuery';
import { sumCartBuyerSubtotal, sumCartSubtotal } from '../utils/cartPriceUtils';
import type { ShopType } from '../types';

export function useShopCartQuery(shopId: Ref<number | null>) {
  const authStore = useAuthStore();
  const queryClient = useQueryClient();
  const tenantId = computed(() => authStore.tenantId ?? 0);

  const query = useQuery({
    queryKey: computed(() => shopOrderQueryKeys.cart(tenantId.value, shopId.value ?? 0)),
    queryFn: async () => {
      if (!shopId.value) return null;
      const res = await shopCartService.getOrCreateCart(shopId.value);
      if (!res.success) {
        throw new Error(res.error || 'Failed to fetch cart');
      }

      if (res.data?.permissions) {
        seedCustomerShopPermissions(queryClient, shopId.value, res.data.permissions);
      }

      const enrichedItems = (res.data?.items ?? []).map((i) => {
        const moq = resolveShopCartItemMoq(i);
        return {
          ...i,
          minimum_quantity: moq,
          minimum_order_quantity: moq,
        };
      });

      return {
        ...res.data,
        items: enrichedItems,
      };
    },
    staleTime: 15 * 1000,
    enabled: computed(() => !!tenantId.value && !!shopId.value),
  });

  const cart = computed(() => query.data.value?.cart ?? null);
  const permissions = computed(() => query.data.value?.permissions ?? null);
  const items = computed(() => (query.data.value?.items ?? []).slice().sort((a, b) => a.id - b.id));
  const shopType = computed(() => cart.value?.shop_type as ShopType | undefined);

  const itemCount = computed(() => items.value.reduce((sum, item) => sum + item.quantity, 0));

  const cartTotal = computed(() => sumCartSubtotal(shopType.value, items.value));

  const buyerCartTotal = computed(() => sumCartBuyerSubtotal(shopType.value, items.value));

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
    permissions,
    items,
    itemCount,
    cartTotal,
    buyerCartTotal,
    chargeTotal,
    recipientGrandTotal,
    estimatedProfit,
  };
}
