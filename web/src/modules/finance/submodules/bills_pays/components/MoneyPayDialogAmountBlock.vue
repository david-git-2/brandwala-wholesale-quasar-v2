<template>
  <div class="money-pay-dialog-amount">
    <label class="money-pay-dialog-amount__label" for="money-pay-amount-input">
      {{ amountLabel }}
    </label>
    <div class="money-pay-dialog-amount__wrap">
      <q-input
        id="money-pay-amount-input"
        :model-value="amount"
        outlined
        type="number"
        step="0.01"
        min="0"
        hide-bottom-space
        data-test="money-pay-amount"
        class="money-pay-dialog-amount__input"
        @update:model-value="onAmount"
        @blur="emit('blur')"
      />
    </div>
    <div
      v-if="errorMessage"
      class="money-pay-dialog-amount__error"
      role="alert"
    >
      {{ errorMessage }}
    </div>
    <div v-if="amountInWords" class="money-pay-dialog-amount__words" aria-live="polite">
      {{ amountInWords }}
    </div>
    <div v-if="booksPreviewLabel" class="money-pay-dialog-amount__meta">
      {{ booksPreviewLabel }}
    </div>
    <div v-if="unallocatedHint" class="money-pay-dialog-amount__meta">
      {{ unallocatedHint }}
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { formatAmountInWords } from 'src/utils/amountInWords';
import { formatAmountBdt } from 'src/utils/currency';

const props = defineProps<{
  amount: number | null;
  currencyCode?: string | null;
  /** Maximum allowed (e.g. bill due). */
  maxAmount?: number | null;
  booksPreviewLabel?: string | null;
  unallocatedAmount?: number | null;
  showError?: boolean;
}>();

const emit = defineEmits<{
  'update:amount': [value: number | null];
  blur: [];
}>();

const currencyCode = computed(() => (props.currencyCode ?? 'BDT').trim() || 'BDT');

const amountLabel = computed(() => `Payment amount (${currencyCode.value})`);

const amountInWords = computed(() => {
  const pay = Number(props.amount);
  if (!Number.isFinite(pay) || pay <= 0) return null;
  return formatAmountInWords(pay, currencyCode.value);
});

const unallocatedHint = computed(() => {
  const u = props.unallocatedAmount;
  if (u == null || u <= 0.009) return null;
  return `${formatAmountBdt(u)} unallocated on this payment`;
});

const amountCap = computed(() => {
  const cap = props.maxAmount;
  return cap != null && cap > 0 ? cap : null;
});

const amountOverCap = computed(() => {
  const pay = Number(props.amount);
  const cap = amountCap.value;
  if (cap == null || !Number.isFinite(pay) || pay <= 0) return false;
  return pay > cap + 0.009;
});

const amountInvalid = computed(() => {
  const pay = Number(props.amount);
  return !Number.isFinite(pay) || pay <= 0;
});

const errorMessage = computed(() => {
  if (amountOverCap.value) return 'Cannot pay more than bill due.';
  if (!props.showError || !amountInvalid.value) return null;
  return 'Enter an amount greater than zero';
});

const onAmount = (raw: string | number | null) => {
  if (raw === '' || raw == null) {
    emit('update:amount', null);
    return;
  }
  const n = Number(raw);
  emit('update:amount', Number.isFinite(n) ? n : null);
};
</script>

<style scoped lang="scss">
.money-pay-dialog-amount__label {
  display: block;
  margin-bottom: 6px;
  font-size: 12px;
  font-weight: 600;
  color: var(--tf-neutral-chrome-text, #5b6b80);
  letter-spacing: 0.02em;
}

.money-pay-dialog-amount__wrap {
  position: relative;
}

.money-pay-dialog-amount__input {
  :deep(.q-field__control) {
    min-height: 52px;
    border-radius: var(--tf-radius-sm, 8px);
  }

  :deep(input) {
    font-size: 1.35rem;
    font-weight: 600;
    color: var(--tf-neutral-ink, #0f172a);
    font-variant-numeric: tabular-nums;
  }

}

.money-pay-dialog-amount__error {
  margin-top: 6px;
  font-size: 12px;
  color: var(--tf-danger, #b91c1c);
}

.money-pay-dialog-amount__words {
  margin-top: 8px;
  padding: 8px 10px;
  font-size: 13px;
  line-height: 1.45;
  color: var(--tf-neutral-ink, #334155);
  background: var(--tf-neutral-canvas, #f8fafc);
  border: 1px solid var(--tf-neutral-border, #e2e8f0);
  border-radius: var(--tf-radius-sm, 8px);
}

.money-pay-dialog-amount__meta {
  display: block;
  margin-top: 8px;
  font-size: 12px;
  color: var(--tf-neutral-muted, #475569);
}
</style>
