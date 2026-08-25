<template>
  <q-page class="q-pa-md shop-commerce-page">
    <div class="q-gutter-y-md">
      <!-- Standard Page Header -->
      <ShopCartHeader
        :show-cart-picker="showCartPicker"
        :item-count="itemCount"
        :active-carts="activeCarts"
        :current-shop-cart-info="currentShopCartInfo"
        :selected-shop-id="selectedShopId"
        :format-active-cart-total="formatActiveCartTotal"
        @go-back="goBack"
        @select-shop-cart="selectShopCart"
      />

      <q-banner
        v-if="placesOrderFromCart && items.length > 0 && !isCartsLoading && !isCartLoading"
        class="catalog-banner text-primary rounded-borders"
        dense
      >
        {{ $t('shop.cart_place_order_banner') }}
      </q-banner>

      <!-- Loading Skeleton State -->
      <ShopCartSkeleton v-if="isCartsLoading || isCartLoading" />

      <!-- Cart List Error State -->
      <q-card v-else-if="isCartsError" flat bordered class="q-pa-xl text-center">
        <q-card-section>
          <q-icon name="ph ph-warning-circle" size="64px" color="negative" class="q-mb-md" />
          <div class="text-h6 text-grey-8 text-weight-bold q-mb-xs">
            {{ $t('shop.cart_load_error') }}
          </div>
          <div class="text-grey-6 q-mb-md">
            {{ $t('shop.cart_load_error_desc') }}
          </div>
          <q-btn
            color="primary"
            no-caps
            unelevated
            icon="ph ph-arrow-clockwise"
            :label="$t('shop.cart_retry')"
            @click="() => refetchActiveCarts()"
          />
        </q-card-section>
      </q-card>

      <!-- Multiple Carts Picker View -->
      <ShopCartPickerView
        v-else-if="showCartPicker"
        :active-carts="activeCarts"
        :format-active-cart-total="formatActiveCartTotal"
        @select-shop-cart="selectShopCart"
      />

      <!-- Empty State -->
      <q-card v-else-if="items.length === 0" flat bordered class="q-pa-xl text-center">
        <q-card-section>
          <q-icon name="ph ph-shopping-cart" size="64px" color="grey-4" class="q-mb-md" />
          <div class="text-h6 text-grey-7 text-weight-bold">{{ $t('shop.cart_empty') }}</div>
          <p class="text-body2 text-grey-6 q-mt-sm q-mb-md">
            {{ $t('shop.cart_empty_desc') }}
          </p>
          <q-btn
            color="primary"
            no-caps
            unelevated
            :label="$t('shop.continue_shopping')"
            @click="goBack"
          />
        </q-card-section>
      </q-card>

      <!-- Cart Content Grid -->
      <div v-else class="row q-col-gutter-lg cart-content">
        <!-- Cart Items List (8 cols on desktop) -->
        <div class="col-xs-12 col-md-8">
          <ShopCartItemsList
            :items="items"
            :item-count="itemCount"
            :current-shop-cart-info="currentShopCartInfo"
            :cart="cart"
            :can-see-buy-price="canSeeBuyPrice"
            :can-see-sell-price="canSeeSellPrice"
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

        <!-- Checkout Summary (4 cols on desktop) -->
        <div class="col-xs-12 col-md-4">
          <ShopCartSummaryCard
            :cart="cart"
            :can-see-buy-price="canSeeBuyPrice"
            :can-see-sell-price="canSeeSellPrice"
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

    <q-page-sticky
      v-if="items.length > 0 && !showCartPicker && !isCartsLoading && !isCartLoading"
      position="bottom"
      expand
      class="lt-sm"
    >
      <div class="cart-mobile-cta row items-center no-wrap q-px-md q-py-sm">
        <div v-if="canSeePrices" class="col">
          <div class="text-caption text-grey-6">
            {{ cart?.shop_type === 'dropship' ? $t('shop.recipient_pay_total') : $t('shop.estimated_total') }}
          </div>
          <div class="text-subtitle1 text-weight-bold text-primary">
            {{ cart?.shop_type === 'dropship' ? formatAmount(recipientGrandTotal) : formatCartTotal() }}
          </div>
        </div>
        <span>
          <q-btn
            color="primary"
            unelevated
            no-caps
            :label="$t(checkoutLabelKey)"
            :loading="isSaving || placingOrder"
            :disable="checkoutDisabled"
            @click="handleButtonClick"
          />
          <q-tooltip v-if="checkoutDisabled && checkoutDisabledReason">
            {{ $t(checkoutDisabledReason) }}
          </q-tooltip>
        </span>
      </div>
    </q-page-sticky>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useActiveShopCartsQuery } from '../composables/useActiveShopCartsQuery';
import { useShopCartQuery } from '../composables/useShopCartQuery';
import { useShopCartPageLogic } from '../composables/useShopCartPageLogic';
import ShopCartHeader from '../components/ShopCartHeader.vue';
import ShopCartPickerView from '../components/ShopCartPickerView.vue';
import ShopCartItemsList from '../components/ShopCartItemsList.vue';
import ShopCartSummaryCard from '../components/ShopCartSummaryCard.vue';
import ShopCartSkeleton from '../components/ShopCartSkeleton.vue';

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
const canSeePrices = computed(() => canSeeBuyPrice.value || canSeeSellPrice.value);

const logic = useShopCartPageLogic(
  activeCarts,
  isCartsLoading,
  cart,
  items,
  itemCount,
  cartTotal,
  buyerCartTotal,
);

// Sync selectedShopIdRef with logic.selectedShopId
watch(logic.selectedShopId, (val) => {
  selectedShopIdRef.value = val;
}, { immediate: true });

const {
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

<style scoped>
.catalog-banner {
  background: var(--bw-theme-primary-soft);
}

.cart-mobile-cta {
  background: var(--bw-theme-surface, #ffffff);
  border-top: 1px solid var(--bw-theme-border, rgba(34, 56, 101, 0.08));
}

@media (max-width: 599px) {
  .cart-content {
    padding-bottom: 72px;
  }
}
</style>

