<template>
  <AppResizableOverlayPanel
    :model-value="modelValue"
    storage-key="procurement.demand-buy-bulk-paste-width"
    :default-width="560"
    :min-width="400"
    :max-width="880"
    aria-label="Bulk paste demand vendor orders"
    @update:model-value="emit('update:modelValue', $event)"
  >
    <div class="bulk-paste-overlay column no-wrap full-height demand-buy-bulk-paste">
      <div
        class="bulk-paste-overlay__header row items-center justify-between q-px-md q-pt-md q-pb-sm shrink-0"
      >
        <div class="row items-center q-gutter-x-sm min-width-0">
          <q-avatar color="primary" text-color="white" icon="ph ph-clipboard-text" size="32px" />
          <div class="min-width-0">
            <div class="text-subtitle1 text-weight-bold text-grey-9">Bulk paste vendor orders</div>
            <div class="text-caption text-grey-6">
              Click a cell, then paste. Match by barcode and/or product code.
            </div>
          </div>
        </div>
        <q-btn
          icon="ph ph-x"
          flat
          round
          dense
          color="grey-6"
          aria-label="Close"
          :disable="saving"
          @click="close"
        />
      </div>

      <div class="q-px-md q-pb-sm shrink-0">
        <q-select
          :model-value="vendorCode"
          :options="vendorOptions"
          option-value="code"
          option-label="label"
          emit-value
          map-options
          outlined
          dense
          options-dense
          hide-bottom-space
          clearable
          label="Vendor for pasted rows"
          class="full-width"
          @update:model-value="emit('update:vendorCode', $event)"
        />
      </div>

      <div class="bulk-paste-overlay__body col q-px-md q-py-sm overflow-auto">
        <div class="bulk-paste-grid-wrap" @paste.capture="onGridPaste">
          <table class="bulk-paste-grid bulk-paste-grid--wide">
            <thead>
              <tr>
                <th v-for="col in gridColumns" :key="col">
                  {{ columnLabel(col) }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, rowIdx) in gridRows" :key="row.rowKey">
                <td v-for="(col, colIdx) in gridColumns" :key="col">
                  <input
                    :value="row[col]"
                    class="bulk-paste-cell"
                    :class="{ 'bulk-paste-cell--value': col !== 'barcode' && col !== 'product_code' }"
                    :data-row="rowIdx"
                    :data-col="colIdx"
                    @input="onCellInput(rowIdx, col, $event)"
                    @focus="onCellFocus(rowIdx, colIdx)"
                  />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="bulk-paste-overlay__footer row items-center justify-end q-gutter-sm q-pa-md shrink-0">
        <q-btn flat label="Cancel" color="grey-7" no-caps :disable="saving" @click="close" />
        <q-btn
          unelevated
          color="primary"
          icon="ph ph-check"
          label="Apply paste"
          no-caps
          class="rounded-borders q-px-md text-weight-bold"
          :loading="saving"
          :disable="saving || !vendorCode?.trim()"
          @click="onApply"
        />
      </div>
    </div>
  </AppResizableOverlayPanel>
</template>

<script setup lang="ts">
import { nextTick, ref, watch } from 'vue';
import AppResizableOverlayPanel from 'src/components/ui/AppResizableOverlayPanel.vue';
import type { DemandBuyBulkPasteRow } from '../utils/demandBuyBulkPaste';

type GridCol = keyof DemandBuyBulkPasteRow;

type GridRow = DemandBuyBulkPasteRow & { rowKey: string };

const gridColumns: GridCol[] = ['barcode', 'product_code', 'quantity', 'unit_price'];

const props = defineProps<{
  modelValue: boolean;
  vendorCode: string | null;
  vendorOptions: Array<{ code: string; label: string }>;
  saving?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  'update:vendorCode': [value: string | null];
  apply: [rows: DemandBuyBulkPasteRow[]];
}>();

const focus = ref({ row: 0, col: 0 });
const gridRows = ref<GridRow[]>([]);

const emptyRow = (index: number): GridRow => ({
  rowKey: `r-${index}`,
  barcode: '',
  product_code: '',
  quantity: '',
  unit_price: '',
});

const resetRows = () => {
  gridRows.value = Array.from({ length: 16 }, (_, i) => emptyRow(i));
  focus.value = { row: 0, col: 0 };
};

watch(
  () => props.modelValue,
  (open) => {
    if (open) {
      resetRows();
      void nextTick(() => {
        const el = document.querySelector(
          '.demand-buy-bulk-paste .bulk-paste-cell[data-row="0"][data-col="0"]',
        ) as HTMLInputElement | null;
        el?.focus();
      });
    }
  },
);

const columnLabel = (col: GridCol): string => {
  switch (col) {
    case 'barcode':
      return 'Barcode';
    case 'product_code':
      return 'Product code';
    case 'quantity':
      return 'Qty';
    case 'unit_price':
      return 'Unit £';
    default:
      return col;
  }
};

const onCellInput = (rowIdx: number, col: GridCol, event: Event) => {
  const value = (event.target as HTMLInputElement).value;
  const rows = gridRows.value.map((r, i) => (i === rowIdx ? { ...r, [col]: value } : r));
  gridRows.value = rows;
};

const onCellFocus = (row: number, col: number) => {
  focus.value = { row, col };
};

const looksLikeHeader = (cols: string[]) => {
  const joined = cols.join(' ').toLowerCase();
  return (
    joined.includes('barcode') ||
    joined.includes('product code') ||
    joined.includes('product_code') ||
    joined.includes('sku')
  );
};

const onGridPaste = (event: ClipboardEvent) => {
  const text = event.clipboardData?.getData('text/plain');
  if (!text) return;
  event.preventDefault();

  let pasted = text
    .split(/\r?\n/)
    .map((line) => line.split('\t').map((cell) => cell.trim()))
    .filter((cols) => cols.some((cell) => cell !== ''));
  if (pasted.length === 0) return;
  if (pasted[0] && looksLikeHeader(pasted[0])) {
    pasted = pasted.slice(1);
  }
  if (pasted.length === 0) return;

  const startRow = focus.value.row;
  const startCol = focus.value.col;
  const rows = [...gridRows.value];

  pasted.forEach((cols, rOffset) => {
    const rowIdx = startRow + rOffset;
    while (rowIdx >= rows.length) {
      rows.push(emptyRow(rows.length));
    }
    const row = rows[rowIdx];
    if (!row) return;
    cols.forEach((cell, cOffset) => {
      if (!cell.trim()) return;
      const colIdx = startCol + cOffset;
      const key = gridColumns[colIdx];
      if (!key) return;
      row[key] = cell;
    });
  });

  gridRows.value = rows;
};

const close = () => {
  emit('update:modelValue', false);
};

const onApply = () => {
  const rows: DemandBuyBulkPasteRow[] = gridRows.value.map((r) => ({
    barcode: r.barcode,
    product_code: r.product_code,
    quantity: r.quantity,
    unit_price: r.unit_price,
  }));
  emit('apply', rows);
};
</script>

<style scoped lang="scss">
.bulk-paste-overlay {
  min-height: 0;
  background: var(--tf-theme-surface, #fff);
}

.bulk-paste-overlay__footer {
  border-top: 1px solid #e2e8f0;
  background: #f8fafc;
}

.bulk-paste-overlay__body .bulk-paste-grid-wrap {
  max-height: none;
  min-height: 12rem;
}

.bulk-paste-grid-wrap {
  overflow: auto;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  background: #fff;
}

.bulk-paste-grid {
  width: 100%;
  border-collapse: collapse;
  table-layout: fixed;
}

.bulk-paste-grid--wide {
  table-layout: auto;
  min-width: 520px;
}

.bulk-paste-grid--wide th {
  white-space: nowrap;
  min-width: 88px;
}

.bulk-paste-grid th {
  position: sticky;
  top: 0;
  z-index: 1;
  background: #f8fafc;
  font-size: 11px;
  font-weight: 700;
  color: #475569;
  text-align: left;
  padding: 6px 8px;
  border-bottom: 1px solid #cbd5e1;
}

.bulk-paste-grid td {
  padding: 0;
  border-bottom: 1px solid #e2e8f0;
  border-right: 1px solid #e2e8f0;
}


.bulk-paste-grid td:last-child {
  border-right: none;
}

.bulk-paste-cell {
  width: 100%;
  height: 28px;
  border: none;
  outline: none;
  padding: 0 8px;
  font-size: 12px;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  background: #fff;
  color: #0f172a;
}

.bulk-paste-cell:focus {
  box-shadow: inset 0 0 0 2px var(--q-primary, #2563eb);
}

.bulk-paste-cell--value {
  text-align: right;
  font-variant-numeric: tabular-nums;
  font-weight: 700;
}
</style>