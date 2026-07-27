<template>
  <q-card flat bordered class="details-card">
    <q-card-section class="q-px-lg q-py-md border-bottom">
      <div class="text-subtitle1 text-weight-bold text-grey-9">{{ $t('shop_admin.order_summary') }}</div>
    </q-card-section>

    <q-card-section class="q-px-lg q-py-md q-gutter-y-sm">
      <div class="row justify-between">
        <span class="text-grey-6">{{ $t('shop_admin.order_no') }}</span>
        <span class="text-weight-bold text-grey-8">{{ order.order_no }}</span>
      </div>
      <div class="row justify-between">
        <span class="text-grey-6">{{ $t('shop_admin.date') }}</span>
        <span class="text-grey-8">{{ formatDate(order.created_at) }}</span>
      </div>
      <div class="row justify-between">
        <span class="text-grey-6">{{ $t('shop_admin.shop_type_label') }}</span>
        <span class="text-grey-8 text-capitalize">{{ order.shop_type_snapshot }}</span>
      </div>
      <div class="row justify-between" v-if="order.shop_type_snapshot === 'dropship'">
        <span class="text-grey-6">{{ $t('shop_admin.payment_mode') }}</span>
        <q-badge
          :color="order.is_prepaid_snapshot ? 'positive' : 'warning'"
          text-color="white"
          class="q-py-xs q-px-sm"
        >
          {{
            order.is_prepaid_snapshot
              ? $t('shop_admin.payment_prepaid')
              : $t('shop_admin.payment_cod')
          }}
        </q-badge>
      </div>
      <div
        class="row justify-between items-center q-mt-xs"
        v-if="order.shop_type_snapshot === 'dropship' && order.tracking_url"
      >
        <span class="text-grey-6">Courier Tracking</span>
        <q-btn
          flat
          dense
          no-caps
          size="sm"
          color="primary"
          icon="ph ph-arrow-up-right"
          label="Track Parcel"
          type="a"
          :href="order.tracking_url"
          target="_blank"
          rel="noopener noreferrer"
        />
      </div>
      <div
        class="row justify-between"
        v-if="order.shop_type_snapshot !== 'dropship'"
      >
        <span class="text-grey-6">{{ $t('shop_admin.order_mode_label') }}</span>
        <span class="text-grey-8 text-capitalize">{{ order.order_mode_snapshot }}</span>
      </div>

      <q-separator class="q-my-sm" />

      <!-- Dropship detailed receipt footer -->
      <template v-if="order.shop_type_snapshot === 'dropship'">
        <div class="row justify-between text-body2 text-grey-7">
          <span>{{ $t('shop.items_subtotal') }}</span>
          <span>{{ currencySymbol }}{{ recipientSubtotal.toFixed(2) }}</span>
        </div>
        
        <div class="row justify-between text-body2 text-grey-7" v-if="deliveryChargeVal > 0">
          <span>
            {{ $t('shop.delivery_charge') }}
            <span class="text-grey-5">({{ deductDeliveryFromMargin ? 'deducted from profit' : 'customer pays' }})</span>
          </span>
          <span>{{ currencySymbol }}{{ deliveryChargeVal.toFixed(2) }}</span>
        </div>
        
        <div class="row justify-between text-body2 text-grey-7" v-if="codChargeVal > 0">
          <span>
            {{ $t('shop.cod_fee', { pct: codFeePctLabel }) }}
            <span class="text-grey-5">({{ deductCodFromMargin ? 'deducted from profit' : 'customer pays' }})</span>
          </span>
          <span>{{ currencySymbol }}{{ codChargeVal.toFixed(2) }}</span>
        </div>
        
        <div class="row justify-between text-body2 text-grey-7" v-if="printChargeVal > 0">
          <span>
            {{ $t('shop.print_charge') }}
            <span class="text-grey-5">(deducted from profit)</span>
          </span>
          <span>{{ currencySymbol }}{{ printChargeVal.toFixed(2) }}</span>
        </div>
        
        <div class="row justify-between text-body2 text-grey-7" v-if="packingChargeVal > 0">
          <span>
            {{ $t('shop.packing_charge') }}
            <span class="text-grey-5">(deducted from profit)</span>
          </span>
          <span>{{ currencySymbol }}{{ packingChargeVal.toFixed(2) }}</span>
        </div>

        <div class="row justify-between text-body2 text-negative" v-if="discountVal > 0">
          <span>{{ $t('shop_admin.discount') }}</span>
          <span>-{{ currencySymbol }}{{ discountVal.toFixed(2) }}</span>
        </div>

        <q-separator class="q-my-sm" />

        <div class="row justify-between items-baseline q-mb-xs">
          <span class="text-subtitle1 text-weight-bold text-grey-9">{{ $t('shop.recipient_pay_total') }}</span>
          <span class="text-h6 text-weight-bold text-primary">
            {{ currencySymbol }}{{ recipientGrandTotal.toFixed(2) }}
          </span>
        </div>

        <div class="row justify-between text-caption text-grey-6">
          <span>{{ $t('shop_admin.your_cost_accounting') }}</span>
          <span>{{ currencySymbol }}{{ middlemanTotalCost.toFixed(2) }}</span>
        </div>

        <div class="row justify-between text-body2 text-weight-bold text-positive q-mt-xs">
          <span>{{ $t('shop_admin.your_estimated_profit') }}</span>
          <span>{{ currencySymbol }}{{ estimatedProfit.toFixed(2) }}</span>
        </div>

        <div
          v-if="isBeforePickup"
          class="q-mt-sm q-pa-sm bg-blue-1 text-primary text-caption rounded-borders row items-start"
          style="border: 1px solid rgba(25, 118, 210, 0.2);"
        >
          <q-icon name="ph ph-info" size="16px" class="q-mr-xs q-mt-xs" />
          <div>
            Accurate delivery and COD charges will be updated when the order reaches the <strong>Ready for Pickup</strong> stage.
          </div>
        </div>
      </template>
      <template v-else>
        <div class="row justify-between items-baseline">
          <span class="text-subtitle1 text-weight-bold text-grey-9">{{ $t('shop_admin.total_amount_label') }}</span>
          <span class="text-h6 text-weight-bold text-primary">
            {{ currencySymbol }}{{ orderTotal.toFixed(2) }}
          </span>
        </div>
      </template>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import { date } from 'quasar';

defineProps<{
  order: any;
  currencySymbol: string;
  recipientSubtotal: number;
  deliveryChargeVal: number;
  codChargeVal: number;
  printChargeVal: number;
  packingChargeVal: number;
  discountVal: number;
  deductDeliveryFromMargin: boolean;
  deductCodFromMargin: boolean;
  codFeePctLabel: number | string;
  recipientGrandTotal: number;
  middlemanTotalCost: number;
  estimatedProfit: number;
  isBeforePickup: boolean;
  orderTotal: number;
}>();

const formatDate = (dateStr?: string) => {
  if (!dateStr) return '';
  return date.formatDate(dateStr, 'D MMM YYYY, HH:mm');
};
</script>

<script lang="ts">
export default {
  name: 'CustomerOrderSummaryCard',
};
</script>

<style scoped>
.details-card {
  border-radius: 14px;
  background: #ffffff;
  box-shadow: 0 4px 12px rgba(34, 56, 101, 0.02);
}

.border-bottom {
  border-bottom: 1px solid rgba(34, 56, 101, 0.08);
}
</style>
