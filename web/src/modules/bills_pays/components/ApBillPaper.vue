<template>
  <div class="ap-bill-paper">
    <template v-if="linePaper">
      <div v-if="linePaper.weight_kg != null && linePaper.weight_kg > 0" class="ap-bill-row q-mb-sm">
        <span class="text-grey-7">Total weight</span>
        <span class="font-mono">{{ formatWeight(linePaper.weight_kg) }}</span>
      </div>

      <div
        v-for="(group, gIdx) in currencyGroups"
        :key="`${group.currency_code}-${gIdx}`"
        class="ap-bill-currency-group"
        :class="{ 'q-mt-md': gIdx > 0 }"
      >
        <div
          v-if="currencyGroups.length > 1"
          class="text-caption text-weight-bold text-grey-8 q-mb-xs text-uppercase"
          style="letter-spacing: 0.04em"
        >
          {{ group.currency_code }}
        </div>

        <q-markup-table v-if="group.lines.length" flat dense class="ap-bill-lines">
          <thead>
            <tr>
              <th class="text-left">Description</th>
              <th class="text-right">Amount</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(line, idx) in group.lines" :key="idx">
              <td>{{ line.description }}</td>
              <td class="text-right font-mono">{{ formatLineAmount(line, group) }}</td>
            </tr>
          </tbody>
        </q-markup-table>

        <div class="ap-bill-row text-weight-bold q-mt-sm">
          <span>Total ({{ group.currency_code }})</span>
          <span class="font-mono">{{ formatGroupTotal(group) }}</span>
        </div>
      </div>

      <div v-if="currencyGroups.length === 0" class="text-caption text-grey-6 q-py-sm">
        No line detail on file. Re-sync from shipment to refresh.
      </div>

      <div v-if="showLegacyConversion(linePaper)" class="ap-bill-row q-mt-sm">
        <span class="text-grey-7">Conversion rate</span>
        <span class="font-mono">{{ formatRate(linePaper.conversion_rate!) }}</span>
      </div>
      <div v-if="showLegacyBdtDue(linePaper)" class="ap-bill-row text-weight-bold">
        <span>Amount (BDT)</span>
        <span class="font-mono">{{ formatAmountBdt(linePaper.bdt_amount) }}</span>
      </div>
    </template>

    <div
      v-else-if="paper?.paper === 'vendor' || paper?.paper === 'material'"
      class="column q-gutter-y-sm"
    >
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

    <div
      v-else-if="paper?.paper === 'cargo' || paper?.paper === 'freight'"
      class="column q-gutter-y-sm"
    >
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

    <div v-else class="text-caption text-grey-7 q-py-sm">
      Paper detail not saved yet. Update the bill from the shipment AP sync.
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { formatAmountBdt } from 'src/utils/currency';
import type {
  ApBillPaperCurrencyGroup,
  ApBillPaperLine,
  ApBillPaperSnapshot,
  ApBillPaperBucketLines,
} from '../types/apBillPaper';
import { apBillCurrencyGroups, parseApBillPaper } from '../utils/parseApBillPaper';

const props = defineProps<{
  channelMeta?: Record<string, unknown> | null;
  apKind?: string | null;
  totalAmount?: number | null;
}>();

const paper = computed((): ApBillPaperSnapshot | null =>
  parseApBillPaper(props.channelMeta, props.apKind),
);

const linePaper = computed((): ApBillPaperBucketLines | null => {
  const p = paper.value;
  if (!p || !('lines' in p) || !Array.isArray(p.lines)) return null;
  return p as ApBillPaperBucketLines;
});

const currencyGroups = computed(() => apBillCurrencyGroups(props.channelMeta));

const formatForeign = (n: number) =>
  Number(n).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });

const formatRate = (n: number) =>
  Number(n).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 4 });

const formatWeight = (n: number) => `${Number(n).toLocaleString(undefined, { maximumFractionDigits: 3 })} kg`;

const formatLineAmount = (line: ApBillPaperLine, group: ApBillPaperCurrencyGroup) => {
  const sym = line.currency_symbol || group.currency_symbol || '';
  const formatted = formatForeign(line.amount);
  return sym ? `${sym}${formatted}` : formatted;
};

const formatGroupTotal = (group: ApBillPaperCurrencyGroup) => {
  const sym = group.currency_symbol || '';
  const formatted = formatForeign(group.foreign_total);
  return sym ? `${sym}${formatted}` : formatted;
};

/** FX on paper only for legacy snapshots or after payout stamped a rate. */
const showLegacyConversion = (p: ApBillPaperBucketLines) => {
  const rate = p.conversion_rate;
  if (rate == null || rate <= 0) return false;
  if (Math.abs(rate - 1) < 0.0001 && (p.currency_code === 'BDT' || !p.currency_code)) return false;
  const foreign = p.foreign_total ?? 0;
  const bdt = p.bdt_amount ?? 0;
  return foreign > 0 && bdt > 0 && Math.abs(foreign - bdt) > 0.01;
};

const showLegacyBdtDue = (p: ApBillPaperBucketLines) => showLegacyConversion(p);
</script>

<style scoped lang="scss">
.ap-bill-row {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  font-size: 13px;
}

.ap-bill-currency-group + .ap-bill-currency-group {
  padding-top: 0.5rem;
  border-top: 1px solid var(--bw-neutral-border, #e2e8f0);
}

.ap-bill-lines th {
  font-size: 11px;
  color: var(--bw-neutral-chrome, #64748b);
  font-weight: 600;
}
</style>
