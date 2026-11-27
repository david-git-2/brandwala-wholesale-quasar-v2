<template>
  <div class="column q-gutter-y-md">
    <ShopDropshipChargeOptionsCard
      v-model:recipient-pays-delivery="recipientPaysDelivery"
      v-model:recipient-pays-cod="recipientPaysCod"
      :charges="chargePreview"
      :currency-symbol="currencySymbol"
      :disable="false"
    />
    <q-card flat bordered>
      <q-card-section class="q-pa-md column q-gutter-y-sm">
        <div class="text-subtitle2 text-weight-bold">{{ $t('shop.dropship_merchant_deductions') }}</div>
        <div class="row justify-between text-body2">
          <span>{{ $t('shop.dropship_margin_estimate') }}</span>
          <span class="tf-num text-weight-medium">
            {{ formatMoney(costSummary.resellTotal - columnTotals.purchaseTotal) }}
          </span>
        </div>
        <div v-if="costSummary.merchantDeductions > 0" class="row justify-between text-body2 text-grey-7">
          <span>{{ $t('shop.dropship_merchant_deductions') }}</span>
          <span class="tf-num">{{ formatMoney(costSummary.merchantDeductions) }}</span>
        </div>
        <template v-if="costSummary.hasPendingDiscount">
          <div class="row justify-between text-body2 text-grey-7">
            <span>{{ $t('shop.dropship_current_resell_total') }}</span>
            <span class="tf-num">{{ formatMoney(costSummary.actualResellTotal) }}</span>
          </div>
          <div class="row justify-between text-body2">
            <span class="text-weight-medium">{{ $t('shop.dropship_pending_discount_resell_total') }}</span>
            <span class="tf-num text-weight-bold dropship-cost-summary__pending-amount">
              {{ formatMoney(costSummary.resellTotal) }}
            </span>
          </div>
          <div class="text-caption dropship-cost-summary__pending-note">
            {{ $t('shop.dropship_totals_pending_discount_note') }}
          </div>
        </template>
        <q-separator />
        <div class="row justify-between items-center">
          <span class="text-subtitle2 text-weight-bold">{{ $t('shop.recipient_pay_total') }}</span>
          <span
            class="text-h6 text-weight-bold tf-num"
            :class="costSummary.hasPendingDiscount ? 'dropship-cost-summary__pending-amount' : 'text-primary'"
          >
            {{ formatMoney(costSummary.recipientGrandTotal) }}
          </span>
        </div>
        <div
          v-if="costSummary.hasPendingDiscount"
          class="text-caption dropship-cost-summary__pending-note q-mt-xs"
        >
          {{ $t('shop.dropship_resell_total_if_discount_accepted') }}
        </div>
      </q-card-section>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import ShopDropshipChargeOptionsCard from '../ShopDropshipChargeOptionsCard.vue';
import type { DropshipChargePreview } from '../ShopDropshipChargeOptionsCard.vue';

const recipientPaysDelivery = defineModel<boolean>('recipientPaysDelivery', { required: true });
const recipientPaysCod = defineModel<boolean>('recipientPaysCod', { required: true });

const props = defineProps<{
  chargePreview: DropshipChargePreview;
  costSummary: {
    resellTotal: number;
    actualResellTotal: number;
    hasPendingDiscount: boolean;
    recipientGrandTotal: number;
    merchantDeductions: number;
  };
  columnTotals: { purchaseTotal: number; resellTotal: number };
  currencySymbol: string;
}>();

const formatMoney = (amount: number) => {
  const sym = props.currencySymbol?.trim() || '৳';
  return `${sym} ${amount.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
};
</script>

<style scoped>
.dropship-cost-summary__pending-amount {
  color: color-mix(in srgb, var(--tf-warning) 75%, var(--tf-neutral-ink));
}

.dropship-cost-summary__pending-note {
  line-height: 1.35;
  color: rgba(34, 56, 101, 0.58);
}
</style>