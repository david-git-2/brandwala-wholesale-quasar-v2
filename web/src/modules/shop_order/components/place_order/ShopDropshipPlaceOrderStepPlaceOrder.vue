<template>
  <div class="column q-gutter-y-md">
    <ShopDropshipPlaceOrderReviewDocument
      :customer-form="customerForm"
      :recipient-pays-delivery="recipientPaysDelivery"
      :recipient-pays-cod="recipientPaysCod"
      :items="uiItems"
      :item-count="reviewSummary.totalUnits"
      :totals="columnTotals"
      :cost-summary="costSummary"
      :currency-symbol="currencySymbol"
      :terms-accepted="termsAccepted"
    />

    <q-btn
      color="primary"
      unelevated
      no-caps
      class="full-width lt-sm"
      :icon-right="hasPendingDiscountRequests ? 'ph ph-paper-plane-tilt' : 'ph ph-check'"
      :label="
        hasPendingDiscountRequests
          ? $t('shop.dropship_place_order_with_discount_requests')
          : $t('shop.place_order')
      "
      :disable="!canPlaceOrder"
      :loading="isSubmitting"
      @click="$emit('place-order')"
    />
  </div>
</template>

<script setup lang="ts">
import ShopDropshipPlaceOrderReviewDocument from './ShopDropshipPlaceOrderReviewDocument.vue';
import type { DropshipReviewListItem } from '../ShopDropshipReviewItemsList.vue';

defineProps<{
  customerForm: {
    recipientName: string;
    recipientPhone: string;
    secondaryPhone?: string;
    shippingAddress: string;
    district: string;
    thana: string;
    postCode?: string;
    deliveryInstructions?: string;
  };
  recipientPaysDelivery: boolean;
  recipientPaysCod: boolean;
  uiItems: DropshipReviewListItem[];
  columnTotals: { purchaseTotal: number; resellTotal: number };
  reviewSummary: { totalUnits: number };
  costSummary: {
    recipientGrandTotal: number;
    hasPendingDiscount?: boolean;
  };
  currencySymbol: string;
  termsAccepted: boolean;
  hasPendingDiscountRequests: boolean;
  canPlaceOrder: boolean;
  isSubmitting: boolean;
}>();

defineEmits<{
  (e: 'place-order'): void;
}>();
</script>