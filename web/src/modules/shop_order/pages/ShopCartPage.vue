<template>
  <q-page class="bw-page theme-shop" data-test="shop-cart-page">
    <div class="bw-page__stack">
      <ShopCartHeader
        :show-cart-picker="showCartPicker"
        :item-count="itemCount"
      />

      <q-banner
        v-if="placesOrderFromCart && items.length > 0 && !isCartsLoading && !isCartLoading"
        dense
        rounded
        class="bg-theme-primary-soft text-primary"
        data-test="shop-cart-place-order-banner"
      >
        {{ $t('shop.cart_place_order_banner') }}
      </q-banner>

      <ShopCartSkeleton
        v-if="isCartsLoading || isCartLoading || (!selectedShopId && scopedActiveCarts.length > 0)"
      />

      <template v-else-if="isCartsError">
        <q-banner class="bw-status-banner bg-negative text-white" rounded data-test="shop-cart-error">
          <div class="text-subtitle1 text-weight-bold">{{ $t('shop.cart_load_error') }}</div>
          <div class="q-mt-xs">{{ $t('shop.cart_load_error_desc') }}</div>
        </q-banner>
        <div class="row justify-center">
          <q-btn
            color="primary"
            no-caps
            unelevated
            icon="ph ph-arrow-clockwise"
            :label="$t('shop.cart_retry')"
            class="square-btn"
            data-test="shop-cart-retry"
            @click="() => refetchActiveCarts()"
          />
        </div>
      </template>

      <div
        v-else-if="(!selectedShopId && scopedActiveCarts.length === 0) || items.length === 0"
        class="column items-center justify-center q-pa-xl text-center empty-state-block floating-surface"
        data-test="shop-cart-empty"
      >
        <q-icon name="ph ph-shopping-cart" size="64px" class="q-mb-md bw-text-muted" />
        <div class="text-subtitle1 text-weight-bold">{{ $t('shop.cart_empty') }}</div>
        <p class="bw-type-body bw-text-muted q-mt-sm q-mb-md">
          {{ $t('shop.cart_empty_desc') }}
        </p>
        <q-btn
          color="primary"
          no-caps
          unelevated
          :label="$t('shop.continue_shopping')"
          class="square-btn"
          data-test="shop-cart-continue-shopping"
          @click="goBack"
        />
      </div>

      <div v-else class="row q-col-gutter-lg">
        <div class="col-xs-12 col-md-8">
          <ShopCartItemsList
            :items="items"
            :item-count="itemCount"
            :current-shop-cart-info="currentShopCartInfo"
            :cart="cart"
            :can-see-buy-price="canSeeBuyPrice"
            :can-see-sell-price="canSeeSellPrice"
            :can-see-line-prices="canSeeLinePrices"
            :currency-symbol="currencySymbol"
            :permissions="permissions"
            :edited-quantities="editedQuantities"
            :edited-prices="editedPrices"
            :is-saving="isSaving"
            :get-item-qty="getItemQty"
            :get-item-price="getItemPrice"
            :format-unit-price="formatUnitPrice"
            :format-item-total="formatItemTotal"
            :format-buyer-unit-price="formatBuyerUnitPrice"
            :format-buyer-item-total="formatBuyerItemTotal"
            :is-item-price-below-floor="isItemPriceBelowFloor"
            @update-price-local="updatePriceLocal"
            @save-item-price="saveItemPrice"
            @adjust-qty-local="adjustItemQtyLocal"
            @save-item-qty="saveItemQty"
            @remove-item="removeItem"
          />
        </div>

        <div class="col-xs-12 col-md-4">
          <ShopCartSummaryCard
            :cart="cart"
            :can-see-buy-price="canSeeBuyPrice"
            :can-see-sell-price="canSeeSellPrice"
            :can-see-line-prices="canSeeLinePrices"
            :item-count="itemCount"
            :format-cart-total="formatCartTotal"
            :format-amount="formatAmount"
            :print-charge="printCharge"
            :packing-charge="packingCharge"
            :default-packing-charge="defaultPackingCharge"
            :courier-estimate="courierEstimate"
            :cod-estimate-summary="codEstimateSummary"
            :buyer-total="buyerTotal"
            :estimated-profit="estimatedProfit"
            :recipient-grand-total="recipientGrandTotal"
            :is-saving="isSaving"
            :placing-order="placingOrder"
            :checkout-disabled="checkoutDisabled"
            :checkout-disabled-reason="checkoutDisabledReason"
            :checkout-label-key="checkoutLabelKey"
            @handle-button-click="handleButtonClick"
          />
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useActiveShopCartsQuery } from '../composables/useActiveShopCartsQuery';
import { useShopCartQuery } from '../composables/useShopCartQuery';
import { useShopCartPageLogic } from '../composables/useShopCartPageLogic';
import ShopCartHeader from '../components/ShopCartHeader.vue';
import ShopCartItemsList from '../components/ShopCartItemsList.vue';
import ShopCartSummaryCard from '../components/ShopCartSummaryCard.vue';
import ShopCartSkeleton from '../components/ShopCartSkeleton.vue';
import { customerCanSeeCartLinePrices } from '../utils/catalogPriceUtils';

const {
  data: activeCartsData,
  isLoading: isCartsLoading,
  isError: isCartsError,
  refetch: refetchActiveCarts,
} = useActiveShopCartsQuery();
const activeCarts = computed(() => activeCartsData.value ?? []);

const selectedShopIdRef = ref<number | null>(null);

const {
  cart,
  items,
  itemCount,
  cartTotal,
  buyerCartTotal,
  recipientGrandTotal,
  estimatedProfit,
  permissions,
  isLoading: isCartLoading,
} = useShopCartQuery(selectedShopIdRef);

const canSeeBuyPrice = computed(() => !!permissions.value?.can_see_buy_price);
const canSeeSellPrice = computed(() => !!permissions.value?.can_see_sell_price);
const canSeeLinePrices = computed(() =>
  customerCanSeeCartLinePrices(cart.value?.shop_type, permissions.value),
);

const logic = useShopCartPageLogic(
  activeCarts,
  isCartsLoading,
  cart,
  items,
  itemCount,
  cartTotal,
  buyerCartTotal,
);

watch(logic.selectedShopId, (val) => {
  selectedShopIdRef.value = val;
}, { immediate: true });

const {
  selectedShopId,
  scopedActiveCarts,
  showCartPicker,
  currentShopCartInfo,
  currencySymbol,
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
  buyerTotal,
  courierEstimate,
  codEstimateSummary,
  formatAmount,
  formatCartTotal,
} = logic;
</script>

<script lang="ts">
export default {
  name: 'ShopCartPage',
};
</script>
