<template>
  <q-dialog
    :model-value="modelValue"
    persistent
    @update:model-value="onDialogUpdate"
  >
    <q-card
      flat
      bordered
      class="correct-bill-payment-flow"
      :style="step === 'payment' ? 'width: min(480px, 94vw); max-height: 92vh' : 'width: min(440px, 92vw)'"
    >
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-weight-bold">Correct payment</div>
        <q-space />
        <q-btn flat round dense icon="ph ph-x" aria-label="Close" @click="closeAll" />
      </q-card-section>

      <div class="correct-bill-payment-flow__banner">
        <q-icon name="ph ph-warning" size="20px" class="correct-bill-payment-flow__banner-icon" />
        <div>
          <p v-if="step === 'reason'" class="q-mb-xs">
            Posted payments cannot be edited. Step 1: say why. Step 2: void pay
            <strong v-if="historyEntry?.payment_id">#{{ historyEntry.payment_id }}</strong>
            and add the payment again with the right amount or rate.
          </p>
          <p v-else class="q-mb-xs">
            Pay <strong v-if="replacingPayId">#{{ replacingPayId }}</strong> is voided. Post the corrected payment below.
          </p>
          <p class="q-mb-none correct-bill-payment-flow__banner-sub">
            The bill stays issued — only settlement is reversed and re-recorded.
          </p>
        </div>
      </div>

      <q-card-section v-if="step === 'reason'" class="q-pt-sm">
        <template v-if="historyEntry">
          <p v-if="historyEntry.instruments.length > 1" class="correct-bill-payment-flow__note q-mb-sm">
            Split tender: correction voids the whole pay.
          </p>
          <div class="correct-bill-payment-flow__current q-mb-md">
            <span class="text-caption text-weight-medium">Current pay</span>
            <div class="tf-num">{{ summaryLine }}</div>
          </div>
          <q-input
            v-model="reason"
            outlined
            dense
            type="textarea"
            autogrow
            rows="3"
            label="Reason for correction"
            hint="Required — e.g. wrong exchange rate or amount"
            hide-bottom-space
          />
        </template>
        <p v-else class="text-negative text-caption">Payment row not found on this bill.</p>
        <q-card-actions align="right" class="q-px-none q-pb-none q-pt-md">
          <TfBtn variant="tertiary" label="Cancel" @click="closeAll" />
          <TfBtn
            variant="primary"
            color="warning"
            label="Continue to add payment"
            :loading="voiding"
            :disable="!reason.trim() || !historyEntry"
            @click="onContinue"
          />
        </q-card-actions>
      </q-card-section>

      <div v-else class="correct-bill-payment-flow__payment scroll">
        <RecordBillPaymentDialog
          embedded
          :model-value="true"
          :due-amount="dueAmount"
          :due-currency-code="dueCurrencyCode"
          :bill-id="billId"
          :profile-id="profileId"
          :tenant-id="tenantId"
          :books-tenant-id="booksTenantId"
          :is-ap="isAp"
          :channel-meta="channelMeta"
          :loading="recordLoading"
          :shipment-id="shipmentId"
          :replacing-pay-id="replacingPayId"
          :prefill-snapshot="prefillSnapshot"
          @submit="onPaymentSubmit"
          @cancel="closeAll"
        />
      </div>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useQueryClient } from '@tanstack/vue-query';
import TfBtn from 'src/components/ui/TfBtn.vue';
import RecordBillPaymentDialog from './RecordBillPaymentDialog.vue';
import { paysRepository } from '../repositories/paysRepository';
import {
  buildPayCorrectionSnapshot,
  buildPayCorrectionSnapshotFromHistory,
  historyEntrySummaryLine,
} from '../utils/buildPayCorrectionSnapshot';
import type { PayCorrectionSnapshot } from '../types/payCorrectionSnapshot';
import type { RecordBillPaymentInput } from '../composables/useRecordBillPaymentMutation';
import { paysQueryKeys } from '../services/paysQueryKeys';
import type { InvoicePaymentHistoryEntry } from 'src/modules/sales_invoice/types';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

const props = defineProps<{
  modelValue: boolean;
  historyEntry: InvoicePaymentHistoryEntry | null;
  billId: number;
  dueAmount: number;
  dueCurrencyCode?: string | null;
  profileId: number;
  tenantId: number;
  booksTenantId: number;
  isAp: boolean;
  channelMeta?: Record<string, unknown> | null;
  shipmentId?: number | null;
  recordLoading?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  submit: [payload: RecordBillPaymentInput];
  voided: [];
}>();

const queryClient = useQueryClient();
const step = ref<'reason' | 'payment'>('reason');
const reason = ref('');
const voiding = ref(false);
const replacingPayId = ref<number | null>(null);
const prefillSnapshot = ref<PayCorrectionSnapshot | null>(null);

const historyEntry = computed(() => props.historyEntry);

const summaryLine = computed(() =>
  historyEntry.value ? historyEntrySummaryLine(historyEntry.value) : '',
);

const resetState = () => {
  step.value = 'reason';
  reason.value = '';
  voiding.value = false;
  replacingPayId.value = null;
  prefillSnapshot.value = null;
};

watch(
  () => props.modelValue,
  (open) => {
    if (open) resetState();
    else resetState();
  },
);

const onDialogUpdate = (open: boolean) => {
  if (!open) closeAll();
  else emit('update:modelValue', open);
};

const closeAll = () => {
  emit('update:modelValue', false);
};

const onContinue = async () => {
  const entry = historyEntry.value;
  const trimmed = reason.value.trim();
  if (!entry?.payment_id || !trimmed) return;

  voiding.value = true;
  try {
    let snapshot = buildPayCorrectionSnapshotFromHistory(entry);
    if (!snapshot) {
      const pay = await paysRepository.getPayById(entry.payment_id);
      snapshot = buildPayCorrectionSnapshot(pay);
    }

    await paysRepository.reversePay(entry.payment_id, trimmed);
    void queryClient.invalidateQueries({ queryKey: paysQueryKeys.root, refetchType: 'none' });
    void queryClient.invalidateQueries({
      queryKey: paysQueryKeys.detail(entry.payment_id),
      refetchType: 'none',
    });
    replacingPayId.value = snapshot.paymentId;
    prefillSnapshot.value = snapshot;
    showSuccessNotification('Payment voided. Enter the corrected payment below.');
    emit('voided');
    step.value = 'payment';
  } catch (e) {
    showErrorNotification(e instanceof Error ? e.message : 'Could not void payment.');
  } finally {
    voiding.value = false;
  }
};

const onPaymentSubmit = (payload: RecordBillPaymentInput) => {
  emit('submit', payload);
  closeAll();
};
</script>

<style scoped lang="scss">
.correct-bill-payment-flow__banner {
  display: flex;
  gap: 10px;
  margin: 0 16px 4px;
  padding: 10px 12px;
  background: var(--tf-attention-soft);
  border: 1px solid var(--tf-neutral-border);
  border-radius: var(--tf-radius-sm, 8px);
  font-size: 13px;
  line-height: 1.45;
  color: var(--tf-neutral-ink);
}

.correct-bill-payment-flow__banner-icon {
  flex-shrink: 0;
  margin-top: 2px;
  color: var(--tf-status-attention, #b45309);
}

.correct-bill-payment-flow__banner-sub {
  font-size: 12px;
  color: var(--tf-neutral-muted);
}

.correct-bill-payment-flow__note {
  font-size: 13px;
  color: var(--tf-neutral-muted);
}

.correct-bill-payment-flow__current {
  padding: 8px 10px;
  background: var(--tf-neutral-canvas);
  border: 1px solid var(--tf-neutral-border);
  border-radius: var(--tf-radius-sm, 8px);
}

.correct-bill-payment-flow__payment {
  max-height: min(70vh, 640px);
  overflow-y: auto;
  padding: 0 8px 8px;
}

.correct-bill-payment-flow__payment :deep(.record-bill-payment-card--embedded) {
  border: none;
  box-shadow: none;
}
</style>
