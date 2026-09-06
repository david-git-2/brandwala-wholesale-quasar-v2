<template>
  <q-card flat bordered class="dropship-delivery-summary">
    <q-card-section class="q-pa-md">
      <div class="q-mb-md">
        <div class="row items-center justify-between">
          <div class="text-subtitle2 text-weight-bold text-grey-9">
            {{ $t('shop.recipient_pay') }}
          </div>
          <div class="text-h6 text-weight-bold text-primary">
            {{ formatMoney(summary.resellTotal) }}
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
        icon-right="ph ph-check"
        :label="$t('shop.place_order')"
        :disable="!canSubmit || isSubmitting"
        :loading="isSubmitting"
        @click="$emit('place-order')"
      />

      <div v-if="!canSubmit && !isSubmitting" class="text-caption text-grey-6 text-center q-mt-sm">
        {{ $t('shop.dropship_delivery_form_hint') }}
      </div>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
export interface DropshipDeliverySummary {
  resellTotal: number;
  recipientDeliveryCharge: number;
  recipientCodCharge: number;
  recipientGrandTotal: number;
  merchantDeductions: number;
}

const props = withDefaults(
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
.dropship-delivery-summary {
  border-radius: 14px;
  background: #ffffff;
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.02);
}
</style>
