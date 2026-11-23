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
        <div v-if="summary.hasPendingDiscount" class="dropship-review-summary__pending q-mt-sm">
          <div class="row justify-between text-body2">
            <span>{{ $t('shop.dropship_current_resell_total') }}</span>
            <span class="tf-num text-grey-7">{{ formatMoney(summary.currentItemsTotal) }}</span>
          </div>
          <div class="row justify-between text-body2 q-mt-xs">
            <span>{{ $t('shop.dropship_pending_discount_resell_total') }}</span>
            <span class="text-weight-bold dropship-review-summary__pending-amount tf-num">
              {{ formatMoney(summary.itemsTotal) }}
            </span>
          </div>
          <div class="text-caption dropship-review-summary__pending-note q-mt-xs">
            {{ $t('shop.dropship_resell_total_if_discount_accepted') }}
          </div>
        </div>
      </div>

      <div class="row q-col-gutter-sm items-stretch dropship-review-summary__actions">
        <div class="col-auto">
          <q-btn
            outline
            color="primary"
            unelevated
            no-caps
            class="full-height pill-btn q-py-sm dropship-review-summary__back"
            icon="ph ph-arrow-left"
            :label="$t('shop.go_back')"
            @click="$emit('back')"
          />
        </div>
        <div class="col min-width-0">
          <q-btn
            color="primary"
            unelevated
            no-caps
            class="full-width full-height pill-btn q-py-sm"
            icon-right="ph ph-arrow-right"
            :label="$t('shop.dropship_continue_delivery')"
            :disable="summary.hasFloorViolation || disableContinue"
            @click="$emit('continue')"
          />
        </div>
      </div>

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
  currentItemsTotal?: number;
  hasPendingDiscount?: boolean;
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
  (e: 'back'): void;
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

.dropship-review-summary__pending {
  padding-top: 8px;
  border-top: 1px solid var(--tf-neutral-border, rgba(34, 56, 101, 0.08));
}

.dropship-review-summary__pending-amount {
  color: color-mix(in srgb, var(--tf-warning) 75%, var(--tf-neutral-ink));
}

.dropship-review-summary__pending-note {
  line-height: 1.35;
  color: rgba(34, 56, 101, 0.58);
}

.dropship-review-summary__actions .q-btn {
  min-height: 44px;
}

.dropship-review-summary__back {
  white-space: nowrap;
}
</style>
