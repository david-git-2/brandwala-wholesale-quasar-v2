<template>
  <q-card flat bordered class="dropship-review-summary">
    <q-card-section class="q-pa-md">
      <div class="q-mb-md">
        <div class="row items-center justify-between">
          <div class="text-subtitle2 text-weight-bold text-grey-9">
            {{ $t('shop.recipient_pay') }}
          </div>
          <div class="text-h6 text-weight-bold text-primary">
            {{ formatMoney(summary.itemsTotal) }}
          </div>
        </div>
        <div class="text-caption text-grey-6 q-mt-xs">
          {{ $t('shop.dropship_courier_added_later') }}
        </div>
      </div>

      <q-btn
        color="primary"
        unelevated
        no-caps
        class="full-width pill-btn q-py-sm"
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
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
export interface DropshipReviewSummary {
  itemsTotal: number;
  totalUnits: number;
  hasFloorViolation: boolean;
}

const props = withDefaults(
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

const formatMoney = (amount: number) => {
  const sym = props.currencySymbol?.trim() || '৳';
  const formatted = amount.toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
  return `${sym} ${formatted}`;
};
</script>

<style scoped>
.dropship-review-summary {
  border-radius: 14px;
  background: #ffffff;
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.02);
}
</style>
