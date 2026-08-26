import { computed, ref, watch, type Ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useQueryClient } from '@tanstack/vue-query';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import type { ActiveCartItem, ShopCartItem } from '../repositories/shopCartRepository';
import { useShopCartMutations } from './useShopCartMutations';
import { useShopCartSelection } from './useShopCartSelection';
import { useShopOrderStore } from '../stores/shopOrderStore';
import { fetchCourierChargeEstimate } from '../services/courierChargeEstimate';
import { shopOrderQueryKeys } from '../shared/queryKeys/shopOrderQueryKeys';
import {
  getCartDisplayUnitAmount,
  getCartItemBuyAmount,
  getCartItemMinSellAmount,
  getCartItemSellAmount,
  getCartLineBuyerSubtotalAmount,
  getCartLineSubtotalAmount,
  pickCartItemPriceForDisplay,
  resolveCartCurrencySymbol,
  formatCartPriceAmount,
} from '../utils/cartPriceUtils';
import { adjustQtyByMoq, resolveShopCartItemMoq } from '../utils/cartQuantityUtils';

export function useShopCartPageLogic(
  activeCarts: Ref<ActiveCartItem[]>,
  isCartsLoading: Ref<boolean>,
  cart: Ref<any>,
  items: Ref<ShopCartItem[]>,
  itemCount: Ref<number>,
  cartTotal: Ref<number>,
  buyerCartTotal: Ref<number>,
) {
  const route = useRoute();
  const router = useRouter();
  const queryClient = useQueryClient();
  const authStore = useAuthStore();
  const orderStore = useShopOrderStore();

  const {
    selectedShopId,
    showCartPicker,
    currentShopCartInfo,
    selectShopCart,
    formatActiveCartTotal,
    goBack,
  } = useShopCartSelection(activeCarts, isCartsLoading);

  const tenantSlugParam = () =>
    route.params.tenantSlug ? String(route.params.tenantSlug) : null;

  const currencySymbol = computed(() =>
    resolveCartCurrencySymbol(items.value, currentShopCartInfo.value),
  );

  const goToCheckout = () => {
    void router.push({
      path: `${shopScopeBaseFromRoute()}/checkout`,
      query: { shopId: selectedShopId.value },
    });
  };

  const shopScopeBaseFromRoute = () => {
    const slug = tenantSlugParam();
    return slug ? `/${slug}/shop` : '/shop';
  };

  const { updateQtyMutation, removeItemMutation, updatePriceMutation } = useShopCartMutations();

  const isSaving = computed(
    () =>
      updateQtyMutation.isPending.value ||
      removeItemMutation.isPending.value ||
      updatePriceMutation.isPending.value,
  );

  const placingOrder = ref(false);

  const editedQuantities = ref<Record<number, number>>({});
  const editedPrices = ref<Record<number, number>>({});

  const getItemQty = (item: any) => {
    return editedQuantities.value[item.id] !== undefined
      ? editedQuantities.value[item.id]
      : item.quantity;
  };

  const getItemPrice = (item: ShopCartItem) => {
    if (editedPrices.value[item.id] !== undefined) {
      return editedPrices.value[item.id];
    }
    return getCartItemSellAmount(item);
  };

  const adjustItemQtyLocal = (item: any, delta: number) => {
    const moq = resolveShopCartItemMoq(item, { dropship: cart.value?.shop_type === 'dropship' });
    const newVal = adjustQtyByMoq(getItemQty(item), delta, moq);

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

    if (numVal === getCartItemSellAmount(item)) {
      delete editedPrices.value[item.id];
    } else {
      editedPrices.value[item.id] = numVal;
    }
  };

  const saveItemPrice = async (item: ShopCartItem) => {
    const targetPrice = editedPrices.value[item.id];
    if (targetPrice === undefined || isNaN(targetPrice) || targetPrice < 0 || !selectedShopId.value) return;
    const minSell = getCartItemMinSellAmount(item);
    if (minSell > 0 && targetPrice < minSell) return;
    await updatePriceMutation.mutateAsync({
      cartItemId: item.id,
      price: targetPrice,
      shopId: selectedShopId.value,
    });
    delete editedPrices.value[item.id];
  };

  const isItemPriceBelowFloor = (item: ShopCartItem) => {
    if (cart.value?.shop_type !== 'dropship') return false;
    const minSell = getCartItemMinSellAmount(item);
    if (minSell <= 0) return false;
    return Number(getItemPrice(item)) < minSell;
  };

  const hasUnsavedEdits = computed(
    () =>
      Object.keys(editedQuantities.value).length > 0 ||
      Object.keys(editedPrices.value).length > 0,
  );

  const hasFloorViolation = computed(() => items.value.some((item) => isItemPriceBelowFloor(item)));

  const checkoutDisabled = computed(
    () =>
      itemCount.value === 0 ||
      isSaving.value ||
      placingOrder.value ||
      hasUnsavedEdits.value ||
      hasFloorViolation.value,
  );

  const checkoutDisabledReason = computed(() => {
    if (hasUnsavedEdits.value) return 'shop.cart_save_edits_first';
    if (hasFloorViolation.value) return 'shop.cart_price_below_floor';
    if (itemCount.value === 0) return 'shop.cart_empty';
    return '';
  });

  const placesOrderFromCart = computed(
    () =>
      cart.value?.shop_type === 'vendor_catalog' || cart.value?.shop_type === 'fixed_price',
  );

  const checkoutLabelKey = computed(() =>
    placesOrderFromCart.value ? 'shop.place_order' : 'shop.proceed_to_checkout',
  );

  const handleButtonClick = async () => {
    if (checkoutDisabled.value) return;
    if (placesOrderFromCart.value) {
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
          const slug = tenantSlugParam();
          void router.push(`${slug ? `/${slug}` : ''}/shop/orders`);
        }
      } finally {
        placingOrder.value = false;
      }
    } else {
      goToCheckout();
    }
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

  const formatUnitPrice = (item: ShopCartItem) => {
    const edited = editedPrices.value[item.id];
    const amount = getCartDisplayUnitAmount(cart.value?.shop_type, item, edited);
    const price = pickCartItemPriceForDisplay(cart.value?.shop_type, item);
    return formatCartPriceAmount(amount, price, currencySymbol.value);
  };

  const formatItemTotal = (item: ShopCartItem) => {
    const edited = editedPrices.value[item.id];
    const qty = getItemQty(item);
    const amount = getCartLineSubtotalAmount(cart.value?.shop_type, item, qty, edited);
    const price = pickCartItemPriceForDisplay(cart.value?.shop_type, item);
    return formatCartPriceAmount(amount, price, currencySymbol.value);
  };

  const formatBuyerUnitPrice = (item: ShopCartItem) => {
    const amount = getCartItemBuyAmount(item);
    return formatCartPriceAmount(amount, item.unit_price, currencySymbol.value);
  };

  const formatBuyerItemTotal = (item: ShopCartItem) => {
    const qty = getItemQty(item);
    const amount = getCartLineBuyerSubtotalAmount(cart.value?.shop_type, item, qty);
    return formatCartPriceAmount(amount, item.unit_price, currencySymbol.value);
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
    checkoutDisabled,
    checkoutDisabledReason,
    checkoutLabelKey,
    placesOrderFromCart,
    isItemPriceBelowFloor,
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
