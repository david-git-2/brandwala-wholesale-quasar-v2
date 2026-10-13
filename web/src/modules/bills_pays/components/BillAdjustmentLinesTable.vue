<template>
  <q-markup-table flat dense class="bill-adjustment-lines-table">
    <thead>
      <tr>
        <th class="text-left">Description</th>
        <th class="text-right">Amount</th>
        <th class="text-right">Books (BDT)</th>
      </tr>
    </thead>
    <tbody>
      <tr v-for="line in lines" :key="line.id">
        <td>{{ line.name_snapshot }}</td>
        <td class="text-right font-mono">{{ formatLineAmount(line) }}</td>
        <td class="text-right font-mono">{{ formatAmountBdt(line.books_amount) }}</td>
      </tr>
      <tr v-if="!lines.length && headerTotalBdt != null && headerTotalBdt > 0">
        <td class="text-grey-7">Credit / debit total</td>
        <td />
        <td class="text-right font-mono text-weight-medium">
          {{ formatAmountBdt(headerTotalBdt) }}
        </td>
      </tr>
      <tr v-if="!lines.length && (!headerTotalBdt || headerTotalBdt <= 0)">
        <td colspan="3" class="text-caption text-grey-6">No line detail on this note.</td>
      </tr>
    </tbody>
    <tfoot v-if="lines.length">
      <tr class="text-weight-bold">
        <td>Total</td>
        <td />
        <td class="text-right font-mono">{{ formatAmountBdt(linesBooksTotal) }}</td>
      </tr>
    </tfoot>
  </q-markup-table>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { formatAmountBdt } from 'src/utils/currency';
import type { BillLineDisplayRow } from '../repositories/billLinesRepository';

const props = defineProps<{
  lines: BillLineDisplayRow[];
  headerTotalBdt?: number | null;
}>();

const linesBooksTotal = computed(() =>
  props.lines.reduce((sum, line) => sum + Number(line.books_amount ?? 0), 0),
);

function formatLineAmount(line: BillLineDisplayRow): string {
  const code = (line.currency_code || 'BDT').toUpperCase();
  const amt = Number(line.line_total_amount ?? 0);
  const formatted = amt.toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
  return code === 'BDT' ? formatAmountBdt(amt) : `${code} ${formatted}`;
}
</script>
