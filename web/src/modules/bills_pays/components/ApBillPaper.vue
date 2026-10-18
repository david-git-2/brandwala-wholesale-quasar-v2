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
              <th v-if="noteEditMode" class="text-right note-amount-col">
                Revised ({{ group.currency_code || 'BDT' }})
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(line, lineIdx) in group.lines" :key="lineIdx">
              <td>{{ line.description }}</td>
              <td class="text-right font-mono">
                {{ formatDraftOrLineAmount(gIdx, lineIdx, line, group) }}
              </td>
              <td v-if="noteEditMode" class="text-right note-amount-col">
                <q-input
                  v-if="draftForApLine(gIdx, lineIdx)"
                  :model-value="draftForApLine(gIdx, lineIdx)!.revisedAmount"
                  dense
                  outlined
                  type="number"
                  step="0.01"
                  min="0"
                  class="note-amount-input"
                  :placeholder="formatForeign(draftForApLine(gIdx, lineIdx)?.maxAmount ?? line.amount)"
                  @update:model-value="
                    (v) => onNoteAmount(draftForApLine(gIdx, lineIdx)!, v as number | null)
                  "
                />
              </td>
            </tr>
            <tr v-for="row in extraRowsForGroup(group.currency_code)" :key="row.key">
              <td>
                <q-input v-model="row.name" dense outlined placeholder="Description" />
              </td>
              <td />
              <td v-if="noteEditMode" class="text-right note-amount-col">
                <q-input
                  :model-value="row.amount"
                  dense
                  outlined
                  type="number"
                  step="0.01"
                  min="0"
                  class="note-amount-input"
                  placeholder="0"
                  @update:model-value="(v) => onNoteAmount(row, v as number | null)"
                />
              </td>
            </tr>
          </tbody>
          <tfoot v-if="noteEditMode">
            <tr class="text-weight-bold">
              <td>Total</td>
              <td class="text-right font-mono">{{ formatGroupTotal(group) }}</td>
              <td class="text-right font-mono">{{ formatNoteGroupTotal(group, gIdx) }}</td>
            </tr>
          </tfoot>
        </q-markup-table>

        <div v-if="noteEditMode" class="q-mt-xs">
          <q-btn
            flat
            dense
            no-caps
            color="primary"
            icon="ph ph-plus"
            label="Add line"
            @click="emit('add-extra-line', (group.currency_code || 'BDT').toUpperCase())"
          />
        </div>

        <div v-if="!noteEditMode" class="ap-bill-row text-weight-bold q-mt-sm">
          <span>Total ({{ group.currency_code }})</span>
          <span class="font-mono">{{ formatGroupTotal(group) }}</span>
        </div>
      </div>

      <div v-if="currencyGroups.length === 0" class="text-caption text-grey-6 q-py-sm">
        No line detail on file. Re-sync from shipment to refresh.
      </div>

      <div
        v-if="noteEditMode && apTotalDraft"
        class="row items-center q-gutter-sm q-mt-sm"
      >
        <span class="text-body2">{{ apTotalDraft.name }}</span>
        <q-input
          :model-value="apTotalDraft.revisedAmount"
          dense
          outlined
          type="number"
          step="0.01"
          :label="`Revised (${apTotalDraft.currencyCode})`"
          :placeholder="
            apTotalDraft.maxAmount != null ? formatForeign(apTotalDraft.maxAmount) : '0'
          "
          class="note-amount-input"
          @update:model-value="(v) => onNoteAmount(apTotalDraft!, v as number | null)"
        />
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
import type { BillAdjustmentDraftRow } from '../utils/billAdjustmentParentLines';
import { apLineDraftKey, parseNoteInputAmount } from '../utils/billAdjustmentParentLines';

const props = defineProps<{
  channelMeta?: Record<string, unknown> | null;
  apKind?: string | null;
  totalAmount?: number | null;
  noteEditMode?: boolean;
  draftRows?: BillAdjustmentDraftRow[];
}>();

const emit = defineEmits<{
  'add-extra-line': [currencyCode: string];
  'note-amount': [row: BillAdjustmentDraftRow, value: number | null];
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

const apTotalDraft = computed(() => props.draftRows?.find((r) => r.key === 'ap-total'));

function draftForApLine(groupIdx: number, lineIdx: number) {
  const key = apLineDraftKey(groupIdx, lineIdx);
  return props.draftRows?.find((r) => r.key === key);
}

function extraRowsForGroup(currencyCode: string) {
  const code = (currencyCode || 'BDT').toUpperCase();
  return (props.draftRows ?? []).filter(
    (r) => r.isExtra && r.currencyCode.toUpperCase() === code,
  );
}

function onNoteAmount(row: BillAdjustmentDraftRow, value: number | null) {
  emit('note-amount', row, value);
}

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

function formatDraftOrLineAmount(
  gIdx: number,
  lineIdx: number,
  line: ApBillPaperLine,
  group: ApBillPaperCurrencyGroup,
) {
  const d = draftForApLine(gIdx, lineIdx);
  if (props.noteEditMode && d?.maxAmount != null) {
    const rem = d.maxAmount;
    const orig = Number(d.originalAmount ?? line.amount);
    const formatted = formatForeign(rem);
    const prefix = orig > rem + 0.001 ? 'left ' : '';
    const sym = line.currency_symbol || group.currency_symbol || '';
    return prefix + (sym ? `${sym}${formatted}` : formatted);
  }
  return formatLineAmount(line, group);
}

function groupInvoiceTotal(group: ApBillPaperCurrencyGroup): number {
  const ft = Number(group.foreign_total);
  if (Number.isFinite(ft) && ft > 0) return ft;
  return (group.lines ?? []).reduce((sum, line) => sum + (Number(line.amount) || 0), 0);
}

const formatGroupTotal = (group: ApBillPaperCurrencyGroup) => {
  const sym = group.currency_symbol || '';
  const formatted = formatForeign(groupInvoiceTotal(group));
  return sym ? `${sym}${formatted}` : formatted;
};

function noteSumForGroup(gIdx: number, group: ApBillPaperCurrencyGroup): number {
  let sum = 0;
  const groupLines = group.lines ?? [];
  for (let lineIdx = 0; lineIdx < groupLines.length; lineIdx++) {
    const line = groupLines[lineIdx];
    const d = draftForApLine(gIdx, lineIdx);
    const revised = d?.revisedAmount;
    if (revised != null && Number.isFinite(revised)) sum += revised;
    else sum += Number(d?.maxAmount ?? line.amount) || 0;
  }
  for (const row of extraRowsForGroup(group.currency_code)) {
    const amt = parseNoteInputAmount(row.amount);
    if (amt != null) sum += amt;
  }
  return sum;
}

const formatNoteGroupTotal = (group: ApBillPaperCurrencyGroup, gIdx: number) => {
  const sym = group.currency_symbol || '';
  const formatted = formatForeign(noteSumForGroup(gIdx, group));
  return sym ? `${sym}${formatted}` : formatted;
};

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
  border-top: 1px solid var(--tf-neutral-border, #e2e8f0);
}

.ap-bill-lines th {
  font-size: 11px;
  color: var(--tf-neutral-chrome, #64748b);
  font-weight: 600;
}

.note-amount-col {
  min-width: 120px;
}

.note-amount-input {
  max-width: 120px;
  margin-left: auto;
}
</style>
