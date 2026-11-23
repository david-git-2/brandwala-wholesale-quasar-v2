<template>
  <q-page class="dropship-place-order-page shop-commerce-page q-pa-sm column no-wrap fit">
    <div v-if="navLayout === 'compact'" class="q-mb-sm flex-shrink-0">
      <ShopDropshipPlaceOrderStepNav
        :steps="steps"
        :current-index="currentStepIndex"
        :max-reachable-index="maxReachableIndex"
        :layout="navLayout"
        @select="goToStep"
      />
    </div>

    <div class="row col dropship-place-order-page__body min-height-0 no-wrap">
      <div v-if="navLayout === 'rail'" class="dropship-place-order-page__rail column">
        <ShopDropshipPlaceOrderStepNav
          :steps="steps"
          :current-index="currentStepIndex"
          :max-reachable-index="maxReachableIndex"
          layout="rail"
          @select="goToStep"
        />
      </div>

      <div
        v-if="navLayout === 'rail'"
        class="dropship-place-order-page__divider"
        aria-hidden="true"
      />

      <div class="col column min-width-0 min-height-0 dropship-place-order-page__main">
        <div class="col scroll dropship-place-order-page__scroll q-pb-md">
          <ShopCartSkeleton v-if="isLoading" />

          <q-card v-else-if="isError" flat bordered class="q-pa-xl text-center">
            <q-btn
              color="primary"
              no-caps
              unelevated
              icon="ph ph-arrow-clockwise"
              :label="$t('shop.cart_retry')"
              @click="refetchAll"
            />
          </q-card>

          <q-card
            v-else-if="!shopId || (currentStep === 1 && lockItems.length === 0)"
            flat
            bordered
            class="q-pa-xl text-center"
          >
            <div class="text-h6 text-grey-7 text-weight-bold">{{ $t('shop.cart_empty') }}</div>
          </q-card>

          <template v-else>
            <ShopDropshipPlaceOrderStepLockQty
              v-if="currentStep === 1"
              :items="lockItems"
              :currency-symbol="currencySymbol"
              :get-item-qty="getItemQty"
              :has-unsaved-qty="hasUnsavedQty"
              :get-purchase-unit-amount="getPurchaseUnitAmount"
              :is-cart-busy="isCartBusy"
              :is-updating-qty="isUpdatingQty"
              :removing-item-id="removingItemId"
              :adjust-item-qty-local="adjustItemQtyLocal"
              :save-item-qty="saveItemQty"
              :remove-item="removeItem"
            />
            <ShopDropshipPlaceOrderStepResellPrice
              v-else-if="currentStep === 2"
              :shop-id="shopId"
              :ui-items="uiReviewItems"
              :column-totals="columnTotals"
              :review-summary="reviewSummary"
              :currency-symbol="currencySymbol"
              :is-updating-price="isUpdatingPrice"
              :saving-item-id="savingItemId"
              :update-resell-price-local="updateResellPriceLocal"
              :save-resell-price="saveResellPrice"
            />
            <ShopDropshipPlaceOrderStepDelivery
              v-else-if="currentStep === 3"
              :customer-form="customerForm"
              :district-options="districtOptions"
              :thana-options="thanaOptions"
              :postcode-options="postcodeOptions"
              :is-phone-profile-loading="isPhoneProfileLoading"
              :on-recipient-phone-blur="onRecipientPhoneBlur"
              :on-district-change="onDistrictChange"
              :on-thana-change="onThanaChange"
              :filter-district="filterDistrict"
              :filter-thana="filterThana"
              :filter-postcode="filterPostcode"
              :create-postcode="createPostcode"
            />
            <ShopDropshipPlaceOrderStepCostDistribution
              v-else-if="currentStep === 4"
              v-model:recipient-pays-delivery="recipientPaysDelivery"
              v-model:recipient-pays-cod="recipientPaysCod"
              :charge-preview="chargePreview"
              :cost-summary="costSummary"
              :column-totals="columnTotals"
              :currency-symbol="currencySymbol"
            />
            <ShopDropshipPlaceOrderStepConfirmation
              v-else-if="currentStep === 5"
              v-model:terms-accepted="termsAccepted"
            />
            <ShopDropshipPlaceOrderStepPlaceOrder
              v-else-if="currentStep === 6"
              :customer-form="customerForm"
              :recipient-pays-delivery="recipientPaysDelivery"
              :recipient-pays-cod="recipientPaysCod"
              :ui-items="uiReviewItems"
              :column-totals="columnTotals"
              :review-summary="reviewSummary"
              :cost-summary="costSummary"
              :currency-symbol="currencySymbol"
              :terms-accepted="termsAccepted"
              :can-place-order="canPlaceOrder"
              :is-submitting="isSubmitting"
              @place-order="submitOrder"
            />
          </template>
        </div>

        <ShopDropshipPlaceOrderActionBar
          class="flex-shrink-0"
          :sticky="navLayout === 'compact'"
          :show-back="currentStep > 1"
          :show-next="currentStep < stepCount"
          :show-place-order="currentStep === stepCount"
          :can-next="canGoNext"
          :can-place-order="canPlaceOrder"
          :is-submitting="isSubmitting"
          @back="goBack"
          @next="goNext"
          @place-order="submitOrder"
        />
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { useDropshipPlaceOrderWizard } from '../composables/useDropshipPlaceOrderWizard';
import ShopCartSkeleton from '../components/ShopCartSkeleton.vue';
import ShopDropshipPlaceOrderStepNav from '../components/place_order/ShopDropshipPlaceOrderStepNav.vue';
import ShopDropshipPlaceOrderActionBar from '../components/place_order/ShopDropshipPlaceOrderActionBar.vue';
import ShopDropshipPlaceOrderStepLockQty from '../components/place_order/ShopDropshipPlaceOrderStepLockQty.vue';
import ShopDropshipPlaceOrderStepResellPrice from '../components/place_order/ShopDropshipPlaceOrderStepResellPrice.vue';
import ShopDropshipPlaceOrderStepDelivery from '../components/place_order/ShopDropshipPlaceOrderStepDelivery.vue';
import ShopDropshipPlaceOrderStepCostDistribution from '../components/place_order/ShopDropshipPlaceOrderStepCostDistribution.vue';
import ShopDropshipPlaceOrderStepConfirmation from '../components/place_order/ShopDropshipPlaceOrderStepConfirmation.vue';
import ShopDropshipPlaceOrderStepPlaceOrder from '../components/place_order/ShopDropshipPlaceOrderStepPlaceOrder.vue';

const {
  steps,
  stepCount,
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
  getPurchaseUnitAmount,
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
  districtOptions,
  thanaOptions,
  postcodeOptions,
  filterDistrict,
  filterThana,
  filterPostcode,
  createPostcode,
  isPhoneProfileLoading,
  onRecipientPhoneBlur,
  onDistrictChange,
  onThanaChange,
  recipientPaysDelivery,
  recipientPaysCod,
  chargePreview,
  costSummary,
  canGoNext,
  canPlaceOrder,
  isSubmitting,
  goNext,
  goBack,
  goToStep,
  submitOrder,
} = useDropshipPlaceOrderWizard();
</script>

<script lang="ts">
export default {
  name: 'ShopDropshipPlaceOrderPage',
};
</script>

<style scoped>
.dropship-place-order-page {
  width: 100%;
  max-width: none;
  min-height: calc(100dvh - var(--shop-bottom-nav-height, 4.75rem));
}

.dropship-place-order-page__rail {
  width: min(280px, 32vw);
  flex-shrink: 0;
  padding-right: 1rem;
}

.dropship-place-order-page__divider {
  width: 1px;
  flex-shrink: 0;
  align-self: stretch;
  background: var(--tf-neutral-border);
  margin: 0 1rem 0 0;
}

.dropship-place-order-page__main {
  padding-left: 0.25rem;
}

.dropship-place-order-page__body {
  flex: 1 1 auto;
  width: 100%;
  min-height: 0;
}

.dropship-place-order-page__scroll {
  overflow-y: auto;
  -webkit-overflow-scrolling: touch;
}
</style>