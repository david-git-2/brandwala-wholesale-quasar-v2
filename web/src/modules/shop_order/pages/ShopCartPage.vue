<template>
  <q-page class="q-pa-md">
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

      <!-- Loading Skeleton State -->
      <ShopCartSkeleton v-if="isCartsLoading || isCartLoading" />

      <!-- Cart List Error State -->
      <q-card v-else-if="isCartsError" flat bordered class="q-pa-xl text-center">
        <q-card-section>
          <q-icon name="ph ph-warning-circle" size="64px" color="negative" class="q-mb-md" />
          <div class="text-h6 text-grey-8 text-weight-bold q-mb-xs">
            Couldn't load your carts
          </div>
          <div class="text-grey-6 q-mb-md">
            Something went wrong while loading your shop carts. Please try again.
          </div>
          <q-btn
            color="primary"
            no-caps
            unelevated
            icon="ph ph-arrow-clockwise"
            label="Retry"
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
      <div v-else class="row q-col-gutter-lg">
        <!-- Cart Items List (8 cols on desktop) -->
        <div class="col-xs-12 col-md-8">
          <ShopCartItemsList
            :items="items"
            :item-count="itemCount"
            :current-shop-cart-info="currentShopCartInfo"
            :cart="cart"
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
            :item-count="itemCount"
            :format-cart-total="formatCartTotal"
            :format-amount="formatAmount"
            :print-charge="printCharge"
            :packing-charge="packingCharge"
            :default-packing-charge="defaultPackingCharge"
            :deduct-print-from-margin="deductPrintFromMargin"
            :deduct-packing-from-margin="deductPackingFromMargin"
            :courier-estimate="courierEstimate"
            :cod-estimate-summary="codEstimateSummary"
            :total-deductible-charges="totalDeductibleCharges"
            :buyer-total="buyerTotal"
            :estimated-profit="estimatedProfit"
            :recipient-grand-total="recipientGrandTotal"
            :is-saving="isSaving"
            :placing-order="placingOrder"
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
} = logic;
</script>

<script lang="ts">
export default {
  name: 'ShopCartPage',
};
</script>
