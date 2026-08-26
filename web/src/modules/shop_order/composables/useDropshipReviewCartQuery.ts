import { useQuery, useQueryClient } from '@tanstack/vue-query';
import { computed, type Ref } from 'vue';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { dropshipCartService } from '../services/dropshipCartService';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { resolveShopCartItemMoq } from '../utils/cartQuantityUtils';
import { seedCustomerShopPermissions } from './useCustomerShopPermissionsQuery';
import { cartPriceAmount, cartPriceSymbol } from '../utils/cartPriceUtils';

export function useDropshipReviewCartQuery(shopId: Ref<number | null>) {
  const authStore = useAuthStore();
  const queryClient = useQueryClient();
  const tenantId = computed(() => authStore.tenantId ?? 0);

  const query = useQuery({
    queryKey: computed(() =>
      shopOrderQueryKeys.dropshipReviewCart(tenantId.value, shopId.value ?? 0),
    ),
    queryFn: async () => {
      if (!shopId.value) return null;
      const res = await dropshipCartService.getDropshipReviewCart(shopId.value);
      if (!res.success) {
        throw new Error(res.error || 'Failed to fetch dropship review cart');
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
  const chargeEstimates = computed(() => query.data.value?.charge_estimates ?? null);
  const reviewSummary = computed(() => query.data.value?.review_summary ?? null);

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

  const totalUnits = computed(() => reviewSummary.value?.total_units ?? totals.value?.item_count ?? 0);
  const purchaseSubtotal = computed(() => totals.value?.purchase_subtotal ?? 0);
  const resellSubtotal = computed(() => totals.value?.resell_subtotal ?? 0);
  const hasFloorViolation = computed(() => reviewSummary.value?.has_floor_violation ?? false);
  const recipientGrandTotal = computed(() => reviewSummary.value?.recipient_grand_total ?? 0);
  const canContinue = computed(() => reviewSummary.value?.can_continue ?? false);

  const getPurchaseUnitAmount = (item: (typeof items.value)[number]) =>
    cartPriceAmount(item.listing_sell_price) || cartPriceAmount(item.purchase_price);

  const getResellUnitAmount = (item: (typeof items.value)[number]) =>
    cartPriceAmount(item.resell_price);

  const getMinResellAmount = (item: (typeof items.value)[number]) =>
    cartPriceAmount(item.min_resell_price);

  return {
    ...query,
    cart,
    permissions,
    items,
    totals,
    chargeEstimates,
    reviewSummary,
    currencySymbol,
    totalUnits,
    purchaseSubtotal,
    resellSubtotal,
    hasFloorViolation,
    recipientGrandTotal,
    canContinue,
    getPurchaseUnitAmount,
    getResellUnitAmount,
    getMinResellAmount,
  };
}
