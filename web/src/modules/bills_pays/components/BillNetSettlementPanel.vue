<template>
  <div class="bill-net-settlement-panel">
    <div class="text-overline text-grey-7 q-mb-xs">Money summary</div>
    <div
      v-if="isDualCurrency && invoiceRate"
      class="text-caption text-grey-7 q-mb-xs bill-total-row"
    >
      <span>Rate</span>
      <span class="font-mono">{{ invoiceRate }} BDT per 1 {{ invoiceCurrency }}</span>
    </div>
    <div v-if="loading" class="text-caption text-grey-6">Loading balances…</div>
    <template v-else-if="balances">
      <div class="bill-total-row">
        <span>{{ startingAmountLabel }}</span>
        <DualAmountCell :display="dualAmount(balances.original_total, 'original')" />
      </div>
      <div class="bill-total-row text-weight-medium">
        <span>Amount after notes</span>
        <span class="column items-end">
          <DualAmountCell :display="dualAmount(amountAfterNotes)" />
          <span
            v-if="notesAdjustmentCaption"
            class="text-caption text-grey-7 text-weight-regular text-right"
          >
            {{ notesAdjustmentCaption }}
          </span>
        </span>
      </div>
      <div class="bill-total-row">
        <span>{{ paidLabel }}</span>
        <DualAmountCell :display="dualAmount(balances.paid_amount)" />
      </div>
      <div class="bill-total-row text-weight-bold">
        <span>{{ stillOwedLabel }}</span>
        <DualAmountCell :display="dualAmount(stillOwedBooks, 'due')" />
      </div>
      <template v-if="isAp && refundReceiptRows.length">
        <div
          v-for="row in refundReceiptRows"
          :key="row.currencyCode"
          class="bill-total-row text-positive"
        >
          <span>{{ refundRowLabel(row.currencyCode) }}</span>
          <DualAmountCell :display="row.display" />
        </div>
      </template>
      <div
        v-else-if="isAp && vendorRefundsReceived > 0"
        class="bill-total-row text-positive"
      >
        <span>Refund received from vendor</span>
        <DualAmountCell :display="dualAmount(vendorRefundsReceived)" />
      </div>
      <div v-if="balances.credit_open > 0" class="bill-total-row text-primary">
        <span>{{ openCreditLabel }}</span>
        <DualAmountCell :display="dualAmount(balances.credit_open)" />
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
import { computed, defineComponent, h } from 'vue';
import { formatAmountBdt, formatSettlementCurrencyAmount } from 'src/utils/currency';
import type { BillNetBalances } from '../types/billBalances';
import type { VendorRefundReceiptBucket } from '../utils/paymentHistoryDisplay';
import { apBillPaperForeignTotal } from '../utils/apBillBooks';
import {
  apBillPaperConversionRate,
  apBillPaperCurrencyCode,
  apBooksToSettlementAmount,
} from '../utils/parseApBillPaper';

export type DualAmountDisplay = {
  primary: string;
  secondary: string | null;
};

const DualAmountCell = defineComponent({
  name: 'DualAmountCell',
  props: {
    display: { type: Object as () => DualAmountDisplay, required: true },
  },
  setup(props) {
    return () =>
      h('span', { class: 'font-mono column items-end' }, [
        h('span', props.display.primary),
        props.display.secondary
          ? h('span', { class: 'text-caption text-grey-7' }, props.display.secondary)
          : null,
      ]);
  },
});

const props = defineProps<{
  balances: BillNetBalances | null | undefined;
  isAp: boolean;
  loading?: boolean;
  channelMeta?: Record<string, unknown> | null;
  /** Issued credit notes with due &gt; 0 (for “still open on …”). */
  openCreditNoteNos?: string[];
  /** Cash refunds grouped by settlement currency (from payment history). */
  vendorRefundReceipts?: VendorRefundReceiptBucket[];
}>();

const refundReceiptRows = computed(() => {
  const buckets = props.vendorRefundReceipts ?? [];
  return buckets
    .filter((b) => b.booksBdt > 0 || b.foreignTotal > 0)
    .map((b) => {
      const code = b.currencyCode.toUpperCase();
      if (code === 'BDT') {
        return {
          currencyCode: code,
          display: { primary: formatAmountBdt(b.booksBdt), secondary: null },
        };
      }
      return {
        currencyCode: code,
        display: {
          primary: formatSettlementCurrencyAmount(b.foreignTotal, code),
          secondary: formatAmountBdt(b.booksBdt),
        },
      };
    });
});

function refundRowLabel(currencyCode: string): string {
  if (currencyCode === 'BDT') return 'Refund received from vendor';
  return `Refund received (${currencyCode})`;
}

const invoiceCurrency = computed(() =>
  props.isAp ? apBillPaperCurrencyCode(props.channelMeta ?? null) : 'BDT',
);
const invoiceRate = computed(() => apBillPaperConversionRate(props.channelMeta ?? null));
const foreignPaperTotal = computed(() =>
  Math.max(0, Number(apBillPaperForeignTotal(props.channelMeta ?? null) ?? 0)),
);

const isDualCurrency = computed(
  () => props.isAp && invoiceCurrency.value !== 'BDT' && foreignPaperTotal.value > 0,
);

const amountAfterNotes = computed(() => {
  if (!props.balances) return 0;
  const original = Number(props.balances.original_total) || 0;
  const credits = Number(props.balances.credits_issued) || 0;
  const debits = Number(props.balances.debits_issued) || 0;
  return Math.round((original - credits + debits) * 100) / 100;
});

const stillOwedBooks = computed(() => {
  if (!props.balances) return 0;
  return Math.max(0, Number(props.balances.open_books ?? props.balances.due_amount) || 0);
});

function booksToForeignFace(books: number, hint?: 'original' | 'due'): number {
  const code = invoiceCurrency.value;
  const foreignTotal = foreignPaperTotal.value;
  const b = Math.max(0, Number(books) || 0);
  if (!isDualCurrency.value) return b;

  if (hint === 'original' && props.balances) {
    const originalBooks = Number(props.balances.original_total) || 0;
    if (Math.abs(b - originalBooks) < 0.02) return foreignTotal;
  }

  if (hint === 'due' && props.balances) {
    const openTxn = props.balances.open_txn;
    if (openTxn != null && Number.isFinite(Number(openTxn))) {
      return Math.max(0, Number(openTxn));
    }
    const dueBooks = Number(props.balances.open_books ?? props.balances.due_amount) || 0;
    if (b > 0 && Math.abs(b - dueBooks) < 0.02 && Math.abs(b - foreignTotal) < 0.02) {
      return b;
    }
  }

  return apBooksToSettlementAmount(b, props.channelMeta ?? null, foreignTotal, code);
}

function dualAmount(books: number, hint?: 'original' | 'due'): DualAmountDisplay {
  const b = Number(books) || 0;
  if (!isDualCurrency.value) {
    return { primary: formatAmountBdt(b), secondary: null };
  }
  const code = invoiceCurrency.value;
  const fx = booksToForeignFace(b, hint);
  return {
    primary: formatSettlementCurrencyAmount(fx, code),
    secondary: formatAmountBdt(b),
  };
}

const notesAdjustmentCaption = computed(() => {
  if (!props.balances) return null;
  const credits = Number(props.balances.credits_issued) || 0;
  const debits = Number(props.balances.debits_issued) || 0;
  const parts: string[] = [];
  if (credits > 0) {
    parts.push(formatNoteDelta('credit notes', credits, true));
  }
  if (debits > 0) {
    parts.push(formatNoteDelta('debit notes', debits, false));
  }
  if (!parts.length) return null;
  return parts.join(' · ');
});

function formatNoteDelta(label: string, books: number, subtract: boolean): string {
  const sign = subtract ? '−' : '+';
  if (!isDualCurrency.value) {
    return `${label} ${sign}${formatAmountBdt(books)}`;
  }
  const fx = booksToForeignFace(books);
  const code = invoiceCurrency.value;
  return `${label} ${sign}${formatSettlementCurrencyAmount(fx, code)} (${formatAmountBdt(books)})`;
}

const startingAmountLabel = computed(() =>
  props.isAp ? 'First bill amount' : 'First invoice amount',
);

const paidLabel = computed(() => (props.isAp ? 'You paid' : 'Customer paid'));

const stillOwedLabel = computed(() =>
  props.isAp ? 'You still owe' : 'Customer still owes',
);

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
  props.isAp ? 'Vendor still owes you' : 'Credit still owed to customer',
);

const openCreditHint = computed(() =>
  props.isAp
    ? 'Record vendor refund when cash hits your till or bank. Each open note clears separately.'
    : 'Refund the customer or apply to another invoice when that flow is available.',
);
</script>

<style scoped lang="scss">
.bill-net-settlement-panel {
  border-top: 1px solid var(--tf-neutral-border, #e2e8f0);
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
