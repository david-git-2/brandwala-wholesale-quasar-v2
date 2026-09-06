<template>
  <q-card flat bordered class="details-card">
    <q-card-section class="q-px-md q-py-sm border-bottom">
      <div class="text-subtitle1 text-weight-bold text-grey-9">{{ $t('shop_admin.order_summary') }}</div>
    </q-card-section>

    <q-card-section class="q-px-md q-py-md q-gutter-y-sm">
      <div class="row justify-between items-center">
        <span class="text-caption text-grey-6">{{ $t('shop_admin.order_no') }}</span>
        <span class="text-body2 text-weight-medium text-grey-8">{{ order.order_no }}</span>
      </div>
      <div class="row justify-between items-center">
        <span class="text-caption text-grey-6">{{ $t('shop_admin.date') }}</span>
        <span class="text-body2 text-grey-8">{{ formatDate(order.created_at) }}</span>
      </div>

      <div v-if="order.shop_type_snapshot === 'dropship'" class="row justify-between items-center">
        <span class="text-caption text-grey-6">{{ $t('shop_admin.payment_mode') }}</span>
        <q-badge
          :color="order.is_prepaid_snapshot ? 'positive' : 'warning'"
          text-color="white"
          class="q-py-xs q-px-sm text-caption"
        >
          {{
            order.is_prepaid_snapshot
              ? $t('shop_admin.payment_prepaid')
              : $t('shop_admin.payment_cod')
          }}
        </q-badge>
      </div>

      <div
        v-if="order.shop_type_snapshot !== 'dropship'"
        class="row justify-between items-center"
      >
        <span class="text-caption text-grey-6">{{ $t('shop_admin.order_mode_label') }}</span>
        <span class="text-body2 text-grey-8 text-capitalize">{{ order.order_mode_snapshot }}</span>
      </div>

      <template v-if="order.shop_type_snapshot === 'dropship'">
        <q-separator class="q-my-sm" />

        <div class="recipient-hero row justify-between items-baseline">
          <span class="text-subtitle1 text-weight-bold text-grey-9">
            {{ $t('shop_admin.recipient_pays') }}
          </span>
          <span class="recipient-hero__amount text-h5 text-weight-bold text-primary">
            {{ currencySymbol }}{{ recipientGrandTotal.toFixed(2) }}
          </span>
        </div>

        <q-btn
          v-if="order.tracking_url"
          flat
          dense
          no-caps
          color="primary"
          icon="ph ph-arrow-up-right"
          :label="$t('shop_admin.track_parcel')"
          class="q-mt-xs q-px-none"
          type="a"
          :href="order.tracking_url"
          target="_blank"
          rel="noopener noreferrer"
        />

        <q-expansion-item
          v-model="feesExpanded"
          dense
          expand-separator
          class="fees-expansion q-mt-sm"
          :label="$t('shop_admin.fees_and_profit')"
          header-class="text-body2 text-weight-medium text-grey-8"
        >
          <div class="q-gutter-y-xs q-pb-sm">
            <div class="row justify-between text-body2 text-grey-7">
              <span>{{ $t('shop.items_subtotal') }}</span>
              <span>{{ currencySymbol }}{{ recipientSubtotal.toFixed(2) }}</span>
            </div>

            <div v-if="deliveryChargeVal > 0" class="row justify-between text-body2 text-grey-7">
              <span>{{ $t('shop.delivery_charge') }}</span>
              <span>{{ currencySymbol }}{{ deliveryChargeVal.toFixed(2) }}</span>
            </div>

            <div v-if="codChargeVal > 0" class="row justify-between text-body2 text-grey-7">
              <span>{{ $t('shop.cod_fee', { pct: codFeePctLabel }) }}</span>
              <span>{{ currencySymbol }}{{ codChargeVal.toFixed(2) }}</span>
            </div>

            <div v-if="printChargeVal > 0" class="row justify-between text-body2 text-grey-7">
              <span>{{ $t('shop.print_charge') }}</span>
              <span>{{ currencySymbol }}{{ printChargeVal.toFixed(2) }}</span>
            </div>

            <div v-if="packingChargeVal > 0" class="row justify-between text-body2 text-grey-7">
              <span>{{ $t('shop.packing_charge') }}</span>
              <span>{{ currencySymbol }}{{ packingChargeVal.toFixed(2) }}</span>
            </div>

            <div v-if="discountVal > 0" class="row justify-between text-body2 text-negative">
              <span>{{ $t('shop_admin.discount') }}</span>
              <span>-{{ currencySymbol }}{{ discountVal.toFixed(2) }}</span>
            </div>

            <q-separator class="q-my-xs" />

            <div class="row justify-between text-caption text-grey-6">
              <span>{{ $t('shop_admin.your_cost') }}</span>
              <span>{{ currencySymbol }}{{ middlemanTotalCost.toFixed(2) }}</span>
            </div>

            <div class="row justify-between text-body2 text-weight-medium text-positive">
              <span>{{ $t('shop_admin.your_profit') }}</span>
              <span>{{ currencySymbol }}{{ estimatedProfit.toFixed(2) }}</span>
            </div>
          </div>
        </q-expansion-item>

        <p
          v-if="isBeforePickup"
          class="text-caption text-grey-6 q-mb-none q-mt-sm"
        >
          {{ $t('shop_admin.charges_update_before_pickup') }}
        </p>
      </template>

      <template v-else>
        <q-separator class="q-my-sm" />
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
import { ref } from 'vue';
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
  deductPrintFromMargin?: boolean;
  deductPackingFromMargin?: boolean;
  codFeePctLabel: number | string;
  recipientGrandTotal: number;
  middlemanTotalCost: number;
  estimatedProfit: number;
  isBeforePickup: boolean;
  orderTotal: number;
}>();

const feesExpanded = ref(false);

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

.recipient-hero__amount {
  font-variant-numeric: tabular-nums;
}

.fees-expansion {
  border: 1px solid rgba(34, 56, 101, 0.08);
  border-radius: 10px;
  overflow: hidden;
}

.fees-expansion :deep(.q-item) {
  min-height: 44px;
  padding-left: 12px;
  padding-right: 8px;
}
</style>
