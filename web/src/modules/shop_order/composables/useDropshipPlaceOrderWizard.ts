import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useRecipientProfileStore } from 'src/modules/people/submodules/customer/stores/recipientProfileStore';
import { showErrorNotification } from 'src/utils/appFeedback';
import { useUnsavedLeaveGuard } from 'src/composables/useUnsavedLeaveGuard';
import { useDropshipOrderFlowLeaveGuard } from './useDropshipOrderFlowLeaveGuard';
import { useDropshipShopCartQuery } from './useDropshipShopCartQuery';
import { useDropshipReviewCartQuery } from './useDropshipReviewCartQuery';
import { useShopCartMutations } from './useShopCartMutations';
import { useBDAddressOptions } from './useBDAddressOptions';
import { useSubmitDropshipOrderMutation } from './useSubmitDropshipOrderMutation';
import { resolveCartShopId, shopCustomerOrderDetailRoute } from '../utils/catalogShop';
import { useActiveShopCartsQuery } from './useActiveShopCartsQuery';
import { filterActiveCartsByKind } from '../utils/shopCartScope';
import type { DropshipReviewListItem } from '../components/ShopDropshipReviewItemsList.vue';
import {
  effectiveResellUnitPrice,
  hasPendingResellDiscount,
} from '../utils/dropshipReviewPricingUtils';
import {
  DROPSHIP_PLACE_ORDER_STEP_COUNT,
  DROPSHIP_PLACE_ORDER_STEPS,
} from '../constants/dropshipPlaceOrderSteps';
import type { DropshipCartItem } from '../repositories/dropshipCartRepository';
import {
  deliveryDetailsToForm,
  formToDeliveryDetails,
  hasStoredDeliveryDetails,
  type DropshipCartDeliveryDetails,
} from '../utils/dropshipCartDeliveryDetails';

export function useDropshipPlaceOrderWizard() {
  const route = useRoute();
  const router = useRouter();
  const { t } = useI18n();
  const $q = useQuasar();
  const authStore = useAuthStore();
  const recipientProfileStore = useRecipientProfileStore();

  const { data: activeCartsData, isLoading: isActiveCartsLoading } =
    useActiveShopCartsQuery();
  const dropshipActiveCarts = computed(() =>
    filterActiveCartsByKind(activeCartsData.value ?? [], 'dropship'),
  );

  const shopId = computed(() =>
    resolveCartShopId(
      authStore.tenantId,
      dropshipActiveCarts.value,
      route.query.shopId,
    ),
  );

  watch(shopId, (id) => {
    if (!id) return;
    const q = String(route.query.shopId ?? '');
    if (q !== String(id)) {
      syncStepQuery();
    }
  });

  const currentStep = ref(1);
  const maxReachableStep = ref(1);
  const termsAccepted = ref(false);
  const skipFlowLeaveGuard = ref(false);

  const parseInitialStep = (): number => {
    const raw = Array.isArray(route.query.step) ? route.query.step[0] : route.query.step;
    const n = Number(raw);
    if (!Number.isFinite(n) || n < 1 || n > DROPSHIP_PLACE_ORDER_STEP_COUNT) return 1;
    return Math.floor(n);
  };

  const syncStepQuery = () => {
    void router.replace({
      query: {
        ...route.query,
        shopId: shopId.value ? String(shopId.value) : route.query.shopId,
        step: String(currentStep.value),
      },
    });
  };

  watch(currentStep, () => syncStepQuery());

  const lockCartQuery = useDropshipShopCartQuery(shopId);
  const reviewCartQuery = useDropshipReviewCartQuery(shopId);
  const { updateQtyMutation, removeItemMutation, updatePriceMutation, updateDeliveryDetailsMutation } =
    useShopCartMutations();
  const submitOrderMutation = useSubmitDropshipOrderMutation();

  const isLoading = computed(() => {
    if (!shopId.value && isActiveCartsLoading.value) return true;
    if (!shopId.value) return false;
    return lockCartQuery.isLoading.value || reviewCartQuery.isLoading.value;
  });
  const isError = computed(() => lockCartQuery.isError.value || reviewCartQuery.isError.value);

  const refetchAll = async () => {
    await Promise.all([lockCartQuery.refetch(), reviewCartQuery.refetch()]);
  };

  const lockItems = computed(() => lockCartQuery.items.value);
  const reviewItems = computed(() => reviewCartQuery.items.value);
  const currencySymbol = computed(
    () => reviewCartQuery.currencySymbol.value || lockCartQuery.currencySymbol.value,
  );

  // —— Step 1: quantity ——
  const editedQuantities = ref<Record<number, number>>({});
  const removingItemId = ref<number | null>(null);
  const isUpdatingQty = computed(() => updateQtyMutation.isPending.value);
  const isCartBusy = computed(
    () => updateQtyMutation.isPending.value || removeItemMutation.isPending.value,
  );

  const getItemQty = (item: DropshipCartItem) =>
    editedQuantities.value[item.id] !== undefined
      ? editedQuantities.value[item.id]
      : item.quantity;

  const hasUnsavedQty = (item: DropshipCartItem) =>
    editedQuantities.value[item.id] !== undefined &&
    editedQuantities.value[item.id] !== item.quantity;

  const hasUnsavedQtyEdits = computed(() =>
    lockItems.value.some((item) => hasUnsavedQty(item)),
  );

  const adjustItemQtyLocal = (itemId: number, quantity: number, savedQuantity: number) => {
    if (quantity === savedQuantity) {
      delete editedQuantities.value[itemId];
      return;
    }
    editedQuantities.value[itemId] = quantity;
  };

  const saveItemQty = async (itemId: number) => {
    const targetQty = editedQuantities.value[itemId];
    if (targetQty === undefined || !shopId.value) return;
    await updateQtyMutation.mutateAsync({
      cartItemId: itemId,
      quantity: targetQty,
      shopId: shopId.value,
    });
    delete editedQuantities.value[itemId];
    await reviewCartQuery.refetch();
  };

  const removeItem = async (item: DropshipCartItem) => {
    if (!shopId.value || isCartBusy.value) return;
    delete editedQuantities.value[item.id];
    removingItemId.value = item.id;
    try {
      await removeItemMutation.mutateAsync({
        cartItemId: item.id,
        shopId: shopId.value,
      });
      await reviewCartQuery.refetch();
    } finally {
      removingItemId.value = null;
    }
  };

  const saveAllQtyEdits = async (): Promise<boolean> => {
    if (!shopId.value || !hasUnsavedQtyEdits.value) return true;
    const ids = Object.keys(editedQuantities.value).map(Number);
    for (const cartItemId of ids) {
      const quantity = editedQuantities.value[cartItemId];
      if (quantity === undefined) continue;
      await updateQtyMutation.mutateAsync({
        cartItemId,
        quantity,
        shopId: shopId.value,
      });
      delete editedQuantities.value[cartItemId];
    }
    await reviewCartQuery.refetch();
    return !hasUnsavedQtyEdits.value;
  };

  // —— Step 2: resell ——
  const editedResellPrices = ref<Record<number, number>>({});
  const savingItemId = ref<number | null>(null);
  const isUpdatingPrice = computed(() => updatePriceMutation.isPending.value);

  const getResellUnitAmount = reviewCartQuery.getResellUnitAmount;
  const getPurchaseUnitAmount = reviewCartQuery.getPurchaseUnitAmount;
  const getMinResellAmount = reviewCartQuery.getMinResellAmount;
  const getRequestedResellDiscountAmount = reviewCartQuery.getRequestedResellDiscountAmount;

  const getItemResellPrice = (itemId: number, savedPrice: number) =>
    editedResellPrices.value[itemId] !== undefined
      ? editedResellPrices.value[itemId]
      : savedPrice;

  const hasUnsavedResell = (itemId: number, savedPrice: number) =>
    editedResellPrices.value[itemId] !== undefined &&
    editedResellPrices.value[itemId] !== savedPrice;

  const hasUnsavedResellEdits = computed(() =>
    reviewItems.value.some((item) =>
      hasUnsavedResell(item.id, getResellUnitAmount(item)),
    ),
  );

  const uiReviewItems = computed<DropshipReviewListItem[]>(() =>
    reviewItems.value.map((item) => {
      const savedResell = getResellUnitAmount(item);
      const resellPrice = getItemResellPrice(item.id, savedResell);
      return {
        id: item.id,
        name: item.name,
        imageUrl: item.image_url,
        quantity: item.quantity,
        purchasePrice: getPurchaseUnitAmount(item),
        resellPrice,
        minResellPrice: getMinResellAmount(item),
        isSaving: savingItemId.value === item.id && isUpdatingPrice.value,
        requestedResellDiscountPrice: getRequestedResellDiscountAmount(item),
        resellDiscountRequestReason: item.resell_discount_request_reason ?? null,
      };
    }),
  );

  const effectiveResellUnitForItem = (item: (typeof reviewItems.value)[number]) =>
    effectiveResellUnitPrice(
      getItemResellPrice(item.id, getResellUnitAmount(item)),
      getRequestedResellDiscountAmount(item),
    );

  const columnTotals = computed(() => {
    const purchaseTotal = reviewItems.value.reduce(
      (sum, item) => sum + getPurchaseUnitAmount(item) * item.quantity,
      0,
    );
    const resellTotal = reviewItems.value.reduce(
      (sum, item) => sum + effectiveResellUnitForItem(item) * item.quantity,
      0,
    );
    return { purchaseTotal, resellTotal };
  });

  const reviewSummary = computed(() => ({
    itemsTotal: columnTotals.value.resellTotal,
    totalUnits: reviewCartQuery.totalUnits.value,
    hasFloorViolation: hasUnsavedResellEdits.value
      ? uiReviewItems.value.some((item) => item.resellPrice < item.minResellPrice)
      : reviewCartQuery.hasFloorViolation.value,
  }));

  const updateResellPriceLocal = (itemId: number, value: number) => {
    const item = reviewItems.value.find((row) => row.id === itemId);
    if (!item) return;
    const savedPrice = getResellUnitAmount(item);
    if (value === savedPrice) {
      delete editedResellPrices.value[itemId];
      return;
    }
    editedResellPrices.value[itemId] = value;
  };

  const saveResellPrice = async (itemId: number) => {
    const item = reviewItems.value.find((row) => row.id === itemId);
    if (!item) return;
    const savedPrice = getResellUnitAmount(item);
    if (!hasUnsavedResell(itemId, savedPrice)) return;
    const targetPrice = editedResellPrices.value[itemId];
    if (targetPrice === undefined || !shopId.value) return;
    savingItemId.value = itemId;
    try {
      await updatePriceMutation.mutateAsync({
        cartItemId: itemId,
        price: targetPrice,
        shopId: shopId.value,
      });
      delete editedResellPrices.value[itemId];
    } finally {
      savingItemId.value = null;
    }
  };

  const saveAllResellEdits = async (): Promise<boolean> => {
    if (reviewSummary.value.hasFloorViolation) return false;
    for (const item of reviewItems.value) {
      const savedPrice = getResellUnitAmount(item);
      if (!hasUnsavedResell(item.id, savedPrice)) continue;
      await saveResellPrice(item.id);
      if (hasUnsavedResell(item.id, getResellUnitAmount(item))) return false;
    }
    return !hasUnsavedResellEdits.value;
  };

  // —— Step 3–4: delivery & charges ——
  const addressOptions = useBDAddressOptions();

  onMounted(async () => {
    const requested = parseInitialStep();
    maxReachableStep.value = Math.max(1, requested);
    currentStep.value = Math.min(requested, maxReachableStep.value);
    syncStepQuery();
    await addressOptions.loadInitialDistricts();
  });
  const lastLookupPhone = ref('');
  const isPhoneProfileLoading = ref(false);
  const recipientPaysDelivery = ref(true);
  const recipientPaysCod = ref(true);

  const customerForm = reactive({
    recipientName: '',
    recipientPhone: '',
    secondaryPhone: '',
    district: '',
    thana: '',
    postCode: '',
    shippingAddress: '',
    deliveryInstructions: '',
  });

  const deliveryDetailsHydratedForCart = ref<number | null>(null);
  const skipDeliveryDetailsPersist = ref(false);

  const cart = computed(() => reviewCartQuery.cart.value);
  const deliveryCharge = computed(() => 0);
  const codCharge = computed(() => 0);
  const printCharge = computed(() => cart.value?.charges.print_charge_amount ?? 0);
  const packingCharge = computed(() => cart.value?.charges.packing_charge_amount ?? 0);

  const chargePreview = computed(() => ({
    deliveryCharge: deliveryCharge.value,
    codCharge: codCharge.value,
    printCharge: printCharge.value,
    packingCharge: packingCharge.value,
    recipientPaysDelivery: recipientPaysDelivery.value,
    recipientPaysCod: recipientPaysCod.value,
  }));

  const hasPendingDiscountRequests = computed(() =>
    reviewItems.value.some((item) =>
      hasPendingResellDiscount(getRequestedResellDiscountAmount(item)),
    ),
  );

  const costSummary = computed(() => {
    const recipientDeliveryCharge = recipientPaysDelivery.value ? deliveryCharge.value : 0;
    const recipientCodCharge = recipientPaysCod.value ? codCharge.value : 0;
    const merchantDelivery = recipientPaysDelivery.value ? 0 : deliveryCharge.value;
    const merchantCod = recipientPaysCod.value ? 0 : codCharge.value;
    const merchantDeductions =
      merchantDelivery + merchantCod + printCharge.value + packingCharge.value;
    const actualResellTotal = reviewCartQuery.resellSubtotal.value;
    const effectiveResellTotal = columnTotals.value.resellTotal;
    const recipientGrandTotal =
      effectiveResellTotal + recipientDeliveryCharge + recipientCodCharge;

    return {
      resellTotal: effectiveResellTotal,
      actualResellTotal,
      hasPendingDiscount: hasPendingDiscountRequests.value,
      recipientDeliveryCharge,
      recipientCodCharge,
      recipientGrandTotal,
      merchantDeductions,
    };
  });

  const isDeliveryFormValid = computed(() => {
    const phone = customerForm.recipientPhone.trim();
    return (
      customerForm.recipientName.trim().length > 0 &&
      /^01[3-9]\d{8}$/.test(phone) &&
      customerForm.shippingAddress.trim().length > 0 &&
      !isPhoneProfileLoading.value
    );
  });

  const canPlaceOrder = computed(
    () =>
      isDeliveryFormValid.value &&
      termsAccepted.value &&
      !reviewSummary.value.hasFloorViolation &&
      !submitOrderMutation.isPending.value,
  );

  const canGoNext = computed(() => {
    if (currentStep.value === 5) {
      return termsAccepted.value;
    }
    return true;
  });

  const clearEndCustomerDetailsFromPhone = () => {
    customerForm.recipientName = '';
    customerForm.secondaryPhone = '';
    customerForm.district = '';
    customerForm.thana = '';
    customerForm.postCode = '';
    customerForm.shippingAddress = '';
    customerForm.deliveryInstructions = '';
  };

  const applyDeliveryDetailsFromCart = async (
    details?: DropshipCartDeliveryDetails,
    chargesInstructions?: string | null,
  ) => {
    const hasDetails = hasStoredDeliveryDetails(details);
    const mapped = deliveryDetailsToForm(details);
    const hasStoredTerms = details?.terms_accepted === true;
    if (!hasDetails && !chargesInstructions && !hasStoredTerms) {
      return;
    }

    skipDeliveryDetailsPersist.value = true;
    try {
      if (mapped.recipientName) customerForm.recipientName = mapped.recipientName;
      if (mapped.recipientPhone) customerForm.recipientPhone = mapped.recipientPhone;
      if (mapped.secondaryPhone) customerForm.secondaryPhone = mapped.secondaryPhone;
      if (mapped.district) customerForm.district = mapped.district;
      if (mapped.thana) customerForm.thana = mapped.thana;
      if (mapped.postCode) customerForm.postCode = mapped.postCode;
      if (mapped.shippingAddress) customerForm.shippingAddress = mapped.shippingAddress;
      if (mapped.deliveryInstructions) {
        customerForm.deliveryInstructions = mapped.deliveryInstructions;
      } else if (chargesInstructions) {
        customerForm.deliveryInstructions = chargesInstructions;
      }
      if (mapped.recipientPaysDelivery !== undefined) {
        recipientPaysDelivery.value = mapped.recipientPaysDelivery;
      }
      if (mapped.recipientPaysCod !== undefined) {
        recipientPaysCod.value = mapped.recipientPaysCod;
      }
      if (mapped.termsAccepted !== undefined) {
        termsAccepted.value = mapped.termsAccepted;
      }

      if (customerForm.district) {
        await addressOptions.updateThanaList(customerForm.district);
      }
      if (customerForm.district && customerForm.thana) {
        await addressOptions.updatePostcodeList(
          customerForm.district,
          customerForm.thana,
          customerForm.postCode || undefined,
        );
      }

      const phoneDigits = customerForm.recipientPhone.replace(/\D/g, '');
      if (/^01\d{9}$/.test(phoneDigits)) {
        lastLookupPhone.value = phoneDigits;
      }
    } finally {
      skipDeliveryDetailsPersist.value = false;
    }
  };

  const persistDeliveryDetails = () => {
    if (skipDeliveryDetailsPersist.value || !shopId.value || !cart.value?.id) return;
    if (updateDeliveryDetailsMutation.isPending.value) return;

    void updateDeliveryDetailsMutation.mutateAsync({
      shopId: shopId.value,
      deliveryDetails: formToDeliveryDetails(
        customerForm,
        recipientPaysDelivery.value,
        recipientPaysCod.value,
        termsAccepted.value,
      ),
    });
  };

  watch(
    () => [cart.value?.id, cart.value?.delivery_details, cart.value?.charges.delivery_instructions] as const,
    async ([cartId, details, deliveryInstructions]) => {
      if (!cartId || deliveryDetailsHydratedForCart.value === cartId) return;
      await applyDeliveryDetailsFromCart(details, deliveryInstructions);
      deliveryDetailsHydratedForCart.value = cartId;
    },
    { immediate: true },
  );

  watch(shopId, () => {
    deliveryDetailsHydratedForCart.value = null;
  });

  watch(
    () => customerForm.recipientPhone.replace(/\D/g, ''),
    (phone) => {
      if (isPhoneProfileLoading.value) return;
      if (!lastLookupPhone.value) return;
      if (phone !== lastLookupPhone.value) {
        clearEndCustomerDetailsFromPhone();
        lastLookupPhone.value = '';
      }
    },
  );

  const onDistrictChange = async (newDistrict: string) => {
    customerForm.thana = '';
    customerForm.postCode = '';
    await addressOptions.updateThanaList(newDistrict);
  };

  const onThanaChange = async (newThana: string) => {
    customerForm.postCode = '';
    await addressOptions.updatePostcodeList(customerForm.district, newThana);
  };

  const onRecipientPhoneBlur = async () => {
    const phone = customerForm.recipientPhone.replace(/\D/g, '');
    const tenantId = cart.value?.tenant_id;
    if (!tenantId || !/^01\d{9}$/.test(phone)) return;
    if (phone === lastLookupPhone.value) return;

    isPhoneProfileLoading.value = true;
    lastLookupPhone.value = phone;
    try {
      const profile = await recipientProfileStore.getByPhone(tenantId, phone);
      if (!profile) {
        lastLookupPhone.value = '';
        return;
      }

      customerForm.recipientName = profile.name || '';
      customerForm.secondaryPhone = profile.secondary_phone || '';

      let baseAddress = profile.address || '';
      let extractedPostcode = '';
      const postCodeMatch = baseAddress.match(/Post\s*Code:\s*([^\n,]+)/i);
      if (postCodeMatch) {
        extractedPostcode = postCodeMatch[1]?.trim() || '';
      }
      baseAddress = baseAddress.replace(/\n?(?:Thana|District|Post\s*Code):.*$/gi, '').trim();

      customerForm.shippingAddress = baseAddress;
      customerForm.district = profile.district || '';
      customerForm.thana = profile.thana || '';
      customerForm.postCode = extractedPostcode;
      if (profile.district) {
        await addressOptions.updateThanaList(profile.district);
      }
      if (profile.district && profile.thana) {
        await addressOptions.updatePostcodeList(
          customerForm.district,
          customerForm.thana,
          extractedPostcode || undefined,
        );
      }
    } catch {
      lastLookupPhone.value = '';
    } finally {
      isPhoneProfileLoading.value = false;
    }
  };

  const validateStep = async (step: number): Promise<boolean> => {
    if (step === 1) {
      if (lockItems.value.length === 0) {
        showErrorNotification(t('shop.cart_empty'));
        return false;
      }
      if (hasUnsavedQtyEdits.value) {
        const saved = await saveAllQtyEdits();
        if (!saved) {
          showErrorNotification(t('shop.cart_save_edits_first'));
          return false;
        }
      }
      return true;
    }
    if (step === 2) {
      if (reviewSummary.value.hasFloorViolation) {
        showErrorNotification(t('shop.cart_price_below_floor'));
        return false;
      }
      if (hasUnsavedResellEdits.value) {
        const saved = await saveAllResellEdits();
        if (!saved) {
          showErrorNotification(t('shop.cart_save_edits_first'));
          return false;
        }
      }
      return true;
    }
    if (step === 3) {
      if (!isDeliveryFormValid.value) {
        showErrorNotification(t('shop.dropship_delivery_form_hint'));
        return false;
      }
      return true;
    }
    if (step === 4) return true;
    if (step === 5) {
      if (!termsAccepted.value) {
        showErrorNotification(t('shop.dropship_terms_required'));
        return false;
      }
      return true;
    }
    return true;
  };

  const goNext = async () => {
    const step = currentStep.value;
    if (!(await validateStep(step))) return;
    if (step === 3 || step === 4 || step === 5) {
      persistDeliveryDetails();
    }
    if (step >= DROPSHIP_PLACE_ORDER_STEP_COUNT) return;
    maxReachableStep.value = Math.max(maxReachableStep.value, step + 1);
    currentStep.value = step + 1;
  };

  const goBack = () => {
    if (currentStep.value <= 1) return;
    currentStep.value -= 1;
  };

  const goToStep = async (index: number) => {
    const oneBased = index + 1;
    if (oneBased > maxReachableStep.value || oneBased === currentStep.value) return;
    if (oneBased > currentStep.value) return;
    currentStep.value = oneBased;
  };

  const isDirty = computed(
    () => hasUnsavedQtyEdits.value || hasUnsavedResellEdits.value,
  );

  useUnsavedLeaveGuard({
    isDirty,
    onSave: async () => {
      if (hasUnsavedQtyEdits.value) {
        const qty = await saveAllQtyEdits();
        if (!qty) return false;
      }
      if (hasUnsavedResellEdits.value) {
        return saveAllResellEdits();
      }
      return true;
    },
    onDiscard: () => {
      editedQuantities.value = {};
      editedResellPrices.value = {};
    },
    title: t('shop.unsaved_leave_title'),
    message: t('shop.unsaved_leave_message'),
  });

  const hasActiveDropshipOrder = computed(
    () => Boolean(shopId.value) && (lockItems.value.length > 0 || reviewItems.value.length > 0),
  );

  useDropshipOrderFlowLeaveGuard({
    hasActiveOrder: hasActiveDropshipOrder,
    skip: skipFlowLeaveGuard,
  });

  const tenantSlugParam = () =>
    route.params.tenantSlug ? String(route.params.tenantSlug) : null;

  const submitOrder = async () => {
    if (!canPlaceOrder.value || !shopId.value) return;

    const result = await submitOrderMutation.mutateAsync({
      shopId: shopId.value,
      recipientName: customerForm.recipientName.trim(),
      recipientPhone: customerForm.recipientPhone.trim(),
      shippingAddress: customerForm.shippingAddress.trim(),
      recipientPhoneSecondary: customerForm.secondaryPhone.trim() || null,
      shippingDistrict: customerForm.district.trim() || null,
      shippingThana: customerForm.thana.trim() || null,
      shippingPostCode: customerForm.postCode.trim() || null,
      deliveryInstructions: customerForm.deliveryInstructions.trim() || null,
      isPrepaid: cart.value?.charges.is_prepaid ?? false,
      codChargeAmount: codCharge.value,
      deliveryChargeAmount: deliveryCharge.value,
      printChargeAmount: printCharge.value,
      packingChargeAmount: packingCharge.value,
      discountAmount: cart.value?.charges.discount_amount ?? 0,
      recipientPaysDelivery: recipientPaysDelivery.value,
      recipientPaysCod: recipientPaysCod.value,
    });

    skipFlowLeaveGuard.value = true;
    void router.push(
      shopCustomerOrderDetailRoute(tenantSlugParam(), result.data.order_id, 'dropship'),
    );
  };

  const navLayout = computed<'rail' | 'compact'>(() =>
    $q.screen.lt.sm ? 'compact' : 'rail',
  );

  const currentStepIndex = computed(() => currentStep.value - 1);
  const maxReachableIndex = computed(() => maxReachableStep.value - 1);
  const isSubmitting = computed(() => submitOrderMutation.isPending.value);

  return {
    steps: DROPSHIP_PLACE_ORDER_STEPS,
    stepCount: DROPSHIP_PLACE_ORDER_STEP_COUNT,
    shopId,
    currentStep,
    currentStepIndex,
    maxReachableIndex,
    navLayout,
    termsAccepted,
    isLoading,
    isError,
    refetchAll,
    currencySymbol,
    lockItems,
    reviewItems,
    lockCartQuery,
    getPurchaseUnitAmount: (item: DropshipCartItem) =>
      lockCartQuery.getPurchaseUnitAmount(item),
    getItemQty,
    hasUnsavedQty,
    isCartBusy,
    isUpdatingQty,
    removingItemId,
    adjustItemQtyLocal,
    saveItemQty,
    removeItem,
    uiReviewItems,
    columnTotals,
    reviewSummary,
    updateResellPriceLocal,
    saveResellPrice,
    isUpdatingPrice,
    savingItemId,
    customerForm,
    addressOptions,
    districtOptions: addressOptions.districtOptions,
    thanaOptions: addressOptions.thanaOptions,
    postcodeOptions: addressOptions.postcodeOptions,
    filterDistrict: addressOptions.filterDistrict,
    filterThana: addressOptions.filterThana,
    filterPostcode: addressOptions.filterPostcode,
    createPostcode: addressOptions.createPostcode,
    isPhoneProfileLoading,
    onRecipientPhoneBlur,
    onDistrictChange,
    onThanaChange,
    recipientPaysDelivery,
    recipientPaysCod,
    chargePreview,
    costSummary,
    hasPendingDiscountRequests,
    canPlaceOrder,
    canGoNext,
    isSubmitting,
    goNext,
    goBack,
    goToStep,
    submitOrder,
  };
}