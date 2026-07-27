<template>
  <q-card flat bordered class="summary-card sticky-card">
    <q-card-section class="q-px-md q-py-sm border-bottom">
      <div class="text-subtitle2 text-weight-bold text-grey-9">
        {{ $t('shop.order_summary') }}
      </div>
    </q-card-section>

    <q-card-section class="q-py-md">
      <template v-if="cart?.see_price_snapshot || cart?.shop_type === 'dropship'">
        <template v-if="cart?.shop_type === 'dropship'">
          <!-- Recipient Subtotal -->
          <div class="row justify-between q-mb-sm text-body2 text-grey-7">
            <span>{{ $t('shop.items_subtotal') }}</span>
            <span class="text-weight-medium text-grey-9">
              {{ formatCartTotal() }}
            </span>
          </div>

          <!-- Charges Section -->
          <div class="column q-mt-sm q-mb-sm bg-grey-1 q-pa-sm rounded-borders" style="border: 1px solid rgba(0,0,0,0.05); border-radius: 8px;">
            <div class="text-caption text-weight-bold text-grey-7 q-mb-xs row items-center justify-between">
              <span>{{ $t('shop.dropship_charges') }}</span>
              <span class="text-caption text-grey-6" style="font-size: 10px;">(Approximate)</span>
            </div>

            <div class="row justify-between text-caption text-grey-7 q-mb-xs">
              <span>{{ $t('shop.delivery_charge') }}</span>
              <span>{{ formatAmount(0) }}</span>
            </div>

            <div class="row justify-between text-caption text-grey-7 q-mb-xs">
              <span>{{ $t('shop.cod_fee') }}</span>
              <span>{{ formatAmount(0) }}</span>
            </div>

            <div class="row justify-between text-caption text-grey-7 q-mb-xs">
              <span>
                {{ $t('shop.print_charge') }}
                <span class="text-grey-5">({{ deductPrintFromMargin ? 'deducted' : 'customer pays' }})</span>
              </span>
              <span>{{ formatAmount(printCharge) }}</span>
            </div>

            <div class="row justify-between text-caption text-grey-7">
              <span>
                {{ $t('shop.packing_charge') }}
                <span v-if="defaultPackingCharge > 0 && itemCount > 0" class="text-grey-6">
                  ({{ formatAmount(defaultPackingCharge) }} &times; {{ itemCount }})
                </span>
                <span class="text-grey-5">({{ deductPackingFromMargin ? 'deducted' : 'customer pays' }})</span>
              </span>
              <span>{{ formatAmount(packingCharge) }}</span>
            </div>

            <div class="delivery-notice-banner q-pa-sm q-mt-sm rounded-borders bg-amber-1 border-amber text-grey-10 shadow-1 flex flex-column gap-xs">
              <div class="flex items-center text-weight-bold text-caption text-amber-10">
                <q-icon name="ph ph-truck text-weight-bold" size="16px" class="q-mr-xs text-amber-9" />
                <span>Courier &amp; Delivery Notice (Approximate)</span>
              </div>
              <div class="text-caption text-grey-9">
                {{ $t('shop.courier_charges_may_vary') }}
              </div>
              <div class="column gap-xs q-mt-xs text-caption">
                <div class="flex items-center justify-between bg-white q-pa-xs rounded-borders">
                  <span class="text-grey-8">Estimated delivery:</span>
                  <strong class="text-primary text-weight-bold">{{ $t('shop.courier_delivery_estimate', { min: formatAmount(courierEstimate.deliveryMin), max: formatAmount(courierEstimate.deliveryMax) }) }}</strong>
                </div>
                <div v-if="codEstimateSummary" class="flex items-center justify-between bg-white q-pa-xs rounded-borders">
                  <span class="text-grey-8">Estimated COD fee:</span>
                  <strong class="text-indigo-9 text-weight-bold">{{ $t('shop.courier_cod_estimate', { summary: codEstimateSummary }) }}</strong>
                </div>
              </div>
            </div>

            <!-- Sum of Deductible Charges -->
            <div class="row justify-between text-caption text-grey-9 q-mt-sm q-pt-xs border-top text-weight-bold" style="font-size: 11px;">
              <span>Total Est. Charges &amp; Deductions:</span>
              <span class="text-negative">{{ formatAmount(totalDeductibleCharges) }}</span>
            </div>
          </div>

          <!-- Buyer Cost -->
          <div class="row justify-between q-mb-sm text-body2 text-grey-7">
            <span>{{ $t('shop.your_cost_buyer') }}</span>
            <span class="text-weight-medium text-grey-9">
              {{ formatAmount(buyerTotal) }}
            </span>
          </div>

          <!-- Profit with Explicit Approximate Disclaimer & Sum of Deductions -->
          <div class="column q-mb-sm bg-green-1 q-pa-sm rounded-borders" style="border: 1px dashed rgba(76, 175, 80, 0.4); border-radius: 8px;">
            <div class="row justify-between items-center text-body2">
              <span class="text-weight-bold text-positive row items-center q-gutter-x-xs">
                <q-icon name="ph ph-trend-up" size="16px" />
                <span>{{ $t('shop.estimated_profit') }}</span>
                <span class="text-caption text-weight-normal text-grey-7">(Approximate)</span>
              </span>
              <span class="text-weight-bold text-positive text-subtitle1">
                {{ formatAmount(estimatedProfit) }}
              </span>
            </div>
            <div class="text-caption text-grey-8 q-mt-xs" style="font-size: 11px; line-height: 1.3;">
              <q-icon name="ph ph-info" size="12px" color="positive" class="q-mr-xs" />
              Profit is approximate. Delivery &amp; COD fees are estimated and finalized at checkout.
            </div>
            <div class="row justify-between text-caption text-grey-8 q-mt-xs q-pt-xs border-top" style="font-size: 11px;">
              <span>Est. Deductions (Print/Packing/Delivery):</span>
              <span class="text-weight-bold text-negative">-{{ formatAmount(totalDeductibleCharges) }}</span>
            </div>
          </div>
        </template>
        <template v-else>
          <div class="row justify-between q-mb-sm text-body2 text-grey-7">
            <span>{{ $t('shop.subtotal') }} ({{ itemCount }} {{ $t('shop.items').toLowerCase() }})</span>
            <span class="text-weight-medium">
              {{ formatCartTotal() }}
            </span>
          </div>
        </template>

        <q-separator class="q-my-md" />

        <div class="row justify-between items-baseline q-mb-lg">
          <span class="text-subtitle1 text-weight-bold text-grey-9">{{
            cart?.shop_type === 'dropship' ? $t('shop.recipient_pay_total') : $t('shop.estimated_total')
          }}</span>
          <span class="text-h6 text-weight-bold text-primary">
            {{ cart?.shop_type === 'dropship' ? formatAmount(recipientGrandTotal) : formatCartTotal() }}
          </span>
        </div>
      </template>

      <q-btn
        color="primary"
        unelevated
        no-caps
        class="full-width"
        label="Proceed to Checkout"
        :loading="isSaving || placingOrder"
        @click="$emit('handle-button-click')"
      />
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
defineProps<{
  cart: any;
  itemCount: number;
  formatCartTotal: () => string;
  formatAmount: (val: any) => string;
  printCharge: number;
  packingCharge: number;
  defaultPackingCharge: number;
  deductPrintFromMargin: boolean;
  deductPackingFromMargin: boolean;
  courierEstimate: {
    deliveryMin: number;
    deliveryMax: number;
    codPercentMin: number | null;
    codPercentMax: number | null;
    codFlatMin: number | null;
    codFlatMax: number | null;
  };
  codEstimateSummary: string;
  totalDeductibleCharges: number;
  buyerTotal: number;
  estimatedProfit: number;
  recipientGrandTotal: number;
  isSaving: boolean;
  placingOrder: boolean;
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
