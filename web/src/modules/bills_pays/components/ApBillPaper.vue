<template>
  <div class="ap-bill-paper">
    <div v-if="paper?.paper === 'vendor'" class="column q-gutter-y-sm">
      <div class="ap-bill-row">
        <span class="text-grey-7">Product invoice total</span>
        <span class="font-mono text-weight-medium">{{ formatForeign(paper.foreign_amount) }}</span>
      </div>
      <div class="ap-bill-row">
        <span class="text-grey-7">Conversion rate</span>
        <span class="font-mono">{{ formatRate(paper.conversion_rate) }}</span>
      </div>
      <div class="ap-bill-row text-weight-bold">
        <span>Amount (BDT)</span>
        <span class="font-mono">{{ formatAmountBdt(paper.bdt_amount) }}</span>
      </div>
    </div>

    <div v-else-if="paper?.paper === 'cargo'" class="column q-gutter-y-sm">
      <div class="ap-bill-row">
        <span class="text-grey-7">Total weight</span>
        <span class="font-mono">{{ formatWeight(paper.weight_kg) }}</span>
      </div>
      <div class="ap-bill-row">
        <span class="text-grey-7">Cargo invoice price</span>
        <span class="font-mono text-weight-medium">{{ formatForeign(paper.price) }}</span>
      </div>
      <div class="ap-bill-row">
        <span class="text-grey-7">Conversion rate</span>
        <span class="font-mono">{{ formatRate(paper.conversion_rate) }}</span>
      </div>
      <div class="ap-bill-row text-weight-bold">
        <span>Amount (BDT)</span>
        <span class="font-mono">{{ formatAmountBdt(paper.bdt_amount) }}</span>
      </div>
    </div>

    <div v-else-if="paper?.paper === 'local'">
      <q-markup-table v-if="paper.lines.length" flat dense class="ap-bill-lines">
        <thead>
          <tr>
            <th class="text-left">Description</th>
            <th class="text-right">Amount (BDT)</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(line, idx) in paper.lines" :key="idx">
            <td>{{ line.description }}</td>
            <td class="text-right font-mono">{{ formatAmountBdt(line.amount) }}</td>
          </tr>
        </tbody>
      </q-markup-table>
      <div v-else class="text-caption text-grey-6 q-py-sm">No line detail on file. Re-sync from shipment to refresh.</div>
      <div class="ap-bill-row text-weight-bold q-mt-md">
        <span>Total (BDT)</span>
        <span class="font-mono">{{ formatAmountBdt(paper.bdt_amount) }}</span>
      </div>
    </div>

    <div v-else class="text-caption text-grey-7 q-py-sm">
      Paper detail not saved yet. Update the bill from the shipment AP sync.
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { formatAmountBdt } from 'src/utils/currency';
import type { ApBillPaperSnapshot } from '../types/apBillPaper';
import { parseApBillPaper } from '../utils/parseApBillPaper';

const props = defineProps<{
  channelMeta?: Record<string, unknown> | null;
  apKind?: string | null;
  totalAmount?: number | null;
}>();

const paper = computed((): ApBillPaperSnapshot | null =>
  parseApBillPaper(props.channelMeta, props.apKind),
);

const formatForeign = (n: number) =>
  Number(n).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

const formatRate = (n: number) =>
  Number(n).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 4 });

const formatWeight = (n: number) => `${Number(n).toLocaleString(undefined, { maximumFractionDigits: 3 })} kg`;
</script>

<style scoped lang="scss">
.ap-bill-row {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  font-size: 13px;
}

.ap-bill-lines th {
  font-size: 11px;
  color: var(--bw-neutral-chrome, #64748b);
  font-weight: 600;
}
</style>
