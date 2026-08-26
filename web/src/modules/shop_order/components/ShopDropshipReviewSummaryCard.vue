<template>
  <div class="dropship-review-summary sticky-card">
    <q-btn
      color="primary"
      unelevated
      no-caps
      class="full-width"
      icon-right="ph ph-arrow-right"
      :label="$t('shop.dropship_continue_delivery')"
      :disable="summary.hasFloorViolation || disableContinue"
      @click="$emit('continue')"
    />
    <div v-if="summary.hasFloorViolation" class="text-caption text-negative text-center q-mt-sm">
      {{ $t('shop.cart_price_below_floor') }}
    </div>
    <div v-else-if="disableContinue" class="text-caption text-grey-6 text-center q-mt-sm">
      {{ $t('shop.cart_save_edits_first') }}
    </div>
  </div>
</template>

<script setup lang="ts">
export interface DropshipReviewSummary {
  recipientGrandTotal: number;
  totalUnits: number;
  hasFloorViolation: boolean;
}

withDefaults(
  defineProps<{
    summary: DropshipReviewSummary;
    currencySymbol?: string;
    disableContinue?: boolean;
  }>(),
  {
    currencySymbol: '৳',
    disableContinue: false,
  },
);

defineEmits<{
  (e: 'continue'): void;
}>();
</script>

<style scoped>
.sticky-card {
  position: sticky;
  top: 24px;
}
</style>
