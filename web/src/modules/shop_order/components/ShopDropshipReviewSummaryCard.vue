<template>
  <q-card flat bordered class="dropship-review-summary sticky-card">
    <q-card-section class="q-px-md q-py-sm border-bottom">
      <div class="text-subtitle2 text-weight-bold text-grey-9">
        {{ $t('shop.order_summary') }}
      </div>
    </q-card-section>

    <q-card-section class="q-py-md column q-gutter-y-sm">
      <div class="row justify-between items-baseline">
        <span class="text-subtitle1 text-weight-bold text-grey-9">{{ $t('shop.recipient_pay_total') }}</span>
        <span class="text-h6 text-weight-bold text-primary">{{ formatMoney(summary.recipientGrandTotal) }}</span>
      </div>

      <div class="row justify-between text-caption text-grey-6">
        <span>{{ $t('shop.dropship_total_units') }}</span>
        <span>{{ summary.totalUnits }}</span>
      </div>

      <q-btn
        color="primary"
        unelevated
        no-caps
        class="full-width q-mt-md"
        icon-right="ph ph-arrow-right"
        :label="$t('shop.dropship_continue_delivery')"
        :disable="summary.hasFloorViolation"
        @click="$emit('continue')"
      />
      <div v-if="summary.hasFloorViolation" class="text-caption text-negative text-center">
        {{ $t('shop.cart_price_below_floor') }}
      </div>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import { formatDropshipUiMoney } from '../mocks/dropshipCartUiMocks';

export interface DropshipReviewSummary {
  recipientGrandTotal: number;
  totalUnits: number;
  hasFloorViolation: boolean;
}

const props = defineProps<{
  summary: DropshipReviewSummary;
  currencySymbol?: string;
}>();

defineEmits<{
  (e: 'continue'): void;
}>();

const formatMoney = (amount: number) =>
  formatDropshipUiMoney(amount, props.currencySymbol ?? '৳');
</script>

<style scoped>
.dropship-review-summary {
  border-radius: 14px;
  background: #ffffff;
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.02);
}

.border-bottom {
  border-bottom: 1px solid rgba(34, 56, 101, 0.08);
}

.sticky-card {
  position: sticky;
  top: 24px;
}
</style>
