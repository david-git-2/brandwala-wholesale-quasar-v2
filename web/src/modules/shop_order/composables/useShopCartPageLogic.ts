import { computed, ref, watch, type Ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQueryClient } from '@tanstack/vue-query';
import type { ActiveCartItem } from '../repositories/shopCartRepository';
import { useShopCartMutations } from './useShopCartMutations';
import { useShopStorefrontStore } from '../stores/shopStorefrontStore';
import { useShopOrderStore } from '../stores/shopOrderStore';
import { useThriftCurrenciesQuery } from 'src/modules/thrift/currency/composables/useThriftCurrenciesQuery';
import { fetchCourierChargeEstimate } from '../services/courierChargeEstimate';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import { useAuthStore } from 'src/modules/auth/stores/authStore';

export function useShopCartPageLogic(
  activeCarts: Ref<ActiveCartItem[]>,
  isCartsLoading: Ref<boolean>,
  cart: Ref<any>,
  items: Ref<any[]>,
  itemCount: Ref<number>,
  cartTotal: Ref<number>,
  buyerCartTotal: Ref<number>,
) {
  const route = useRoute();
  const router = useRouter();
  const queryClient = useQueryClient();
  const authStore = useAuthStore();
  const orderStore = useShopOrderStore();
  const storefrontStore = useShopStorefrontStore();

  const { data: currenciesData } = useThriftCurrenciesQuery();
  const currencies = computed(() => currenciesData.value || []);

  const selectedShopId = ref<number | null>(null);

  watch(
    [() => route.query.shopId, activeCarts, isCartsLoading],
    ([qShopId, carts, loading]) => {
      if (qShopId) {
        selectedShopId.value = Number(qShopId);
      } else if (loading) {
        selectedShopId.value = null;
      } else if (carts.length > 0) {
        selectedShopId.value = null;
      } else {
        selectedShopId.value = null;
      }
    },
    { immediate: true },
  );

  const showCartPicker = computed(() => {
    return !route.query.shopId && activeCarts.value.length > 0 && !selectedShopId.value;
  });

  const currentShopCartInfo = computed(() => {
    return activeCarts.value.find((c) => c.shop_id === selectedShopId.value) ?? null;
  });

  const selectShopCart = (sId: number) => {
    selectedShopId.value = sId;
    const tenantSlug = route.params.tenantSlug ? `/${String(route.params.tenantSlug)}` : '';
    void router.replace({
      path: `${tenantSlug}/shop/cart`,
      query: { shopId: sId },
    });
  };

  const currencySymbol = computed(() => {
    if (currentShopCartInfo.value?.currency_symbol) {
      return currentShopCartInfo.value.currency_symbol;
    }
    const shop = storefrontStore.shopDetails;
    if (shop?.sell_currency_id) {
      const curr = currencies.value.find((c) => c.id === shop.sell_currency_id);
      if (curr?.symbol) return curr.symbol;
    }
    return '৳';
  });

  const formatActiveCartTotal = (activeCart: ActiveCartItem) => {
    const currency = activeCart.currency_symbol || activeCart.currency_code || '';
    return `${currency}${Number(activeCart.cart_total).toFixed(2)}`;
  };

  const goBack = () => {
    const tenantSlug = route.params.tenantSlug ? `/${String(route.params.tenantSlug)}` : '';

    if (route.query.shopId || selectedShopId.value) {
      selectedShopId.value = null;
      void router.replace({ path: `${tenantSlug}/shop/cart`, query: {} });
      return;
    }

    const lastSlug = localStorage.getItem('last_visited_shop_slug');
    if (lastSlug) {
      void router.push(`${tenantSlug}/shop/browse/${lastSlug}`);
    } else {
      void router.push(`${tenantSlug}/shop/browse`);
    }
  };

  const goToCheckout = () => {
    const tenantSlug = route.params.tenantSlug ? `/${String(route.params.tenantSlug)}` : '';
    void router.push({
      path: `${tenantSlug}/shop/checkout`,
      query: { shopId: selectedShopId.value },
    });
  };

  const { updateQtyMutation, removeItemMutation, updatePriceMutation } = useShopCartMutations();

  const isSaving = computed(
    () =>
      updateQtyMutation.isPending.value ||
      removeItemMutation.isPending.value ||
      updatePriceMutation.isPending.value,
  );

  const placingOrder = ref(false);

  const handleButtonClick = async () => {
    if (cart.value?.shop_type === 'vendor_catalog') {
      placingOrder.value = true;
      try {
        const res = await orderStore.submitOrder(
          cart.value.id,
          '',
          '',
          '',
          null,
        );
        if (res.success) {
          if (selectedShopId.value) {
            void queryClient.invalidateQueries({
              queryKey: shopOrderQueryKeys.cart(authStore.tenantId ?? 0, selectedShopId.value),
            });
          }
          void queryClient.invalidateQueries({
            queryKey: shopOrderQueryKeys.activeCarts(authStore.tenantId ?? 0),
          });
          const tenantSlug = route.params.tenantSlug ? `/${String(route.params.tenantSlug)}` : '';
          void router.push(`${tenantSlug}/shop/orders`);
        }
      } finally {
        placingOrder.value = false;
      }
    } else {
      goToCheckout();
    }
  };

  const editedQuantities = ref<Record<number, number>>({});
  const editedPrices = ref<Record<number, number>>({});

  const getItemQty = (item: any) => {
    return editedQuantities.value[item.id] !== undefined
      ? editedQuantities.value[item.id]
      : item.quantity;
  };

  const getItemPrice = (item: any) => {
    return editedPrices.value[item.id] !== undefined
      ? editedPrices.value[item.id]
      : item.customer_sell_price_amount;
  };

  const adjustItemQtyLocal = (item: any, delta: number) => {
    const rawMin =
      cart.value?.shop_type === 'dropship'
        ? 1
        : item.minimum_quantity ?? item.minimum_order_quantity ?? item.moq ?? 1;
    const minQty = Number(rawMin) || 1;
    const stepDelta = Number(delta) || minQty;
    const currentVal = Number(getItemQty(item)) || minQty;
    let newVal = currentVal + stepDelta;
    if (newVal < minQty) newVal = minQty;

    if (newVal === item.quantity) {
      delete editedQuantities.value[item.id];
    } else {
      editedQuantities.value[item.id] = newVal;
    }
  };

  const saveItemQty = async (item: any) => {
    const targetQty = editedQuantities.value[item.id];
    if (targetQty === undefined || !selectedShopId.value) return;
    await updateQtyMutation.mutateAsync({
      cartItemId: item.id,
      quantity: targetQty,
      shopId: selectedShopId.value,
    });
    delete editedQuantities.value[item.id];
  };

  const updatePriceLocal = (item: any, val: string | number | null) => {
    if (val === '' || val === null) {
      editedPrices.value[item.id] = 0;
      return;
    }
    const numVal = Number(val);
    if (isNaN(numVal) || numVal < 0) return;

    if (numVal === item.customer_sell_price_amount) {
      delete editedPrices.value[item.id];
    } else {
      editedPrices.value[item.id] = numVal;
    }
  };

  const saveItemPrice = async (item: any) => {
    const targetPrice = editedPrices.value[item.id];
    if (targetPrice === undefined || isNaN(targetPrice) || targetPrice < 0 || !selectedShopId.value) return;
    await updatePriceMutation.mutateAsync({
      cartItemId: item.id,
      price: targetPrice,
      shopId: selectedShopId.value,
    });
    delete editedPrices.value[item.id];
  };

  const removeItem = async (item: any) => {
    if (!selectedShopId.value) return;
    delete editedQuantities.value[item.id];
    delete editedPrices.value[item.id];
    await removeItemMutation.mutateAsync({
      cartItemId: item.id,
      shopId: selectedShopId.value,
    });
  };

  const formatUnitPrice = (item: any) => {
    const price =
      item.customer_sell_price_amount ??
      item.unit_sell_price_amount ??
      item.unit_list_price_amount ??
      0;
    return `${currencySymbol.value}${Number(price).toFixed(2)}`;
  };

  const formatItemTotal = (item: any) => {
    const price =
      item.customer_sell_price_amount ??
      item.unit_sell_price_amount ??
      item.unit_list_price_amount ??
      0;
    const qty = getItemQty(item);
    const total = price * qty;
    return `${currencySymbol.value}${total.toFixed(2)}`;
  };

  const formatBuyerUnitPrice = (item: any) => {
    const price = item.unit_sell_price_amount ?? item.unit_list_price_amount ?? 0;
    return `${currencySymbol.value}${Number(price).toFixed(2)}`;
  };

  const formatBuyerItemTotal = (item: any) => {
    const price = item.unit_sell_price_amount ?? item.unit_list_price_amount ?? 0;
    const qty = getItemQty(item);
    const total = price * qty;
    return `${currencySymbol.value}${total.toFixed(2)}`;
  };

  const defaultPrintCharge = computed(() => Number(cart.value?.default_print_charge_amount || 0));
  const defaultPackingCharge = computed(() => Number(cart.value?.default_packing_charge_amount || 0));

  const printCharge = computed(() => (cart.value?.shop_type === 'dropship' ? defaultPrintCharge.value : 0));
  const packingCharge = computed(() => (cart.value?.shop_type === 'dropship' ? defaultPackingCharge.value * itemCount.value : 0));

  const deductPrintFromMargin = computed(() => !!cart.value?.deduct_print_from_margin);
  const deductPackingFromMargin = computed(() => !!cart.value?.deduct_packing_from_margin);

  const buyerTotal = computed(() => {
    return buyerCartTotal.value + printCharge.value + packingCharge.value;
  });

  const courierEstimate = ref({
    deliveryMin: 60,
    deliveryMax: 130,
    codPercentMin: 1 as number | null,
    codPercentMax: 1 as number | null,
    codFlatMin: null as number | null,
    codFlatMax: null as number | null,
  });

  const totalDeductibleCharges = computed(() => {
    return (
      printCharge.value +
      packingCharge.value +
      (courierEstimate.value?.deliveryMin || 0)
    );
  });

  const codEstimateSummary = computed(() => {
    const e = courierEstimate.value;
    const parts: string[] = [];
    if (e.codPercentMin != null && e.codPercentMax != null) {
      parts.push(
        e.codPercentMin === e.codPercentMax
          ? `~${e.codPercentMin}%`
          : `~${e.codPercentMin}–${e.codPercentMax}%`
      );
    }
    if (e.codFlatMin != null && e.codFlatMax != null) {
      parts.push(
        e.codFlatMin === e.codFlatMax
          ? formatAmount(e.codFlatMin)
          : `${formatAmount(e.codFlatMin)}–${formatAmount(e.codFlatMax)}`
      );
    }
    return parts.join(' / ') || '~1%';
  });

  const formatAmount = (val: any) => {
    const num = typeof val === 'number' ? val : (val?.value ?? 0);
    return `${currencySymbol.value}${num.toFixed(2)}`;
  };

  const formatCartTotal = () => {
    return `${currencySymbol.value}${cartTotal.value.toFixed(2)}`;
  };

  watch(
    () => cart.value?.shop_type,
    async (type) => {
      if (type === 'dropship') {
        courierEstimate.value = await fetchCourierChargeEstimate();
      }
    },
  );

  return {
    selectedShopId,
    showCartPicker,
    currentShopCartInfo,
    selectShopCart,
    currencySymbol,
    formatActiveCartTotal,
    goBack,
    isSaving,
    placingOrder,
    handleButtonClick,
    editedQuantities,
    editedPrices,
    getItemQty,
    getItemPrice,
    adjustItemQtyLocal,
    saveItemQty,
    updatePriceLocal,
    saveItemPrice,
    removeItem,
    formatUnitPrice,
    formatItemTotal,
    formatBuyerUnitPrice,
    formatBuyerItemTotal,
    defaultPackingCharge,
    printCharge,
    packingCharge,
    deductPrintFromMargin,
    deductPackingFromMargin,
    buyerTotal,
    totalDeductibleCharges,
    courierEstimate,
    codEstimateSummary,
    formatAmount,
    formatCartTotal,
  };
}
