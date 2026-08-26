import { useQuery } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { dropshipCartService } from '../services/dropshipCartService';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { resolveShopCartItemMoq } from '../utils/cartQuantityUtils';
import { seedCustomerShopPermissions } from './useCustomerShopPermissionsQuery';
import { useQueryClient } from '@tanstack/vue-query';
import { cartPriceAmount, cartPriceSymbol } from '../utils/cartPriceUtils';

export function useDropshipShopCartQuery(shopId: Ref<number | null>) {
  const authStore = useAuthStore();
  const queryClient = useQueryClient();
  const tenantId = computed(() => authStore.tenantId ?? 0);

  const query = useQuery({
    queryKey: computed(() => shopOrderQueryKeys.dropshipCart(tenantId.value, shopId.value ?? 0)),
    queryFn: async () => {
      if (!shopId.value) return null;
      const res = await dropshipCartService.getDropshipShopCart(shopId.value);
      if (!res.success) {
        throw new Error(res.error || 'Failed to fetch dropship cart');
      }

      if (res.data?.permissions) {
        seedCustomerShopPermissions(queryClient, shopId.value, res.data.permissions);
      }

      const enrichedItems = (res.data?.items ?? []).map((item) => {
        const moq = resolveShopCartItemMoq(item, { dropship: true });
        return {
          ...item,
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
  const totals = computed(() => query.data.value?.totals ?? null);

  const currencySymbol = computed(() => {
    const sym = cart.value?.currency?.symbol;
    if (sym) return sym;
    const code = cart.value?.currency?.code;
    if (code) return code;
    const firstItem = items.value[0];
    if (firstItem) {
      return (
        cartPriceSymbol(firstItem.listing_sell_price) ||
        cartPriceSymbol(firstItem.purchase_price) ||
        cartPriceSymbol(firstItem.resell_price) ||
        '৳'
      );
    }
    return '৳';
  });

  const itemCount = computed(() => totals.value?.item_count ?? 0);
  const purchaseSubtotal = computed(() => totals.value?.purchase_subtotal ?? 0);
  const resellSubtotal = computed(() => totals.value?.resell_subtotal ?? 0);

  const getPurchaseUnitAmount = (item: (typeof items.value)[number]) =>
    cartPriceAmount(item.listing_sell_price) || cartPriceAmount(item.purchase_price);

  const getLinePurchaseTotal = (item: (typeof items.value)[number]) =>
    Number(item.line_totals?.purchase_subtotal ?? getPurchaseUnitAmount(item) * item.quantity);

  return {
    ...query,
    cart,
    permissions,
    items,
    totals,
    currencySymbol,
    itemCount,
    purchaseSubtotal,
    resellSubtotal,
    getPurchaseUnitAmount,
    getLinePurchaseTotal,
  };
}
