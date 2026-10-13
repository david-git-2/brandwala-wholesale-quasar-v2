<template>
  <div class="bill-net-settlement-panel">
    <div class="text-overline text-grey-7 q-mb-xs">Settlement (books)</div>
    <div v-if="loading" class="text-caption text-grey-6">Loading balances…</div>
    <template v-else-if="balances">
      <div class="bill-total-row">
        <span>Original issued</span>
        <span class="font-mono">{{ formatAmountBdt(balances.original_total) }}</span>
      </div>
      <div v-if="balances.credits_issued > 0" class="bill-total-row">
        <span>Credit notes</span>
        <span class="font-mono">− {{ formatAmountBdt(balances.credits_issued) }}</span>
      </div>
      <div v-if="balances.debits_issued > 0" class="bill-total-row">
        <span>Debit notes</span>
        <span class="font-mono">+ {{ formatAmountBdt(balances.debits_issued) }}</span>
      </div>
      <div class="bill-total-row">
        <span>Paid</span>
        <span class="font-mono">{{ formatAmountBdt(balances.paid_amount) }}</span>
      </div>
      <div class="bill-total-row text-weight-bold">
        <span>Due</span>
        <span class="font-mono">{{ formatAmountBdt(balances.due_amount) }}</span>
      </div>
      <div
        v-if="isAp && vendorRefundsReceived > 0"
        class="bill-total-row text-positive"
      >
        <span>Refunds received</span>
        <span class="font-mono column items-end">
          <span>{{ openAmountPrimary(vendorRefundsReceived) }}</span>
          <span
            v-if="openAmountBooksCaption(vendorRefundsReceived)"
            class="text-caption text-grey-7"
          >
            {{ openAmountBooksCaption(vendorRefundsReceived) }}
          </span>
        </span>
      </div>
      <div v-if="balances.credit_open > 0" class="bill-total-row text-primary">
        <span>{{ openCreditLabel }}</span>
        <span class="font-mono column items-end">
          <span>{{ openAmountPrimary(balances.credit_open) }}</span>
          <span
            v-if="openAmountBooksCaption(balances.credit_open)"
            class="text-caption text-grey-7"
          >
            {{ openAmountBooksCaption(balances.credit_open) }}
          </span>
        </span>
      </div>
      <div v-if="balances.credit_open > 0 && openCreditNoteNos.length" class="text-caption text-grey-7">
        On: {{ openCreditNoteNos.join(', ') }}
      </div>
      <div v-if="balances.credit_open > 0" class="text-caption text-grey-7 q-mt-xs">
        {{ openCreditHint }}
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { formatAmountBdt, formatSettlementCurrencyAmount } from 'src/utils/currency';
import type { BillNetBalances } from '../composables/useBillNetBalancesQuery';
import {
  apBillPaperCurrencyCode as apInvoiceCurrencyFromMeta,
} from '../utils/apBillBooks';
import {
  apBillPaperConversionRate,
  apBooksToSettlementAmount,
} from '../utils/parseApBillPaper';

const props = defineProps<{
  balances: BillNetBalances | null | undefined;
  isAp: boolean;
  loading?: boolean;
  channelMeta?: Record<string, unknown> | null;
  /** Issued credit notes with due &gt; 0 (for “still open on …”). */
  openCreditNoteNos?: string[];
}>();

const invoiceCurrency = computed(() =>
  props.isAp ? apInvoiceCurrencyFromMeta(props.channelMeta ?? null) : 'BDT',
);
const invoiceRate = computed(() => apBillPaperConversionRate(props.channelMeta ?? null));

const vendorRefundsReceived = computed(() => {
  if (!props.isAp || !props.balances) return 0;
  const issued = Number(props.balances.credits_issued) || 0;
  const open = Number(props.balances.credit_open) || 0;
  return Math.max(0, Math.round((issued - open) * 100) / 100);
});

const openCreditNoteNos = computed(() =>
  (props.openCreditNoteNos ?? []).map((n) => n.trim()).filter(Boolean),
);

const openCreditLabel = computed(() =>
  props.isAp ? 'Still open on credit notes' : 'Open customer credit',
);

const openCreditHint = computed(() =>
  props.isAp
    ? 'Record vendor refund per open note when cash hits your till or bank. Each note clears separately.'
    : 'Refund or apply to another invoice when that flow is available.',
);

function booksToInvoiceFace(books: number): number | null {
  const code = invoiceCurrency.value;
  if (!props.isAp || code === 'BDT' || books <= 0) return null;
  const rate = invoiceRate.value;
  if (rate && rate > 0) {
    return Math.round((books / rate) * 100) / 100;
  }
  return apBooksToSettlementAmount(books, props.channelMeta ?? null, 0, code);
}

function openAmountPrimary(books: number): string {
  const fx = booksToInvoiceFace(books);
  const code = invoiceCurrency.value;
  if (fx != null && code !== 'BDT') {
    return formatSettlementCurrencyAmount(fx, code);
  }
  return formatAmountBdt(books);
}

function openAmountBooksCaption(books: number): string | null {
  const fx = booksToInvoiceFace(books);
  const code = invoiceCurrency.value;
  if (fx == null || code === 'BDT') return null;
  return `${formatAmountBdt(books)} books`;
}
</script>

<style scoped lang="scss">
.bill-net-settlement-panel {
  border-top: 1px solid var(--bw-neutral-border, #e2e8f0);
  padding-top: 0.5rem;
}

.bill-total-row {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  font-size: 13px;
  padding: 2px 0;
}
</style>
