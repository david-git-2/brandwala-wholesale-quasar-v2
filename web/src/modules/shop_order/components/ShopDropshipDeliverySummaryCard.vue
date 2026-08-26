<template>
  <q-card flat bordered class="dropship-delivery-summary sticky-card">
    <q-card-section class="q-px-md q-py-sm border-bottom">
      <div class="text-subtitle2 text-weight-bold text-grey-9">
        {{ $t('shop.order_summary') }}
      </div>
    </q-card-section>

    <q-card-section class="q-py-md column q-gutter-y-sm">
      <div class="row justify-between text-body2 text-grey-7">
        <span>{{ $t('shop.items_subtotal') }}</span>
        <span class="text-weight-medium text-grey-9">{{ formatMoney(summary.resellTotal) }}</span>
      </div>

      <div
        v-if="summary.recipientDeliveryCharge > 0"
        class="row justify-between text-body2 text-grey-7"
      >
        <span>{{ $t('shop.delivery_charge') }}</span>
        <span class="text-weight-medium text-grey-9">
          {{ formatMoney(summary.recipientDeliveryCharge) }}
        </span>
      </div>

      <div
        v-if="summary.recipientCodCharge > 0"
        class="row justify-between text-body2 text-grey-7"
      >
        <span>{{ $t('shop.cod_fee') }}</span>
        <span class="text-weight-medium text-grey-9">
          {{ formatMoney(summary.recipientCodCharge) }}
        </span>
      </div>

      <q-separator class="q-my-xs" />

      <div class="row justify-between items-baseline">
        <span class="text-subtitle1 text-weight-bold text-grey-9">{{ $t('shop.recipient_pay_total') }}</span>
        <span class="text-h6 text-weight-bold text-primary">
          {{ formatMoney(summary.recipientGrandTotal) }}
        </span>
      </div>

      <div
        v-if="summary.merchantDeductions > 0"
        class="row justify-between text-caption text-grey-6"
      >
        <span>{{ $t('shop.dropship_merchant_deductions') }}</span>
        <span class="text-negative text-weight-medium">
          -{{ formatMoney(summary.merchantDeductions) }}
        </span>
      </div>

      <q-btn
        color="primary"
        unelevated
        no-caps
        class="full-width q-mt-md"
        icon-right="ph ph-check"
        :label="$t('shop.place_order')"
        :disable="!canSubmit"
        @click="$emit('place-order')"
      />
      <div v-if="!canSubmit" class="text-caption text-grey-6 text-center">
        {{ $t('shop.dropship_delivery_form_hint') }}
      </div>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import { formatDropshipUiMoney } from '../mocks/dropshipCartUiMocks';

export interface DropshipDeliverySummary {
  resellTotal: number;
  recipientDeliveryCharge: number;
  recipientCodCharge: number;
  recipientGrandTotal: number;
  merchantDeductions: number;
}

const props = defineProps<{
  summary: DropshipDeliverySummary;
  canSubmit: boolean;
  currencySymbol?: string;
}>();

defineEmits<{
  (e: 'place-order'): void;
}>();

const formatMoney = (amount: number) =>
  formatDropshipUiMoney(amount, props.currencySymbol ?? '৳');
</script>

<style scoped>
.dropship-delivery-summary {
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
