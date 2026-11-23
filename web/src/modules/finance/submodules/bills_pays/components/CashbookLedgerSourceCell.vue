<template>
  <div class="cashbook-ledger-source">
    <div>{{ title }}</div>
    <div v-if="detail" class="text-grey-7">{{ detail }}</div>
    <button
      v-if="payId && linkPay"
      type="button"
      class="cashbook-ledger-source__pay-link"
      @click.stop="emit('open-pay', payId)"
    >
      Pay #{{ payId }}
    </button>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { CashbookLedgerRow } from '../repositories/cashbookRepository';
import {
  cashbookLedgerPayId,
  formatCashbookLedgerSourceDetail,
  formatCashbookLedgerSourceTitle,
} from '../utils/cashbookLedgerDisplay';

const props = withDefaults(
  defineProps<{
    line: CashbookLedgerRow;
    linkPay?: boolean;
  }>(),
  { linkPay: true },
);

const emit = defineEmits<{ 'open-pay': [payId: number] }>();

const title = computed(() => formatCashbookLedgerSourceTitle(props.line));
const detail = computed(() => formatCashbookLedgerSourceDetail(props.line));
const payId = computed(() => cashbookLedgerPayId(props.line));
</script>

<style scoped>
.cashbook-ledger-source {
  font-size: inherit;
  line-height: 1.35;
}

.cashbook-ledger-source__pay-link {
  margin: 2px 0 0;
  padding: 0;
  border: none;
  background: none;
  color: var(--q-primary);
  font: inherit;
  font-size: 0.85em;
  cursor: pointer;
  text-decoration: underline;
}
</style>
