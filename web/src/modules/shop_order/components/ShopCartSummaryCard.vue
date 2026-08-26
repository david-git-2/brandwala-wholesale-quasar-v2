<template>
  <q-card flat bordered class="summary-card sticky-card">
    <q-card-section class="q-px-md q-py-sm border-bottom">
      <div class="text-subtitle2 text-weight-bold text-grey-9">
        {{ $t('shop.order_summary') }}
      </div>
    </q-card-section>

    <q-card-section class="q-py-md">
      <template v-if="canSeeBuyPrice || canSeeSellPrice">
        <template v-if="cart?.shop_type === 'dropship'">
          <div v-if="canSeeSellPrice" class="row justify-between q-mb-sm text-body2 text-grey-7">
            <span>{{ $t('shop.items_subtotal') }}</span>
            <span class="text-weight-medium text-grey-9">
              {{ formatCartTotal() }}
            </span>
          </div>

          <div v-if="canSeeBuyPrice" class="row justify-between q-mb-sm text-body2 text-grey-7">
            <span>{{ $t('shop.your_cost_buyer') }}</span>
            <span class="text-weight-medium text-grey-9">
              {{ formatAmount(buyerTotal) }}
            </span>
          </div>

          <div v-if="canSeeBuyPrice && canSeeSellPrice" class="column q-mb-sm bg-green-1 q-pa-sm rounded-borders">
            <div class="row justify-between items-center text-body2">
              <span class="text-weight-bold text-positive row items-center q-gutter-x-xs">
                <q-icon name="ph ph-trend-up" size="16px" />
                <span>{{ $t('shop.estimated_profit') }}</span>
              </span>
              <span class="text-weight-bold text-positive text-subtitle1">
                {{ formatAmount(estimatedProfit) }}
              </span>
            </div>
            <div class="text-caption text-grey-8 q-mt-xs">
              {{ $t('shop.charges_finalized_checkout') }}
            </div>
          </div>

          <q-expansion-item
            dense
            :label="$t('shop.estimated_charges')"
            header-class="text-caption text-grey-7"
            class="q-mb-sm"
          >
            <div class="column q-pa-sm bg-grey-1 rounded-borders">
              <div v-if="printCharge > 0" class="row justify-between text-caption text-grey-7 q-mb-xs">
                <span>{{ $t('shop.print_charge') }}</span>
                <span>{{ formatAmount(printCharge) }}</span>
              </div>
              <div v-if="packingCharge > 0" class="row justify-between text-caption text-grey-7 q-mb-xs">
                <span>
                  {{ $t('shop.packing_charge') }}
                  <span v-if="defaultPackingCharge > 0 && itemCount > 0" class="text-grey-6">
                    ({{ formatAmount(defaultPackingCharge) }} &times; {{ itemCount }})
                  </span>
                </span>
                <span>{{ formatAmount(packingCharge) }}</span>
              </div>
              <div class="row justify-between text-caption text-grey-7 q-mb-xs">
                <span>{{ $t('shop.delivery_charge') }}</span>
                <span>{{ formatAmount(courierEstimate.deliveryMin) }}–{{ formatAmount(courierEstimate.deliveryMax) }}</span>
              </div>
              <div v-if="codEstimateSummary" class="row justify-between text-caption text-grey-7">
                <span>{{ $t('shop.cod_fee') }}</span>
                <span>{{ codEstimateSummary }}</span>
              </div>
              <div class="text-caption text-grey-6 q-mt-sm">
                {{ $t('shop.courier_charges_may_vary') }}
              </div>
            </div>
          </q-expansion-item>
        </template>
        <template v-else-if="canSeeSellPrice">
          <div class="row justify-between q-mb-sm text-body2 text-grey-7">
            <span>{{ $t('shop.subtotal') }} ({{ itemCount }} {{ $t('shop.items').toLowerCase() }})</span>
            <span class="text-weight-medium">
              {{ formatCartTotal() }}
            </span>
          </div>
        </template>
        <template v-else-if="canSeeBuyPrice">
          <div class="row justify-between q-mb-sm text-body2 text-grey-7">
            <span>{{ $t('shop.subtotal') }} ({{ itemCount }} {{ $t('shop.items').toLowerCase() }})</span>
            <span class="text-weight-medium">
              {{ formatCartTotal() }}
            </span>
          </div>
        </template>

        <q-separator class="q-my-md" />

        <div v-if="canSeeSellPrice || canSeeBuyPrice" class="row justify-between items-baseline q-mb-lg">
          <span class="text-subtitle1 text-weight-bold text-grey-9">{{
            cart?.shop_type === 'dropship' ? $t('shop.recipient_pay_total') : $t('shop.estimated_total')
          }}</span>
          <span class="text-h6 text-weight-bold text-primary">
            {{ cart?.shop_type === 'dropship' ? formatAmount(recipientGrandTotal) : formatCartTotal() }}
          </span>
        </div>
      </template>

      <span class="full-width block">
        <q-btn
          color="primary"
          unelevated
          no-caps
          class="full-width"
          :label="$t(checkoutLabelKey)"
          :loading="isSaving || placingOrder"
          :disable="checkoutDisabled"
          @click="$emit('handle-button-click')"
        />
        <q-tooltip v-if="checkoutDisabled && checkoutDisabledReason">
          {{ $t(checkoutDisabledReason) }}
        </q-tooltip>
      </span>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
defineProps<{
  cart: any;
  canSeeBuyPrice: boolean;
  canSeeSellPrice: boolean;
  itemCount: number;
  formatCartTotal: () => string;
  formatAmount: (val: any) => string;
  printCharge: number;
  packingCharge: number;
  defaultPackingCharge: number;
  courierEstimate: {
    deliveryMin: number;
    deliveryMax: number;
    codPercentMin: number | null;
    codPercentMax: number | null;
    codFlatMin: number | null;
    codFlatMax: number | null;
  };
  codEstimateSummary: string;
  buyerTotal: number;
  estimatedProfit: number;
  recipientGrandTotal: number;
  isSaving: boolean;
  placingOrder: boolean;
  checkoutDisabled: boolean;
  checkoutDisabledReason: string;
  checkoutLabelKey: string;
}>();

defineEmits<{
  (e: 'handle-button-click'): void;
}>();
</script>

<style scoped>
.summary-card {
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

@media (max-width: 599px) {
  .summary-card {
    border-radius: 8px;
  }
}
</style>
