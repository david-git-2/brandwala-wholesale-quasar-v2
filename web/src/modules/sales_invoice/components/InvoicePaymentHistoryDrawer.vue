<template>
  <q-drawer
    v-model="isOpen"
    side="right"
    overlay
    elevated
    :width="520"
    class="invoice-payment-history-drawer bg-white"
  >
    <div class="column full-height">
      <div class="row items-center justify-between q-pa-md bg-grey-1 border-bottom">
        <div>
          <div class="text-subtitle1 text-weight-bold row items-center">
            <q-icon name="ph ph-clock-counter-clockwise" class="q-mr-xs text-primary" size="20px" />
            Payment history
          </div>
          <div class="text-caption text-grey-7">{{ invoiceNo }}</div>
        </div>
        <q-btn icon="ph ph-x" flat round dense aria-label="Close history" @click="isOpen = false" />
      </div>

      <div class="col scroll q-pa-md">
        <div v-if="isLoading" class="q-gutter-y-md">
          <q-skeleton v-for="n in 3" :key="n" type="rect" height="72px" />
        </div>

        <div v-else-if="!entries.length" class="text-center text-grey-6 q-pa-xl">
          <q-icon name="ph ph-receipt" size="48px" class="q-mb-sm" />
          <div class="text-body1 text-weight-medium">No payments yet</div>
          <div class="text-caption">Receipts and concessions on this bill will appear here.</div>
        </div>

        <div v-else class="column q-gutter-y-md">
          <q-card
            v-for="entry in entries"
            :key="`${entry.entry_type}-${entry.entry_id}`"
            flat
            bordered
            class="history-card"
            :class="{ 'history-card--voided': entry.voided_at }"
          >
            <q-card-section class="q-pa-md">
              <div class="row items-start justify-between q-mb-sm">
                <div>
                  <div class="row items-center q-gutter-x-xs">
                    <q-badge
                      :color="entry.entry_type === 'write_off' ? 'orange-2' : 'blue-1'"
                      :text-color="entry.entry_type === 'write_off' ? 'orange-9' : 'blue-9'"
                      class="text-weight-bold"
                    >
                      {{ entryTypeLabel(entry) }}
                    </q-badge>
                    <q-badge
                      v-if="entry.voided_at"
                      color="grey-3"
                      text-color="grey-8"
                      class="text-caption q-px-sm"
                    >
                      Voided
                    </q-badge>
                  </div>
                  <div class="text-h6 font-mono text-weight-bolder text-primary leading-tight q-mt-xs">
                    ৳{{ formatCurrency(entry.amount) }}
                  </div>
                  <div class="text-caption text-grey-7">{{ formatDisplayDate(entry.payment_date) }}</div>
                  <div
                    v-if="entry.entry_type === 'allocation' && entry.receipt_amount > entry.amount"
                    class="text-2xs text-grey-6 q-mt-2xs"
                  >
                    From receipt ৳{{ formatCurrency(entry.receipt_amount) }}
                  </div>
                  <div v-if="entry.write_off_reason" class="text-2xs text-grey-7 q-mt-2xs">
                    Reason: {{ writeOffReasonLabel(entry.write_off_reason) }}
                  </div>
                </div>
              </div>

              <div v-if="entry.instruments.length" class="receipt-section">
                <div class="receipt-section__label">Payment lines</div>
                <div class="column q-gutter-y-xs">
                  <div v-for="inst in entry.instruments" :key="inst.id" class="instrument-block">
                    <div class="row items-center justify-between q-mb-xs">
                      <q-chip dense color="blue-1" text-color="blue-9" class="text-weight-bold">
                        {{ methodLabel(inst.payment_method_code) }}
                      </q-chip>
                      <span class="font-mono text-body2 text-weight-bold text-grey-9">
                        ৳{{ formatCurrency(inst.amount) }}
                      </span>
                    </div>
                    <div v-if="instrumentDetailRows(inst).length" class="detail-grid">
                      <div
                        v-for="row in instrumentDetailRows(inst)"
                        :key="row.label"
                        class="detail-grid__row"
                      >
                        <span class="detail-grid__label">{{ row.label }}</span>
                        <span class="detail-grid__value">{{ row.value }}</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <div v-if="entry.note" class="note-banner q-mt-sm">{{ entry.note }}</div>
            </q-card-section>
          </q-card>
        </div>
      </div>

      <div class="q-pa-md bg-grey-1 border-top row justify-end">
        <q-btn flat label="Close" color="grey-8" no-caps @click="isOpen = false" />
      </div>
    </div>
  </q-drawer>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { paymentMethodFallbackLabel } from 'src/modules/wallet/utils/paymentInstruments';
import { invoiceRepository } from '../repositories/invoiceRepository';
import type { InvoicePaymentHistoryEntry, InvoicePaymentHistoryInstrument } from '../types';

const props = defineProps<{
  modelValue: boolean;
  tenantId: number | null;
  invoiceId: number | null;
  invoiceNo: string;
}>();

const emit = defineEmits<{
  'update:modelValue': [boolean];
}>();

const isOpen = computed({
  get: () => props.modelValue,
  set: (val: boolean) => emit('update:modelValue', val),
});

const entries = ref<InvoicePaymentHistoryEntry[]>([]);
const isLoading = ref(false);

const writeOffReasonLabels: Record<string, string> = {
  dispute_settlement: 'Dispute settlement',
  bad_debt: 'Bad debt',
  currency_rounding: 'Currency rounding',
  management_concession: 'Management concession',
};

async function loadHistory() {
  if (!props.tenantId || !props.invoiceId) {
    entries.value = [];
    return;
  }
  isLoading.value = true;
  try {
    entries.value = await invoiceRepository.listInvoicePaymentHistory({
      tenantId: props.tenantId,
      invoiceId: props.invoiceId,
    });
  } catch {
    entries.value = [];
  } finally {
    isLoading.value = false;
  }
}

watch(
  () => [props.modelValue, props.invoiceId, props.tenantId] as const,
  ([open]) => {
    if (open) void loadHistory();
  },
);

function formatCurrency(val: number) {
  return Number(val || 0).toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

function formatDisplayDate(val: string) {
  const d = new Date(`${val}T00:00:00`);
  if (Number.isNaN(d.getTime())) return val;
  return d.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
}

function methodLabel(code: string) {
  return paymentMethodFallbackLabel(code);
}

function entryTypeLabel(entry: InvoicePaymentHistoryEntry) {
  return entry.entry_type === 'write_off' ? 'Concession / write-off' : 'Payment';
}

function writeOffReasonLabel(reason: string) {
  return writeOffReasonLabels[reason] ?? reason.replace(/_/g, ' ');
}

function instrumentDetailRows(inst: InvoicePaymentHistoryInstrument): { label: string; value: string }[] {
  const rows: { label: string; value: string }[] = [];
  if (inst.bank_name) rows.push({ label: 'Bank', value: inst.bank_name });
  if (inst.cheque_number) rows.push({ label: 'Cheque no.', value: inst.cheque_number });
  if (inst.cheque_date) rows.push({ label: 'Date', value: formatDisplayDate(inst.cheque_date) });
  if (inst.reference) {
    const label = inst.payment_method_code === 'CASH' ? 'Till note' : 'Reference';
    rows.push({ label, value: inst.reference });
  }
  return rows;
}
</script>

<style scoped>
.border-bottom {
  border-bottom: 1px solid var(--q-separator-color, #e2e0db);
}

.border-top {
  border-top: 1px solid var(--q-separator-color, #e2e0db);
}

.history-card {
  border-radius: 10px;
}

.history-card--voided {
  opacity: 0.7;
  background: #f8fafc;
}

.receipt-section {
  margin-top: 12px;
  padding-top: 12px;
  border-top: 1px solid #eef0f3;
}

.receipt-section__label {
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: #94a3b8;
  margin-bottom: 8px;
}

.instrument-block {
  background: #f8fafc;
  border: 1px solid #e8ecf1;
  border-radius: 8px;
  padding: 10px 12px;
}

.detail-grid {
  display: grid;
  gap: 4px;
}

.detail-grid__row {
  display: grid;
  grid-template-columns: 88px 1fr;
  gap: 8px;
  align-items: baseline;
}

.detail-grid__label {
  font-size: 12px;
  color: #64748b;
}

.detail-grid__value {
  font-size: 13px;
  color: #1e293b;
  word-break: break-word;
}

.note-banner {
  font-size: 12px;
  color: #64748b;
  background: #f1f5f9;
  border-radius: 6px;
  padding: 8px 12px;
  font-style: italic;
}

.text-2xs {
  font-size: 10px;
  line-height: 1.2;
}
</style>
