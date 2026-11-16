<template>
  <TfConfirmDialog
    v-model="open"
    title="Cancel this bill?"
    message="This cannot be undone. The bill number stays on file; status becomes voided."
    destructive
    confirm-label="Cancel bill"
    cancel-label="Keep bill"
    :confirm-loading="confirmLoading"
    @confirm="onConfirm"
    @cancel="onCancel"
  >
    <div v-if="bill" class="column q-gutter-y-sm bill-cancel-dialog">
      <section class="bill-cancel-dialog__block">
        <div class="bill-cancel-dialog__label">Bill</div>
        <div class="text-body2">
          {{ bill.invoiceNo }}
          · {{ bill.currencyCode }}
          · Total {{ formatMoney(bill.totalAmount, bill.currencyCode) }}
        </div>
        <div class="text-caption text-grey-7">
          Paid {{ formatMoney(bill.paidAmount, bill.currencyCode) }}
          · Due {{ formatMoney(bill.dueAmount, bill.currencyCode) }}
          <template v-if="bill.writtenOffAmount > 0.001">
            · Written off {{ formatMoney(bill.writtenOffAmount, bill.currencyCode) }}
          </template>
        </div>
      </section>

      <section class="bill-cancel-dialog__block">
        <div class="bill-cancel-dialog__label">What will happen</div>
        <ol class="bill-cancel-dialog__steps q-my-none q-pl-md">
          <li v-if="payments.length">
            Void {{ payments.length === 1 ? 'this payment' : `${payments.length} payments` }} and put cash back in the pot.
          </li>
          <li v-else-if="bill.paidAmount > 0.001">
            Reverse settlements on this bill and put cash back in the pot.
          </li>
          <li>Unapply any credit notes applied to this bill.</li>
          <li>Mark this bill voided (invoice number is kept).</li>
        </ol>
      </section>

      <section v-if="payments.length" class="bill-cancel-dialog__block">
        <div class="bill-cancel-dialog__label">Payments to void</div>
        <ul class="bill-cancel-dialog__pay-list q-my-none q-pl-none">
          <li
            v-for="entry in payments"
            :key="entry.entry_id"
            class="bill-cancel-dialog__pay-row"
          >
            <span>{{ entry.payment_date }}</span>
            <span class="text-weight-medium">
              {{ formatPaymentHistoryPrimary(entry, settlementCurrencyCode) }}
            </span>
            <span
              v-if="formatPaymentHistoryBooksCaption(entry, settlementCurrencyCode)"
              class="text-caption text-grey-7"
            >
              {{ formatPaymentHistoryBooksCaption(entry, settlementCurrencyCode) }}
            </span>
          </li>
        </ul>
      </section>

      <section v-if="openCreditNoteCount > 0" class="bill-cancel-dialog__warn">
        This bill has {{ openCreditNoteCount }} open credit
        {{ openCreditNoteCount === 1 ? 'note' : 'notes' }} linked to it. Those notes are
        not voided automatically — cancel them separately if needed.
      </section>

      <section v-if="isArCollect" class="bill-cancel-dialog__warn">
        Customer receipts need that cash still in your pot. If it was spent, cancel will fail.
      </section>

      <section>
        <q-input
          v-model="reasonDraft"
          outlined
          dense
          hide-bottom-space
          label="Reason (optional)"
          type="textarea"
          autogrow
        />
      </section>
    </div>
  </TfConfirmDialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import TfConfirmDialog from 'src/components/ui/TfConfirmDialog.vue';
import type { InvoicePaymentHistoryEntry } from 'src/modules/sales_invoice/types';
import {
  formatPaymentHistoryBooksCaption,
  formatPaymentHistoryPrimary,
} from '../utils/paymentHistoryDisplay';
import { formatBdtTaka, formatSettlementCurrencyAmount } from 'src/utils/currency';

export type BillCancelConfirmSnapshot = {
  invoiceNo: string;
  totalAmount: number;
  paidAmount: number;
  dueAmount: number;
  writtenOffAmount: number;
  currencyCode: string;
};

const props = withDefaults(
  defineProps<{
    modelValue: boolean;
    bill: BillCancelConfirmSnapshot | null;
    payments: InvoicePaymentHistoryEntry[];
    settlementCurrencyCode?: string | null;
    isAp: boolean;
    openCreditNoteCount: number;
    confirmLoading?: boolean;
  }>(),
  {
    confirmLoading: false,
    settlementCurrencyCode: null,
  },
);

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  confirm: [reason: string | null];
}>();

const open = computed({
  get: () => props.modelValue,
  set: (v: boolean) => emit('update:modelValue', v),
});

const reasonDraft = ref('');

watch(
  () => props.modelValue,
  (v) => {
    if (v) reasonDraft.value = '';
  },
);

const isArCollect = computed(() => !props.isAp && props.payments.length > 0);

function formatMoney(amount: number, code: string): string {
  const c = (code || 'BDT').trim().toUpperCase();
  if (c === 'BDT') return formatBdtTaka(amount);
  return formatSettlementCurrencyAmount(amount, c);
}

function onConfirm() {
  const reason = reasonDraft.value.trim();
  emit('confirm', reason.length ? reason : null);
}

function onCancel() {
  emit('update:modelValue', false);
}
</script>

<style scoped lang="scss">
.bill-cancel-dialog__block {
  padding: var(--tf-space-2xs, 6px) 0;
  border-top: 1px solid var(--tf-neutral-border);
}

.bill-cancel-dialog__block:first-child {
  border-top: none;
  padding-top: 0;
}

.bill-cancel-dialog__label {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--tf-neutral-chrome-text);
  margin-bottom: 4px;
}

.bill-cancel-dialog__steps {
  font-size: 13px;
  line-height: 1.45;
}

.bill-cancel-dialog__pay-list {
  list-style: none;
}

.bill-cancel-dialog__pay-row {
  display: flex;
  flex-wrap: wrap;
  gap: 6px 10px;
  align-items: baseline;
  padding: 4px 0;
  border-bottom: 1px solid var(--tf-neutral-border);
  font-size: 13px;
}

.bill-cancel-dialog__pay-row:last-child {
  border-bottom: none;
}

.bill-cancel-dialog__warn {
  font-size: 13px;
  color: var(--tf-attention-text, #9a6700);
  background: var(--tf-attention-soft, rgba(234, 179, 8, 0.12));
  border: 1px solid var(--tf-neutral-border);
  border-radius: var(--tf-radius-sm);
  padding: 8px 10px;
}
</style>