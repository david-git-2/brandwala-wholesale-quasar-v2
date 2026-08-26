<template>
  <div class="dropship-delivery-summary sticky-card">
    <q-btn
      color="primary"
      unelevated
      no-caps
      class="full-width"
      icon-right="ph ph-check"
      :label="$t('shop.place_order')"
      :disable="!canSubmit || isSubmitting"
      :loading="isSubmitting"
      @click="$emit('place-order')"
    />
    <div v-if="!canSubmit" class="text-caption text-grey-6 text-center q-mt-sm">
      {{ $t('shop.dropship_delivery_form_hint') }}
    </div>
  </div>
</template>

<script setup lang="ts">
export interface DropshipDeliverySummary {
  resellTotal: number;
  recipientDeliveryCharge: number;
  recipientCodCharge: number;
  recipientGrandTotal: number;
  merchantDeductions: number;
}

withDefaults(
  defineProps<{
    summary: DropshipDeliverySummary;
    canSubmit: boolean;
    currencySymbol?: string;
    isSubmitting?: boolean;
  }>(),
  {
    currencySymbol: '৳',
    isSubmitting: false,
  },
);

defineEmits<{
  (e: 'place-order'): void;
}>();
</script>

<style scoped>
.sticky-card {
  position: sticky;
  top: 24px;
}
</style>
