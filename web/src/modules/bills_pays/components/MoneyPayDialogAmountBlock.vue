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
        :class="{ 'money-pay-dialog-amount__input--with-action': showFillDue }"
        @update:model-value="onAmount"
        @blur="emit('blur')"
      />
      <button
        v-if="showFillDue"
        type="button"
        class="money-pay-dialog-amount__full-due"
        @click="emit('fillDue')"
      >
        Full due
      </button>
    </div>
    <div
      v-if="errorMessage"
      class="money-pay-dialog-amount__error"
      role="alert"
    >
      {{ errorMessage }}
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
import { formatAmountBdt } from 'src/utils/currency';

const props = defineProps<{
  amount: number | null;
  currencyCode?: string | null;
  dueAmount?: number | null;
  booksPreviewLabel?: string | null;
  unallocatedAmount?: number | null;
  showError?: boolean;
}>();

const emit = defineEmits<{
  'update:amount': [value: number | null];
  fillDue: [];
  blur: [];
}>();

const amountLabel = computed(() => {
  const code = (props.currencyCode ?? 'BDT').trim() || 'BDT';
  return `Payment amount (${code})`;
});

const showFillDue = computed(
  () => props.dueAmount != null && props.dueAmount > 0,
);

const unallocatedHint = computed(() => {
  const u = props.unallocatedAmount;
  if (u == null || u <= 0.009) return null;
  return `${formatAmountBdt(u)} unallocated on this payment`;
});

const amountInvalid = computed(() => {
  const pay = Number(props.amount);
  return !Number.isFinite(pay) || pay <= 0;
});

const errorMessage = computed(() => {
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

  &--with-action :deep(input) {
    padding-right: 5.5rem;
  }
}

.money-pay-dialog-amount__full-due {
  position: absolute;
  right: 14px;
  top: 50%;
  transform: translateY(-50%);
  z-index: 1;
  appearance: none;
  border: 0;
  background: transparent;
  padding: 2px 0;
  font-size: 12px;
  font-weight: 500;
  color: var(--tf-neutral-muted, #64748b);
  cursor: pointer;
  text-decoration: none;
  white-space: nowrap;

  &:hover {
    color: var(--tf-theme-primary, #0d6b5c);
    text-decoration: underline;
  }
}

.money-pay-dialog-amount__error {
  margin-top: 6px;
  font-size: 12px;
  color: var(--tf-danger, #b91c1c);
}

.money-pay-dialog-amount__meta {
  display: block;
  margin-top: 8px;
  font-size: 12px;
  color: var(--tf-neutral-muted, #475569);
}
</style>
