<script setup lang="ts">
import { computed } from 'vue';
import type { ShopOrder } from '../types';
import DropshipSettlementBadge from './DropshipSettlementBadge.vue';

const props = withDefaults(
  defineProps<{
    order: ShopOrder | null;
    form: {
      deduct_delivery_from_margin: boolean;
      deduct_cod_from_margin: boolean;
      deduct_print_from_margin: boolean;
      deduct_packing_from_margin: boolean;
    };
    recipientSubtotal: number;
    accountingSubtotal: number;
    deliveryChargeVal: number;
    codChargeVal: number;
    printChargeVal: number;
    packingChargeVal: number;
    discountVal: number;
    recipientGrandTotal: number;
    middlemanTotalCost: number;
    estimatedProfit: number;
    b2bInvoiceTotal?: number;
    showSettlementCard: boolean;
    tenantSlug: string | null;
    formatBdt: (amount: number) => string;
    readonly?: boolean;
  }>(),
  {
    readonly: false,
    b2bInvoiceTotal: undefined,
  },
);

const b2bInvoiceDisplay = computed(
  () =>
    props.b2bInvoiceTotal ??
    props.accountingSubtotal + props.printChargeVal + props.packingChargeVal - props.discountVal,
);

const emit = defineEmits<{
  (e: 'toggle-deduct'): void;
  (e: 'update:form-field', key: string, val: any): void;
}>();

const updateField = (key: string, val: any) => {
  emit('update:form-field', key, val);
  emit('toggle-deduct');
};
</script>

<template>
  <div class="q-gutter-y-md">
    <q-card flat bordered class="form-card">
      <q-card-section class="border-bottom">
        <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center">
          <q-icon name="ph ph-wallet" size="18px" class="q-mr-xs text-primary" />
          Totals &amp; Profit Breakdown
        </div>
      </q-card-section>
      <q-card-section class="q-gutter-y-xs text-body2">
        <div class="row justify-between text-grey-7 q-py-xs">
          <span>Face Items Subtotal</span>
          <span>{{ formatBdt(recipientSubtotal) }}</span>
        </div>

        <div v-if="deliveryChargeVal > 0" class="q-py-xs" style="border-bottom: 1px dashed #e0e0e0">
          <div class="row justify-between text-grey-7 items-center">
            <span>Delivery Charge</span>
            <span>{{ formatBdt(deliveryChargeVal) }}</span>
          </div>
          <div class="row justify-end q-mt-xs">
            <q-toggle
              :model-value="props.form.deduct_delivery_from_margin"
              label="Deduct from Profit"
              dense
              size="xs"
              class="text-caption text-grey-6"
              :disable="props.readonly"
              @update:model-value="(val) => updateField('deduct_delivery_from_margin', val)"
            />
          </div>
        </div>

        <div v-if="codChargeVal > 0" class="q-py-xs" style="border-bottom: 1px dashed #e0e0e0">
          <div class="row justify-between text-grey-7 items-center">
            <span>COD Fee</span>
            <span>{{ formatBdt(codChargeVal) }}</span>
          </div>
          <div class="row justify-end q-mt-xs">
            <q-toggle
              :model-value="props.form.deduct_cod_from_margin"
              label="Deduct from Profit"
              dense
              size="xs"
              class="text-caption text-grey-6"
              :disable="props.readonly"
              @update:model-value="(val) => updateField('deduct_cod_from_margin', val)"
            />
          </div>
        </div>

        <div v-if="printChargeVal > 0" class="q-py-xs" style="border-bottom: 1px dashed #e0e0e0">
          <div class="row justify-between text-grey-7 items-center">
            <span>Print Charge</span>
            <span>{{ formatBdt(printChargeVal) }}</span>
          </div>
          <div class="row justify-end q-mt-xs">
            <q-toggle
              :model-value="props.form.deduct_print_from_margin"
              label="Deduct from Profit"
              dense
              size="xs"
              class="text-caption text-grey-6"
              :disable="props.readonly"
              @update:model-value="(val) => updateField('deduct_print_from_margin', val)"
            />
          </div>
        </div>

        <div v-if="packingChargeVal > 0" class="q-py-xs" style="border-bottom: 1px dashed #e0e0e0">
          <div class="row justify-between text-grey-7 items-center">
            <span>Packing Charge</span>
            <span>{{ formatBdt(packingChargeVal) }}</span>
          </div>
          <div class="row justify-end q-mt-xs">
            <q-toggle
              :model-value="props.form.deduct_packing_from_margin"
              label="Deduct from Profit"
              dense
              size="xs"
              class="text-caption text-grey-6"
              :disable="props.readonly"
              @update:model-value="(val) => updateField('deduct_packing_from_margin', val)"
            />
          </div>
        </div>

        <div v-if="discountVal > 0" class="row justify-between text-negative q-py-xs">
          <span>Discount</span>
          <span>-{{ formatBdt(discountVal) }}</span>
        </div>
        <q-separator class="q-my-sm" />
        <div class="row justify-between items-baseline">
          <span class="text-subtitle2 text-weight-bold text-grey-9">Recipient Pay Total</span>
          <span class="text-h6 text-weight-bold text-primary">{{ formatBdt(recipientGrandTotal) }}</span>
        </div>
        <q-separator class="q-my-sm" />
        <div class="row justify-between text-body2 text-weight-medium text-grey-9">
          <span>B2B / Wallet Invoice</span>
          <span>{{ formatBdt(b2bInvoiceDisplay) }}</span>
        </div>
        <div class="text-caption text-grey-6 q-mb-xs">
          Wholesale + print + packing (posted to billing-profile AR &amp; tenant revenue). Excludes courier fees.
        </div>
        <div class="row justify-between text-caption text-grey-6">
          <span>Middle-Man Cost (profit basis)</span>
          <span>{{ formatBdt(middlemanTotalCost) }}</span>
        </div>
        <div class="text-caption text-grey-6 q-mb-xs">
          Includes courier fees deducted from margin — affects profit only, not B2B AR.
        </div>
        <div class="row justify-between text-body2 text-weight-bold" :class="estimatedProfit >= 0 ? 'text-positive' : 'text-negative'">
          <span>Estimated Profit</span>
          <span>{{ formatBdt(estimatedProfit) }}</span>
        </div>
        <q-btn
          v-if="order && tenantSlug"
          outline
          color="primary"
          icon="ph ph-arrow-up-right"
          label="View Order"
          no-caps
          class="full-width q-mt-md"
          :to="{ name: 'app-shop-order-detail-page', params: { tenantSlug, id: order.id } }"
        />
      </q-card-section>
    </q-card>

    <!-- Settlement Card -->
    <q-card
      v-if="showSettlementCard"
      flat
      bordered
      class="form-card"
    >
      <q-card-section class="border-bottom">
        <div class="text-subtitle2 text-weight-bold text-grey-9 row items-center">
          <q-icon name="ph ph-money" size="18px" class="q-mr-xs text-primary" />
          Settlement
        </div>
      </q-card-section>
      <q-card-section class="q-gutter-y-sm">
        <div class="row items-center justify-between text-caption text-grey-7">
          <span>Status:</span>
          <DropshipSettlementBadge :status="order?.payout_settlement_status || 'unpaid'" />
        </div>
        <div v-if="order?.courier_remittance_ref" class="text-body2">
          <div class="text-caption text-grey-7">Remittance Ref</div>
          <div class="text-weight-medium">{{ order.courier_remittance_ref }}</div>
        </div>
        <div v-if="order?.courier_bank_trx_id" class="text-body2">
          <div class="text-caption text-grey-7">Bank / MFS Trx</div>
          <div class="text-weight-medium">{{ order.courier_bank_trx_id }}</div>
        </div>
        <div v-if="order?.cod_collect_amount" class="text-body2">
          <div class="text-caption text-grey-7">COD Collection Target</div>
          <div class="text-weight-medium">{{ formatBdt(order.cod_collect_amount) }}</div>
        </div>

        <div class="text-caption text-blue-9 bg-blue-1 q-pa-sm rounded-borders border-all-1">
          <q-icon name="ph ph-info" class="q-mr-xs" />
          Profit for this dropship order is processed and tracked through the <strong>Dropship Finance Hub</strong>.
        </div>

        <q-btn
          v-if="tenantSlug"
          outline
          color="primary"
          no-caps
          class="full-width pill-btn q-mt-sm"
          icon="ph ph-bank"
          label="Open Dropship Finance Hub"
          :to="{ name: 'app-shop-dropship-finance-hub-page', params: { tenantSlug }, query: order ? { orderId: order.id } : undefined }"
        />
      </q-card-section>
    </q-card>
  </div>
</template>
