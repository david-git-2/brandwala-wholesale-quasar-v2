<template>
  <q-dialog :model-value="modelValue" persistent @update:model-value="$emit('update:modelValue', $event)">
    <q-card class="q-pa-md" style="min-width: 560px; max-width: 720px; border-radius: 16px">
      <q-card-section class="text-h6 text-weight-bold">Record Payment</q-card-section>
      <q-card-section class="q-gutter-md q-pt-none">
        <div class="row justify-between text-caption text-grey-7">
          <span>Due</span><span class="text-weight-bold text-grey-9">৳{{ dueAmount.toFixed(2) }}</span>
        </div>
        <div class="row justify-between text-caption text-grey-7">
          <span>Already paid</span><span>৳{{ paidAmount.toFixed(2) }}</span>
        </div>
        <div class="row justify-between text-caption text-grey-7">
          <span>Customer store credit</span><span>৳{{ storeCredit.toFixed(2) }}</span>
        </div>

        <q-separator />

        <div class="text-subtitle2 text-weight-bold">Money received</div>
        <div class="text-caption text-grey-7">
          Add one block per payment. Each block has its own amount (cash, cheque, bKash, …).
        </div>

        <PaymentInstrumentLinesEditor
          v-model="instrumentLines"
          title="Each payment (separate amount)"
          @validation-change="onInstrumentValidation"
        />

        <q-separator />

        <div class="text-subtitle2 text-weight-bold">Other adjustments</div>
        <div class="text-caption text-grey-7 q-mb-sm">Not new cash at desk — store credit or write-off.</div>

        <q-input
          v-model.number="walletAmount"
          type="number"
          label="From store credit"
          outlined
          dense
          min="0"
          :max="storeCredit"
          class="soft-input"
        />
        <q-input
          v-model.number="settlementAmount"
          type="number"
          label="Settlement (write-off)"
          outlined
          dense
          min="0"
          class="soft-input"
        />

        <div class="q-pa-sm rounded-borders bg-grey-2">
          <div class="row justify-between text-caption q-py-3xs">
            <span>Money received (sum of payments above)</span>
            <span class="text-weight-bold">{{ formatBdtAmount(instrumentTotal) }}</span>
          </div>
          <div v-if="wallet > 0" class="row justify-between text-caption q-py-3xs">
            <span>Store credit</span>
            <span class="text-weight-bold">{{ formatBdtAmount(wallet) }}</span>
          </div>
          <div v-if="settle > 0" class="row justify-between text-caption q-py-3xs">
            <span>Write-off</span>
            <span class="text-weight-bold">{{ formatBdtAmount(settle) }}</span>
          </div>
          <q-separator class="q-my-xs" />
          <div class="row justify-between text-body2">
            <span class="text-weight-medium">Total applying to invoice</span>
            <span class="text-weight-bold">{{ formatBdtAmount(totalApply) }}</span>
          </div>
        </div>

        <div v-if="overDue" class="text-caption text-negative">Total applying cannot exceed due.</div>
        <div v-if="instrumentValidationMessage" class="text-caption text-negative">
          {{ instrumentValidationMessage }}
        </div>
      </q-card-section>
      <q-card-actions align="right">
        <q-btn flat label="Cancel" v-close-popup class="pill-btn" />
        <q-btn
          color="primary"
          label="Save"
          class="pill-btn"
          :loading="saving"
          :disable="!canSubmit"
          @click="onSave"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import PaymentInstrumentLinesEditor from 'src/modules/wallet/components/PaymentInstrumentLinesEditor.vue';
import {
  createPaymentInstrumentLine,
  formatBdtAmount,
  localPaymentDate,
  mapInstrumentLinesToPayload,
  type PaymentInstrumentLineForm,
} from 'src/modules/wallet/utils/paymentInstruments';
import type { WholesaleCollectPaymentPayload } from '../types';

const props = defineProps<{
  modelValue: boolean;
  dueAmount: number;
  paidAmount: number;
  storeCredit: number;
  saving?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [boolean];
  submit: [WholesaleCollectPaymentPayload];
}>();

const instrumentLines = ref<PaymentInstrumentLineForm[]>([createPaymentInstrumentLine()]);
const walletAmount = ref(0);
const settlementAmount = ref(0);
const instrumentValid = ref(true);
const instrumentValidationMessage = ref<string | null>(null);
const instrumentTotal = ref(0);

const resetForm = () => {
  instrumentLines.value = [createPaymentInstrumentLine()];
  walletAmount.value = 0;
  settlementAmount.value = 0;
  instrumentValid.value = true;
  instrumentValidationMessage.value = null;
  instrumentTotal.value = 0;
};

watch(
  () => props.modelValue,
  (open) => {
    if (open) resetForm();
  },
);

const onInstrumentValidation = (payload: { valid: boolean; message: string | null; total: number }) => {
  instrumentValid.value = payload.valid;
  instrumentValidationMessage.value = payload.message;
  instrumentTotal.value = payload.total;
};

const wallet = computed(() => Math.max(Number(walletAmount.value) || 0, 0));
const settle = computed(() => Math.max(Number(settlementAmount.value) || 0, 0));
const totalApply = computed(() => instrumentTotal.value + wallet.value + settle.value);
const overDue = computed(() => totalApply.value > (Number(props.dueAmount) || 0) + 0.0001);

const canSubmit = computed(
  () =>
    totalApply.value > 0 &&
    !overDue.value &&
    instrumentValid.value &&
    wallet.value <= (Number(props.storeCredit) || 0) + 0.0001,
);

const onSave = () => {
  if (!canSubmit.value) return;
  emit('submit', {
    instruments: mapInstrumentLinesToPayload(instrumentLines.value),
    walletAmount: wallet.value,
    settlementAmount: settle.value,
    note: null,
    receivedOn: localPaymentDate(),
  });
};
</script>
