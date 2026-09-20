<script setup lang="ts">
import { formatAmountBdt } from 'src/utils/currency';
import type { TargetTotalSummary } from '../repositories/invoiceRepository';

const props = defineProps<{
  mode: 'composer' | 'detail';
  itemCount?: number;
  totalQuantity?: number;
  totalReturnQuantity?: number;
  subtotalAmount?: number;
  totalDiscountAmount?: number;
  totalReturnCredit?: number;
  grandTotalAmount?: number;
  overallDiscountLocked?: boolean;
  // detail-only
  originalGrossSubtotal?: number;
  totalReturnDeduction?: number;
  invoiceSubtotal?: number;
  showCharges?: boolean;
  isDropship?: boolean;
  canEditDraft?: boolean;
  invoiceIssued?: boolean;
  paidAmount?: number;
  dueAmount?: number;
  settlementDiscount?: number;
  showMargin?: boolean;
  estimatedProfit?: number;
  totalCost?: number;
  averageProfitRate?: string;
  targetTotal?: number | null;
  targetPreview?: TargetTotalSummary | null;
  targetError?: string | null;
  targetPreviewing?: boolean;
  applyingTarget?: boolean;
  chargeForm?: {
    discount_amount: number;
    shipping_charge: number;
    cod_charge_amount: number;
    wrapping_charge: number;
    print_charge: number;
  };
}>();

const overallDiscountInput = defineModel<number | null>('overallDiscountInput');

const emit = defineEmits<{
  (e: 'apply-overall-discount', val: string | number | null): void;
  (e: 'charge-blur'): void;
  (e: 'target-total-input'): void;
  (e: 'apply-target-total'): void;
  (e: 'update:target-total', value: number | null): void;
}>();

const formatMoney = (amount: number) => formatAmountBdt(amount);
</script>

<template>
  <div class="invoice-desk-card invoice-desk-totals">
    <div class="invoice-desk-section-label">Totals</div>

    <div class="invoice-desk-totals__row" v-if="mode === 'composer' && itemCount">
      <span>Total items</span>
      <span>{{ itemCount }}</span>
    </div>
    <div class="invoice-desk-totals__row" v-if="totalQuantity">
      <span>Total units</span>
      <span>{{ totalQuantity }}</span>
    </div>
    <div
      v-if="(totalReturnQuantity ?? 0) > 0"
      class="invoice-desk-totals__row"
    >
      <span>{{ mode === 'detail' ? 'Returned units' : 'Returned units' }}</span>
      <span>{{ totalReturnQuantity }}</span>
    </div>

    <template v-if="mode === 'detail' && (totalReturnQuantity ?? 0) > 0">
      <div class="invoice-desk-totals__row">
        <span>Gross subtotal</span>
        <span class="invoice-desk-money">{{ formatMoney(originalGrossSubtotal ?? 0) }}</span>
      </div>
      <div class="invoice-desk-totals__row text-purple-9">
        <span>Less returns</span>
        <span class="invoice-desk-money">-{{ formatMoney(totalReturnDeduction ?? 0) }}</span>
      </div>
    </template>

    <div class="invoice-desk-totals__row">
      <span>{{ (totalReturnQuantity ?? 0) > 0 && mode === 'detail' ? 'Net subtotal' : 'Subtotal' }}</span>
      <span class="invoice-desk-money">
        {{ formatMoney(mode === 'composer' ? (subtotalAmount ?? 0) : (invoiceSubtotal ?? 0)) }}
      </span>
    </div>

    <div
      v-if="mode === 'detail'"
      class="invoice-desk-totals__row invoice-desk-totals__row--editable"
    >
      <span>Delivery</span>
      <q-input
        v-if="canEditDraft && chargeForm"
        v-model.number="chargeForm.shipping_charge"
        type="number"
        dense
        outlined
        hide-bottom-space
        min="0"
        class="invoice-desk-amount-input"
        input-class="text-right"
        @blur="emit('charge-blur')"
      />
      <span v-else class="invoice-desk-money">{{ formatMoney(chargeForm?.shipping_charge ?? 0) }}</span>
    </div>

    <template v-if="mode === 'detail' && showCharges">
      <div
        v-if="!isDropship"
        class="invoice-desk-totals__row invoice-desk-totals__row--editable"
      >
        <span>COD charge</span>
        <q-input
          v-if="canEditDraft && chargeForm"
          v-model.number="chargeForm.cod_charge_amount"
          type="number"
          dense
          outlined
          hide-bottom-space
          min="0"
          class="invoice-desk-amount-input"
          input-class="text-right"
          @blur="emit('charge-blur')"
        />
        <span v-else class="invoice-desk-money">{{ formatMoney(chargeForm?.cod_charge_amount ?? 0) }}</span>
      </div>
      <div class="invoice-desk-totals__row invoice-desk-totals__row--editable">
        <span>Wrapping</span>
        <q-input
          v-if="canEditDraft && chargeForm"
          v-model.number="chargeForm.wrapping_charge"
          type="number"
          dense
          outlined
          hide-bottom-space
          min="0"
          class="invoice-desk-amount-input"
          input-class="text-right"
          @blur="emit('charge-blur')"
        />
        <span v-else class="invoice-desk-money">{{ formatMoney(chargeForm?.wrapping_charge ?? 0) }}</span>
      </div>
      <div class="invoice-desk-totals__row invoice-desk-totals__row--editable">
        <span>Print</span>
        <q-input
          v-if="canEditDraft && chargeForm"
          v-model.number="chargeForm.print_charge"
          type="number"
          dense
          outlined
          hide-bottom-space
          min="0"
          class="invoice-desk-amount-input"
          input-class="text-right"
          @blur="emit('charge-blur')"
        />
        <span v-else class="invoice-desk-money">{{ formatMoney(chargeForm?.print_charge ?? 0) }}</span>
      </div>
    </template>

    <div class="invoice-desk-totals__row invoice-desk-totals__row--editable">
      <span>{{ mode === 'composer' ? 'Overall discount' : 'Discount' }}</span>
      <q-input
        v-if="mode === 'composer'"
        v-model.number="overallDiscountInput"
        type="number"
        outlined
        dense
        hide-bottom-space
        min="0"
        step="0.01"
        placeholder="0.00"
        class="invoice-desk-amount-input"
        input-class="text-right"
        :disable="overallDiscountLocked"
        @update:model-value="(val) => emit('apply-overall-discount', val)"
      />
      <q-input
        v-else-if="canEditDraft && chargeForm"
        v-model.number="chargeForm.discount_amount"
        type="number"
        dense
        outlined
        hide-bottom-space
        min="0"
        class="invoice-desk-amount-input"
        input-class="text-right"
        @blur="emit('charge-blur')"
      />
      <span v-else class="text-negative invoice-desk-money">
        -{{ formatMoney(chargeForm?.discount_amount ?? 0) }}
      </span>
    </div>

    <div v-if="(totalReturnCredit ?? 0) > 0" class="invoice-desk-totals__row text-negative">
      <span>Return credit</span>
      <span class="invoice-desk-money">−{{ formatMoney(totalReturnCredit ?? 0) }}</span>
    </div>
    <div v-if="(totalDiscountAmount ?? 0) > 0 && mode === 'composer'" class="invoice-desk-totals__row text-negative">
      <span>Total discount</span>
      <span class="invoice-desk-money">−{{ formatMoney(totalDiscountAmount ?? 0) }}</span>
    </div>
    <div v-if="(settlementDiscount ?? 0) > 0" class="invoice-desk-totals__row text-orange-9">
      <span>Settlement discount</span>
      <span class="invoice-desk-money">-{{ formatMoney(settlementDiscount ?? 0) }}</span>
    </div>

    <div class="invoice-desk-totals__row invoice-desk-totals__row--grand">
      <span>Invoice total</span>
      <span class="invoice-desk-money">{{ formatMoney(grandTotalAmount ?? 0) }}</span>
    </div>

    <div v-if="invoiceIssued" class="invoice-desk-totals__row">
      <span>Paid</span>
      <span class="invoice-desk-money">{{ formatMoney(paidAmount ?? 0) }}</span>
    </div>
    <div
      v-if="invoiceIssued"
      class="invoice-desk-totals__row invoice-desk-totals__row--due"
    >
      <span>Balance due</span>
      <span class="invoice-desk-money">{{ formatMoney(dueAmount ?? 0) }}</span>
    </div>

    <template v-if="showMargin">
      <div class="invoice-desk-totals__row">
        <span>{{ invoiceIssued ? 'Gross profit' : 'Est. gross profit' }}</span>
        <span
          class="invoice-desk-money"
          :class="(estimatedProfit ?? 0) >= 0 ? 'text-positive' : 'text-negative'"
        >
          {{ formatMoney(estimatedProfit ?? 0) }}
        </span>
      </div>
      <div class="invoice-desk-totals__row text-grey-7">
        <span>Total cost · {{ totalQuantity }} qty</span>
        <span class="invoice-desk-money">
          {{ formatMoney(totalCost ?? 0) }} · {{ averageProfitRate }}
        </span>
      </div>
    </template>

    <div
      v-if="mode === 'detail' && canEditDraft && (itemCount ?? 0) > 0"
      class="invoice-desk-foot-card"
    >
      <div class="invoice-desk-section-label">Adjust to total</div>
      <div class="text-caption text-grey-7 q-mb-sm">
        Enter the final total; item prices auto-adjust to match.
      </div>
      <div class="row items-center q-gutter-sm no-wrap">
        <q-input
          :model-value="targetTotal"
          type="number"
          dense
          outlined
          class="col"
          min="0"
          placeholder="Desired total"
          :loading="targetPreviewing"
          @update:model-value="(v) => {
            emit('update:target-total', v === '' || v === null ? null : Number(v));
            emit('target-total-input');
          }"
        />
        <q-btn
          color="primary"
          no-caps
          dense
          unelevated
          label="Apply"
          :disable="!targetPreview || !!targetError || applyingTarget"
          :loading="applyingTarget"
          @click="emit('apply-target-total')"
        />
      </div>
      <div v-if="targetError" class="text-caption text-negative q-mt-xs">{{ targetError }}</div>
      <div v-else-if="targetPreview" class="q-mt-sm text-caption">
        <div class="row justify-between">
          <span>Current</span>
          <span class="invoice-desk-money">{{ formatMoney(targetPreview.current_total) }}</span>
        </div>
        <div class="row justify-between">
          <span>Target</span>
          <span class="invoice-desk-money">{{ formatMoney(targetPreview.target_total) }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped lang="scss">
@import '../styles/invoice-desk.scss';
</style>
