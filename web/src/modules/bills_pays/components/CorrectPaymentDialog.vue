<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="emit('update:modelValue', $event)">
    <q-card flat bordered class="correct-payment-dialog" style="min-width: min(440px, 92vw)">
      <q-card-section class="text-weight-bold q-pb-sm">Correct payment</q-card-section>

      <div class="correct-payment-dialog__banner">
        <q-icon name="ph ph-warning" size="20px" class="correct-payment-dialog__banner-icon" />
        <div class="correct-payment-dialog__banner-text">
          <p class="q-mb-xs">
            Posted payments cannot be edited. This will
            <strong>void pay #{{ pay?.id }}</strong>, put the amount back on this bill’s due, then
            open the payment form so you can post again with the right amount or exchange rate.
          </p>
          <p class="q-mb-none correct-payment-dialog__banner-sub">
            The bill stays issued — only settlement is reversed and re-recorded.
          </p>
        </div>
      </div>

      <q-card-section class="q-pt-sm text-body2">
        <p v-if="pay && pay.instruments.length > 1" class="q-mb-sm correct-payment-dialog__note">
          Split tender: correction voids the whole pay. To reverse one cheque only, use
          <strong>Mark bounced</strong> on the payment page.
        </p>
        <div v-if="pay" class="correct-payment-dialog__current q-mb-sm">
          <span class="text-caption text-weight-medium">Current pay</span>
          <div class="tf-num">{{ summaryLine }}</div>
        </div>
        <q-input
          v-model="reason"
          outlined
          dense
          type="textarea"
          autogrow
          label="Reason (required)"
          hide-bottom-space
        />
      </q-card-section>
      <q-card-actions align="right" class="q-px-md q-pb-sm">
        <TfBtn variant="tertiary" label="Cancel" @click="onCancel" />
        <TfBtn
          variant="danger"
          label="Void and re-enter payment"
          :loading="loading"
          :disable="!reason.trim()"
          @click="onConfirm"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import TfBtn from 'src/components/ui/TfBtn.vue';
import type { PayDetail } from '../repositories/paysRepository';
import { formatBdtTaka, formatSettlementCurrencyAmount } from 'src/utils/currency';

const props = defineProps<{
  modelValue: boolean;
  pay: PayDetail | null;
  loading?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  confirm: [reason: string];
  cancel: [];
}>();

const reason = ref('');

watch(
  () => props.modelValue,
  (open) => {
    if (open) reason.value = '';
  },
);

const summaryLine = computed(() => {
  const p = props.pay;
  if (!p) return '';
  const code = (p.settlement_currency_code ?? 'BDT').toUpperCase();
  if (code !== 'BDT' && p.foreign_amount != null) {
    return `${formatSettlementCurrencyAmount(p.foreign_amount, code)} @ ${p.exchange_rate} BDT/${code} (${formatBdtTaka(p.amount)})`;
  }
  return formatBdtTaka(p.amount);
});

const onCancel = () => {
  emit('cancel');
  emit('update:modelValue', false);
};

const onConfirm = () => {
  emit('confirm', reason.value.trim());
};
</script>

<style scoped lang="scss">
.correct-payment-dialog__banner {
  display: flex;
  gap: 10px;
  margin: 0 16px 4px;
  padding: 10px 12px;
  background: var(--tf-attention-soft);
  border: 1px solid var(--tf-neutral-border);
  border-radius: var(--tf-radius-sm, 8px);
  color: var(--tf-neutral-ink);
  font-size: 13px;
  line-height: 1.45;
}

.correct-payment-dialog__banner-icon {
  flex-shrink: 0;
  margin-top: 2px;
  color: var(--tf-status-attention, #b45309);
}

.correct-payment-dialog__banner-sub {
  font-size: 12px;
  color: var(--tf-neutral-muted);
}

.correct-payment-dialog__note {
  font-size: 13px;
  color: var(--tf-neutral-muted);
}

.correct-payment-dialog__current {
  padding: 8px 10px;
  background: var(--tf-neutral-canvas);
  border: 1px solid var(--tf-neutral-border);
  border-radius: var(--tf-radius-sm, 8px);
}
</style>
