<template>
  <q-markup-table flat bordered dense class="bill-adjustment-lines">
    <thead>
      <tr>
        <th class="text-left bill-adjustment-lines__desc-col">Description</th>
        <th class="text-right">Qty</th>
        <th class="text-right">Unit price ({{ currencyCodeLabel }})</th>
        <th class="text-right">Line total ({{ currencyCodeLabel }})</th>
        <th class="text-left bill-adjustment-lines__reason-col">Line reason</th>
        <th class="text-right" />
      </tr>
    </thead>
    <tbody>
      <tr v-for="row in rows" :key="row.key">
        <td class="bill-adjustment-lines__desc-col">
          <q-input
            v-model="row.name"
            dense
            outlined
            type="textarea"
            autogrow
            :rows="2"
            placeholder="What is being credited or adjusted"
            hide-bottom-space
          />
        </td>
        <td class="text-right">
          <q-input
            :model-value="row.quantity"
            dense
            outlined
            type="number"
            step="any"
            min="0.001"
            class="note-input note-input--qty"
            hide-bottom-space
            @update:model-value="(v) => onQuantityInput(row, v)"
          />
        </td>
        <td class="text-right">
          <q-input
            :model-value="row.unitPrice ?? ''"
            dense
            outlined
            type="number"
            step="any"
            min="0"
            class="note-input note-input--price"
            hide-bottom-space
            :placeholder="`0.00 ${currencyCodeLabel}`"
            @update:model-value="(v) => onUnitPriceInput(row, v)"
          />
        </td>
        <td class="text-right font-mono">
          {{ lineAmount(row) != null ? formatAmount(lineAmount(row)!) : '—' }}
        </td>
        <td class="bill-adjustment-lines__reason-col">
          <q-input
            v-model="row.reason"
            dense
            outlined
            type="textarea"
            autogrow
            :rows="2"
            placeholder="Why this line"
            hide-bottom-space
          />
        </td>
        <td class="text-right">
          <q-btn
            flat
            dense
            round
            icon="ph ph-trash"
            color="negative"
            :aria-label="`Remove line ${row.key}`"
            @click="emit('remove-line', row.key)"
          />
        </td>
      </tr>
    </tbody>
  </q-markup-table>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { formatSettlementCurrencyAmount } from 'src/utils/currency';
import {
  extraLineTotalFromDraftRow,
  type BillAdjustmentDraftRow,
} from '../utils/billAdjustmentParentLines';

const props = defineProps<{
  rows: BillAdjustmentDraftRow[];
  currencyCode: string;
  currencySymbol?: string | null;
}>();

const emit = defineEmits<{
  'line-sync': [row: BillAdjustmentDraftRow];
  'remove-line': [key: string];
}>();

function onQuantityInput(row: BillAdjustmentDraftRow, value: string | number | null) {
  if (value === '' || value === null || value === undefined) return;
  const n = typeof value === 'number' ? value : Number(String(value).trim());
  if (!Number.isFinite(n) || n <= 0) return;
  row.quantity = n;
  emit('line-sync', row);
}

function onUnitPriceInput(row: BillAdjustmentDraftRow, value: string | number | null) {
  if (value === '' || value === null || value === undefined) {
    row.unitPrice = null;
    row.amount = null;
    row.selected = false;
    emit('line-sync', row);
    return;
  }
  const n = typeof value === 'number' ? value : Number(String(value).trim());
  if (!Number.isFinite(n)) return;
  row.unitPrice = n > 0 ? n : null;
  emit('line-sync', row);
}

const currencyCodeLabel = computed(() => (props.currencyCode || 'BDT').toUpperCase());

function lineAmount(row: BillAdjustmentDraftRow): number | null {
  if (row.unitPrice != null && row.unitPrice > 0 && row.quantity > 0) {
    return extraLineTotalFromDraftRow(row);
  }
  return null;
}

function formatAmount(amount: number) {
  return formatSettlementCurrencyAmount(amount, props.currencyCode, props.currencySymbol);
}
</script>

<style scoped lang="scss">
.bill-adjustment-lines th {
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  color: var(--tf-neutral-chrome-text, #64748b);
}

.bill-adjustment-lines__desc-col,
.bill-adjustment-lines__reason-col {
  min-width: 160px;
  max-width: 240px;
}

.note-input {
  margin-left: auto;
}

.note-input--qty {
  max-width: 88px;
}

.note-input--price {
  max-width: 120px;
}
</style>