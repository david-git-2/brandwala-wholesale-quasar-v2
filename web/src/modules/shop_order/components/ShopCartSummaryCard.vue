<template>
  <q-card flat bordered class="floating-surface sticky-card">
    <q-card-section class="q-px-md q-py-sm">
      <div class="text-subtitle2 text-weight-bold">
        {{ $t('shop.order_summary') }}
      </div>
    </q-card-section>

    <q-separator />

    <q-card-section class="q-py-md">
      <template
        v-if="cart?.shop_type === 'dropship' ? (canSeeBuyPrice || canSeeSellPrice) : canSeeLinePrices"
      >
        <template v-if="cart?.shop_type === 'dropship'">
          <div v-if="canSeeSellPrice" class="row justify-between q-mb-sm bw-type-body bw-text-muted">
            <span>{{ $t('shop.items_subtotal') }}</span>
            <span class="text-weight-medium bw-tabular">
              {{ formatCartTotal() }}
            </span>
          </div>

          <div v-if="canSeeBuyPrice" class="row justify-between q-mb-sm bw-type-body bw-text-muted">
            <span>{{ $t('shop.your_cost_buyer') }}</span>
            <span class="text-weight-medium bw-tabular">
              {{ formatAmount(buyerTotal) }}
            </span>
          </div>

          <div
            v-if="canSeeBuyPrice && canSeeSellPrice"
            class="column q-mb-sm q-pa-sm rounded-borders profit-panel"
          >
            <div class="row justify-between items-center bw-type-body">
              <span class="text-weight-bold text-positive row items-center q-gutter-x-xs">
                <q-icon name="ph ph-trend-up" size="16px" />
                <span>{{ $t('shop.estimated_profit') }}</span>
              </span>
              <span class="text-weight-bold text-positive text-subtitle1 bw-tabular">
                {{ formatAmount(estimatedProfit) }}
              </span>
            </div>
            <div class="bw-type-meta bw-text-muted q-mt-xs">
              {{ $t('shop.charges_finalized_checkout') }}
            </div>
          </div>

          <q-expansion-item
            dense
            :label="$t('shop.estimated_charges')"
            header-class="bw-type-meta bw-text-muted"
            class="q-mb-sm"
          >
            <div class="column q-pa-sm rounded-borders stat-card">
              <div v-if="printCharge > 0" class="row justify-between bw-type-meta bw-text-muted q-mb-xs">
                <span>{{ $t('shop.print_charge') }}</span>
                <span class="bw-tabular">{{ formatAmount(printCharge) }}</span>
              </div>
              <div v-if="packingCharge > 0" class="row justify-between bw-type-meta bw-text-muted q-mb-xs">
                <span>
                  {{ $t('shop.packing_charge') }}
                  <span v-if="defaultPackingCharge > 0 && itemCount > 0" class="bw-text-muted">
                    ({{ formatAmount(defaultPackingCharge) }} &times; {{ itemCount }})
                  </span>
                </span>
                <span class="bw-tabular">{{ formatAmount(packingCharge) }}</span>
              </div>
              <div class="row justify-between bw-type-meta bw-text-muted q-mb-xs">
                <span>{{ $t('shop.delivery_charge') }}</span>
                <span class="bw-tabular">
                  {{ formatAmount(courierEstimate.deliveryMin) }}–{{ formatAmount(courierEstimate.deliveryMax) }}
                </span>
              </div>
              <div v-if="codEstimateSummary" class="row justify-between bw-type-meta bw-text-muted">
                <span>{{ $t('shop.cod_fee') }}</span>
                <span>{{ codEstimateSummary }}</span>
              </div>
              <div class="bw-type-meta bw-text-muted q-mt-sm">
                {{ $t('shop.courier_charges_may_vary') }}
              </div>
            </div>
          </q-expansion-item>
        </template>
        <template v-else-if="canSeeLinePrices">
          <div class="row justify-between q-mb-sm bw-type-body bw-text-muted">
            <span>{{ $t('shop.subtotal') }} ({{ itemCount }} {{ $t('shop.items').toLowerCase() }})</span>
            <span class="text-weight-medium bw-tabular">
              {{ formatCartTotal() }}
            </span>
          </div>
        </template>

        <q-separator class="q-my-md" />

        <div v-if="canSeeLinePrices" class="row justify-between items-baseline q-mb-lg">
          <span class="text-subtitle1 text-weight-bold">
            {{
              cart?.shop_type === 'dropship' ? $t('shop.recipient_pay_total') : $t('shop.estimated_total')
            }}
          </span>
          <span class="bw-type-kpi text-primary bw-tabular">
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
          data-test="shop-cart-checkout"
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
  canSeeLinePrices: boolean;
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
.sticky-card {
  position: sticky;
  top: 24px;
}

.profit-panel {
  background: var(--bw-success-soft);
  border: 1px solid var(--bw-theme-border);
}
</style>
