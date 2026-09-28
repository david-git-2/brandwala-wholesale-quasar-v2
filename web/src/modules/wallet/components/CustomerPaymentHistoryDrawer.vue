<template>
  <q-drawer
    v-model="isOpen"
    side="right"
    overlay
    elevated
    :width="520"
    class="customer-payment-history-drawer bg-white"
  >
    <div class="column full-height">
      <div class="row items-center justify-between q-pa-md bg-grey-1 border-bottom">
        <div>
          <div class="text-subtitle1 text-weight-bold row items-center">
            <q-icon name="ph ph-clock-counter-clockwise" class="q-mr-xs text-primary" size="20px" />
            Payment history
          </div>
          <div class="text-caption text-grey-7">
            {{ customerName }} · {{ accountCode }}
          </div>
        </div>
        <q-btn icon="ph ph-x" flat round dense aria-label="Close history" @click="isOpen = false" />
      </div>

      <div class="col scroll q-pa-md">
        <div v-if="isLoading" class="q-gutter-y-md">
          <q-skeleton v-for="n in 3" :key="n" type="rect" height="72px" />
        </div>

        <div v-else-if="!receipts.length" class="text-center text-grey-6 q-pa-xl">
          <q-icon name="ph ph-receipt" size="48px" class="q-mb-sm" />
          <div class="text-body1 text-weight-medium">No receipts yet</div>
          <div class="text-caption">Posted payments for this customer will appear here.</div>
        </div>

        <div v-else class="column q-gutter-y-md">
          <q-card
            v-for="receipt in receipts"
            :key="receipt.id"
            flat
            bordered
            class="receipt-card"
            :class="{ 'receipt-card--voided': receipt.voided_at }"
          >
            <q-card-section class="q-pa-md">
              <div class="row items-start justify-between q-mb-sm">
                <div>
                  <div class="text-h6 font-mono text-weight-bolder text-primary leading-tight">
                    ৳{{ formatCurrency(receipt.amount) }}
                  </div>
                  <div class="text-caption text-grey-7 q-mt-2xs">
                    {{ formatDisplayDate(receipt.payment_date) }}
                  </div>
                </div>
                <q-badge
                  v-if="receipt.voided_at"
                  color="grey-3"
                  text-color="grey-8"
                  class="text-caption q-px-sm"
                >
                  Voided
                </q-badge>
              </div>

              <div v-if="receipt.instruments.length" class="receipt-section">
                <div class="receipt-section__label">Payment lines</div>
                <div class="column q-gutter-y-xs">
                  <div
                    v-for="inst in receipt.instruments"
                    :key="inst.id"
                    class="instrument-block"
                  >
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

              <div v-else-if="receipt.method" class="receipt-section">
                <div class="receipt-section__label">Payment</div>
                <div class="instrument-block">
                  <div class="row items-center justify-between">
                    <q-chip dense color="blue-1" text-color="blue-9" class="text-weight-bold">
                      {{ methodLabel(receipt.method) }}
                    </q-chip>
                    <span v-if="receipt.reference" class="text-caption text-grey-8">{{ receipt.reference }}</span>
                  </div>
                </div>
              </div>

              <div v-if="receipt.allocations.length" class="receipt-section">
                <div class="receipt-section__label">Applied to bills</div>
                <div class="column q-gutter-y-4xs">
                  <div
                    v-for="alloc in receipt.allocations"
                    :key="alloc.invoice_id"
                    class="row items-center justify-between allocation-row"
                  >
                    <span class="font-mono text-caption text-weight-medium text-grey-8">{{ alloc.invoice_no }}</span>
                    <span class="font-mono text-caption text-weight-bold text-positive">
                      ৳{{ formatCurrency(alloc.amount) }}
                    </span>
                  </div>
                </div>
              </div>

              <div
                v-if="receipt.unallocated_amount > 0 && !receipt.voided_at"
                class="leftover-banner q-mt-sm"
              >
                <q-icon name="ph ph-wallet" size="16px" class="q-mr-xs" />
                Store credit leftover:
                <strong class="font-mono">৳{{ formatCurrency(receipt.unallocated_amount) }}</strong>
              </div>

              <div v-if="receipt.note" class="note-banner q-mt-sm">
                {{ receipt.note }}
              </div>

              <div v-if="!receipt.voided_at" class="row q-gutter-x-sm q-mt-md">
                <q-btn
                  v-if="receipt.instruments.length"
                  flat
                  no-caps
                  size="sm"
                  color="primary"
                  icon="ph ph-pencil-simple"
                  :label="expandedId === receipt.id ? 'Close edit' : 'Fix details'"
                  @click="toggleExpand(receipt.id)"
                />
                <q-btn
                  flat
                  no-caps
                  size="sm"
                  color="negative"
                  icon="ph ph-arrow-counter-clockwise"
                  label="Void & re-enter"
                  @click="confirmVoid(receipt)"
                />
              </div>

              <div v-if="expandedId === receipt.id && !receipt.voided_at" class="q-mt-md q-pt-md border-top">
                <div class="receipt-section__label q-mb-sm">Edit payment details</div>
                <div
                  v-for="inst in receipt.instruments"
                  :key="inst.id"
                  class="instrument-block q-mb-sm"
                >
                  <div class="text-caption text-weight-bold text-grey-8 q-mb-sm">
                    {{ methodLabel(inst.payment_method_code) }} · ৳{{ formatCurrency(inst.amount) }}
                  </div>

                  <template v-if="editingInstrumentId === inst.id">
                    <div class="column q-gutter-y-sm">
                      <q-select
                        v-if="needsPaymentBank(inst.payment_method_code)"
                        v-model="editForm.bd_bank_id"
                        :options="bankOptions"
                        label="Bank *"
                        outlined
                        dense
                        emit-value
                        map-options
                      />
                      <q-input
                        v-if="inst.payment_method_code === 'CHEQUE'"
                        v-model="editForm.cheque_number"
                        label="Cheque number *"
                        outlined
                        dense
                      />
                      <q-input
                        v-if="inst.payment_method_code === 'CHEQUE' || inst.payment_method_code === 'BANK_TRANSFER'"
                        v-model="editForm.cheque_date"
                        :label="inst.payment_method_code === 'CHEQUE' ? 'Cheque date *' : 'Transfer date'"
                        outlined
                        dense
                      />
                      <q-input
                        v-if="needsPaymentReference(inst.payment_method_code) || inst.payment_method_code === 'CASH'"
                        v-model="editForm.reference"
                        :label="inst.payment_method_code === 'CASH' ? 'Till note' : 'Reference / trx id'"
                        outlined
                        dense
                      />
                      <div class="row q-gutter-x-sm justify-end">
                        <q-btn flat dense no-caps label="Cancel" color="grey-7" @click="cancelEdit" />
                        <q-btn
                          unelevated
                          dense
                          no-caps
                          label="Save"
                          color="primary"
                          :loading="isUpdatingInstrument"
                          @click="saveInstrumentEdit(inst)"
                        />
                      </div>
                    </div>
                  </template>

                  <template v-else>
                    <q-btn
                      flat
                      dense
                      no-caps
                      size="sm"
                      color="primary"
                      label="Edit this line"
                      @click="startEdit(inst)"
                    />
                  </template>
                </div>
              </div>
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
import { computed, ref } from 'vue';
import { useQuasar } from 'quasar';
import { useBdBanksQuery } from 'src/modules/global_reference/composables/useGlobalReferenceQuery';
import {
  needsPaymentBank,
  needsPaymentReference,
  paymentMethodFallbackLabel,
} from 'src/modules/wallet/utils/paymentInstruments';
import { usePayments } from '../composables/usePaymentsQuery';
import type { CustomerGroupReceipt, CustomerReceiptInstrument } from '../types/paymentsTypes';

const props = defineProps<{
  modelValue: boolean;
  customerGroupId: number;
  customerName: string;
  accountCode: string;
}>();

const emit = defineEmits<{
  'update:modelValue': [boolean];
  'void-and-reenter': [customerGroupId: number];
}>();

const $q = useQuasar();
const {
  tenantId,
  useCustomerGroupReceipts,
  updateInstrumentDetails,
  isUpdatingInstrument,
  voidCustomerReceipt,
} = usePayments();

const { data: bdBanks } = useBdBanksQuery();

const isOpen = computed({
  get: () => props.modelValue,
  set: (val: boolean) => emit('update:modelValue', val),
});

const receiptsQuery = useCustomerGroupReceipts(
  computed(() => (props.modelValue ? props.customerGroupId : null)),
);

const receipts = computed(() => receiptsQuery.data.value ?? []);
const isLoading = computed(() => receiptsQuery.isFetching.value);

const expandedId = ref<number | null>(null);
const editingInstrumentId = ref<number | null>(null);
const editForm = ref({
  reference: '',
  bd_bank_id: null as number | null,
  cheque_number: '',
  cheque_date: '',
});

const bankOptions = computed(() =>
  (bdBanks.value ?? []).map((b) => ({ label: b.name, value: b.id })),
);

function methodLabel(code: string) {
  return paymentMethodFallbackLabel(code);
}

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

function instrumentDetailRows(inst: CustomerReceiptInstrument): { label: string; value: string }[] {
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

function toggleExpand(id: number) {
  expandedId.value = expandedId.value === id ? null : id;
  editingInstrumentId.value = null;
}

function startEdit(inst: CustomerReceiptInstrument) {
  editingInstrumentId.value = inst.id;
  editForm.value = {
    reference: inst.reference ?? '',
    bd_bank_id: inst.bd_bank_id,
    cheque_number: inst.cheque_number ?? '',
    cheque_date: inst.cheque_date ?? '',
  };
}

function cancelEdit() {
  editingInstrumentId.value = null;
}

async function saveInstrumentEdit(inst: CustomerReceiptInstrument) {
  if (!tenantId.value) return;
  try {
    await updateInstrumentDetails({
      tenant_id: tenantId.value,
      instrument_id: inst.id,
      reference: editForm.value.reference.trim() || null,
      bd_bank_id: editForm.value.bd_bank_id,
      cheque_number: editForm.value.cheque_number.trim() || null,
      cheque_date: editForm.value.cheque_date || null,
    });
    editingInstrumentId.value = null;
    $q.notify({ type: 'positive', message: 'Payment details updated.', position: 'top-right' });
    await receiptsQuery.refetch();
  } catch (err: unknown) {
    $q.notify({
      type: 'negative',
      message: `Failed to update: ${(err as Error).message}`,
      position: 'top-right',
    });
  }
}

function confirmVoid(receipt: CustomerGroupReceipt) {
  $q.dialog({
    title: 'Void this receipt?',
    message:
      'This reverses the cash and unpaid amounts on the bills. You will then re-enter the correct payment on the collect screen.',
    prompt: {
      model: '',
      type: 'text',
      label: 'Reason (required)',
    },
    cancel: { label: 'Cancel', flat: true, color: 'grey-7' },
    ok: { label: 'Void & re-enter', color: 'negative', unelevated: true },
    persistent: true,
  }).onOk(async (reason: string) => {
    if (!tenantId.value || !reason?.trim()) {
      $q.notify({ type: 'warning', message: 'A reason is required.', position: 'top-right' });
      return;
    }
    try {
      await voidCustomerReceipt({
        tenant_id: tenantId.value,
        payment_id: receipt.id,
        reason: reason.trim(),
      });
      isOpen.value = false;
      emit('void-and-reenter', props.customerGroupId);
      $q.notify({ type: 'positive', message: 'Receipt voided. Enter the correct payment.', position: 'top-right' });
    } catch (err: unknown) {
      $q.notify({
        type: 'negative',
        message: `Failed to void: ${(err as Error).message}`,
        position: 'top-right',
      });
    }
  });
}
</script>

<style scoped>
.border-bottom {
  border-bottom: 1px solid var(--q-separator-color, #e2e0db);
}

.border-top {
  border-top: 1px dashed #e2e0db;
}

.receipt-card {
  border-radius: 10px;
}

.receipt-card--voided {
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

.allocation-row {
  padding: 4px 0;
  border-bottom: 1px dashed #eef0f3;
}

.allocation-row:last-child {
  border-bottom: none;
}

.leftover-banner {
  display: flex;
  align-items: center;
  font-size: 13px;
  color: #c2410c;
  background: #fff7ed;
  border: 1px solid #fed7aa;
  border-radius: 8px;
  padding: 8px 12px;
}

.note-banner {
  font-size: 12px;
  color: #64748b;
  background: #f1f5f9;
  border-radius: 6px;
  padding: 8px 12px;
  font-style: italic;
}
</style>
