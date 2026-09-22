<template>
  <div class="column col overflow-hidden">
    <div v-if="loading" class="col row justify-center items-center">
      <q-spinner color="primary" size="3em" />
      <div class="text-grey-7 q-ml-md">Loading batch lines...</div>
    </div>

    <template v-else>
      <div class="row items-center q-gutter-x-sm q-px-xs q-pb-xs shrink-0">
        <q-btn
          color="primary"
          unelevated
          no-caps
          dense
          icon="ph ph-plus"
          label="Add line"
          class="rounded-sq-btn"
          style="border-radius: 8px"
          :loading="isAddingRow"
          @click="addDialogOpen = true"
        />
        <q-btn
          outline
          color="primary"
          no-caps
          dense
          icon="ph ph-upload-simple"
          label="Import"
          class="rounded-sq-btn"
          style="border-radius: 8px"
          :disable="isPasting"
          @click="importDialogOpen = true"
        />
        <q-btn
          v-if="selectedCount >= 2"
          flat
          no-caps
          dense
          color="negative"
          icon="ph ph-trash"
          :label="`Delete selected (${selectedCount})`"
          class="rounded-sq-btn"
          style="border-radius: 8px"
          :loading="isBulkDeleting"
          @click="onDeleteSelected"
        />
      </div>

      <div
        class="col batch-table-scroll hide-native-scrollbar batch-grid-wrap"
        @paste.capture="onGridPaste"
      >
        <q-inner-loading :showing="isPasting" label="Pasting rows..." />

        <q-markup-table flat class="shipment-items-markup-table bg-white batch-table">
          <thead class="batch-table-head">
            <tr>
              <th class="batch-col-select text-center">
                <q-checkbox
                  :model-value="allRowsSelected"
                  :disable="savedRows.length === 0"
                  dense
                  color="primary"
                  @update:model-value="onToggleSelectAll"
                />
              </th>
              <th class="batch-col-sl text-center">SL</th>
              <th
                v-for="col in EDITABLE_COLUMNS"
                :key="col.field"
                :class="col.align === 'center' ? 'text-center' : 'text-left'"
                class="batch-col-data"
              >
                <div class="batch-header-cell" :class="{ 'justify-center': col.align === 'center' }">
                  <span class="batch-header-label">{{ col.label }}</span>
                  <q-btn
                    flat
                    round
                    dense
                    size="xs"
                    icon="ph ph-clipboard-text"
                    color="primary"
                    class="batch-header-paste-btn"
                    :aria-label="`Paste ${col.label}`"
                    @click="openColumnPaste(col.field)"
                  >
                    <q-tooltip>Paste {{ col.label }}</q-tooltip>
                  </q-btn>
                </div>
              </th>
              <th class="batch-col-expires text-center bw-ops-col-tint--qty">Expires in</th>
              <th class="batch-col-arrived text-center">Arrived</th>
              <th class="batch-col-actions text-center" />
            </tr>
          </thead>
          <tbody>
            <tr v-if="savedRows.length === 0" class="batch-empty-row">
              <td class="text-center text-grey-5">—</td>
              <td class="text-center text-grey-5">—</td>
              <td :colspan="EDITABLE_COLUMNS.length + 3" class="text-grey-6 text-body2">
                No lines yet — Add line, Import CSV, or use a column Paste button in the header
              </td>
            </tr>

            <tr
              v-for="(item, index) in savedRows"
              :key="item.id"
              :class="batchExpiryRowClass(displayExpireDate(item.id, item.expire_date))"
            >
              <td class="text-center batch-col-select" @click.stop>
                <q-checkbox
                  :model-value="selectedIds.has(item.id)"
                  dense
                  color="primary"
                  @update:model-value="(val) => onToggleRow(item.id, val)"
                />
              </td>
              <td class="text-center font-mono text-weight-medium batch-col-sl">
                {{ index + 1 }}
              </td>
              <td
                v-for="col in EDITABLE_COLUMNS"
                :key="`${item.id}-${col.field}`"
                class="q-pa-none batch-col-data"
                :class="col.align === 'center' ? 'text-center' : 'text-left'"
                @click.stop
              >
                <div class="batch-cell">
                  <div class="batch-cell__label">{{ col.label }}</div>
                  <q-input
                    v-if="col.inputType === 'date'"
                    :model-value="getField({ kind: 'saved', id: item.id }, col.field)"
                    dense
                    borderless
                    clearable
                    mask="##-##-####"
                    placeholder="DD-MM-YYYY"
                    :input-class="col.inputClass"
                    class="excel-cell-input batch-date-input"
                    :loading="isRowSaving({ kind: 'saved', id: item.id })"
                    @focus="onCellFocus(index, col.field)"
                    @update:model-value="(val) => setField({ kind: 'saved', id: item.id }, col.field, val)"
                    @blur="() => commitRow({ kind: 'saved', id: item.id })"
                    @keydown.enter="(e: Event) => (e.target as HTMLInputElement).blur()"
                    @clear="onDateClear(item.id, col.field)"
                  >
                    <template #append>
                      <q-icon name="ph ph-calendar" class="cursor-pointer batch-date-icon">
                        <q-popup-proxy transition-show="scale" transition-hide="scale">
                          <q-date
                            :model-value="getField({ kind: 'saved', id: item.id }, col.field) || null"
                            mask="DD-MM-YYYY"
                            default-view="Years"
                            years-in-month-view
                            @update:model-value="(val) => onDateChange(item.id, col.field, val)"
                          >
                            <div class="row items-center justify-end q-pa-sm">
                              <q-btn v-close-popup label="Close" color="primary" flat dense />
                            </div>
                          </q-date>
                        </q-popup-proxy>
                      </q-icon>
                    </template>
                  </q-input>
                  <q-input
                    v-else
                    :model-value="getField({ kind: 'saved', id: item.id }, col.field)"
                    dense
                    borderless
                    :input-class="col.inputClass"
                    class="excel-cell-input"
                    :loading="isRowSaving({ kind: 'saved', id: item.id })"
                    @focus="onCellFocus(index, col.field)"
                    @update:model-value="(val) => setField({ kind: 'saved', id: item.id }, col.field, val)"
                    @blur="() => commitRow({ kind: 'saved', id: item.id })"
                    @keydown.enter="(e: Event) => (e.target as HTMLInputElement).blur()"
                  />
                </div>
              </td>
              <td class="text-center font-mono text-weight-bold batch-col-expires">
                <div class="batch-cell">
                  <div class="batch-cell__label">Expires in</div>
                  <span>{{ formatExpiresIn(displayExpireDate(item.id, item.expire_date)) }}</span>
                </div>
              </td>
              <td class="text-center batch-col-arrived" @click.stop>
                <div class="batch-cell">
                  <div class="batch-cell__label">Arrived</div>
                  <q-checkbox
                    :model-value="getIsArrived(item.id)"
                    dense
                    color="primary"
                    :disable="isRowSaving({ kind: 'saved', id: item.id })"
                    @update:model-value="(val) => toggleArrived(item.id, val)"
                  />
                </div>
              </td>
              <td class="text-center batch-col-actions">
                <q-btn
                  flat
                  round
                  dense
                  size="sm"
                  icon="ph ph-trash"
                  color="grey-7"
                  :disable="isRowSaving({ kind: 'saved', id: item.id })"
                  @click="deleteRow(item.id)"
                >
                  <q-tooltip>Delete line</q-tooltip>
                </q-btn>
              </td>
            </tr>
          </tbody>
        </q-markup-table>
      </div>

      <div class="shrink-0 bg-white border-top q-px-md q-py-sm">
        <div class="text-caption text-grey-6 text-center">
          {{ itemCount }} line<span v-if="itemCount !== 1">s</span>
          · scroll sideways on small screens · header Paste fills a column
        </div>
      </div>
    </template>

    <BatchCodeRowPasteDialog
      v-model="pasteDialogOpen"
      :start-row-index="pasteStartRowIndex"
      :total-rows="savedRows.length"
      :saving="isPasting"
      :initial-field="pasteField"
      :field-locked="pasteFieldLocked"
      @apply="onColumnPasteApply"
    />

    <BatchCodeAddItemDialog
      v-model="addDialogOpen"
      :saving="isAddingRow"
      @submit="onAddLineSubmit"
    />

    <BatchCodeCsvImportDialog
      v-model="importDialogOpen"
      :saving="isPasting"
      @apply="onCsvImportApply"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, ref, toRef, watch } from 'vue';
import { requestConfirmation, showSuccessNotification } from 'src/utils/appFeedback';
import { batchExpiryRowClass, formatExpiresIn } from '../utils/batchCodeExpiry';
import BatchCodeAddItemDialog from './BatchCodeAddItemDialog.vue';
import BatchCodeCsvImportDialog from './BatchCodeCsvImportDialog.vue';
import BatchCodeRowPasteDialog from './BatchCodeRowPasteDialog.vue';
import type { BatchCodePasteRow } from '../repositories/batchCodeRepository';
import { batchCodePasteRowsToMatrix } from '../utils/batchCodeCsv';
import {
  BATCH_CODE_FIELD_LABELS,
  BATCH_CODE_PASTE_FIELDS,
  parseBatchCodePasteMatrix,
  type BatchCodePasteField,
  useShipmentBatchCodeGrid,
} from '../composables/useShipmentBatchCodeGrid';

type EditableColumn = {
  field: BatchCodePasteField;
  label: string;
  align: 'left' | 'center';
  inputType?: 'date' | 'text';
  inputClass: string;
};

const EDITABLE_COLUMNS: EditableColumn[] = [
  {
    field: 'barcode',
    label: BATCH_CODE_FIELD_LABELS.barcode,
    align: 'left',
    inputClass: 'text-left font-mono text-weight-medium text-slate-800 excel-cell-input-native',
  },
  {
    field: 'product_code',
    label: BATCH_CODE_FIELD_LABELS.product_code,
    align: 'left',
    inputClass: 'text-left font-mono text-weight-medium text-slate-800 excel-cell-input-native',
  },
  {
    field: 'batch_id',
    label: BATCH_CODE_FIELD_LABELS.batch_id,
    align: 'left',
    inputClass: 'text-left font-mono text-weight-bold text-slate-800 excel-cell-input-native',
  },
  {
    field: 'manufacturing_date',
    label: BATCH_CODE_FIELD_LABELS.manufacturing_date,
    align: 'center',
    inputType: 'date',
    inputClass: 'text-center excel-cell-input-native',
  },
  {
    field: 'expire_date',
    label: BATCH_CODE_FIELD_LABELS.expire_date,
    align: 'center',
    inputType: 'date',
    inputClass: 'text-center excel-cell-input-native',
  },
];

const props = defineProps<{
  listId: number;
}>();

const {
  loading,
  savedRows,
  itemCount,
  getField,
  setField,
  commitRow,
  pasteGrid,
  pasteColumn,
  addLineFromDialog,
  deleteRow,
  deleteRows,
  getIsArrived,
  toggleArrived,
  isRowSaving,
  isAddingRow,
  isPasting,
  isBulkDeleting,
} = useShipmentBatchCodeGrid(toRef(props, 'listId'));

const selectedIds = ref<Set<number>>(new Set());

watch(
  savedRows,
  (rows) => {
    const valid = new Set(rows.map((row) => row.id));
    const next = new Set<number>();
    selectedIds.value.forEach((id) => {
      if (valid.has(id)) next.add(id);
    });
    selectedIds.value = next;
  },
  { deep: true },
);

const selectedCount = computed(() => selectedIds.value.size);

const allRowsSelected = computed(
  () => savedRows.value.length > 0 && savedRows.value.every((row) => selectedIds.value.has(row.id)),
);

const onToggleSelectAll = (checked: boolean) => {
  if (checked) {
    selectedIds.value = new Set(savedRows.value.map((row) => row.id));
  } else {
    selectedIds.value = new Set();
  }
};

const onToggleRow = (id: number, checked: boolean) => {
  const next = new Set(selectedIds.value);
  if (checked) next.add(id);
  else next.delete(id);
  selectedIds.value = next;
};

const onDeleteSelected = async () => {
  const ids = [...selectedIds.value];
  if (ids.length < 2 || isBulkDeleting.value) return;

  const ok = await requestConfirmation(
    `Delete ${ids.length} batch lines? This cannot be undone.`,
    'Delete selected lines',
    'Delete',
  );
  if (!ok) return;

  try {
    await deleteRows(ids);
    selectedIds.value = new Set();
    showSuccessNotification(`Deleted ${ids.length} lines.`);
  } catch {
    // toast from composable
  }
};

const focusedCell = ref({ rowIndex: 0, colIndex: 0 });
const addDialogOpen = ref(false);
const importDialogOpen = ref(false);
const pasteDialogOpen = ref(false);
const pasteStartRowIndex = ref(0);
const pasteField = ref<BatchCodePasteField>('product_code');
const pasteFieldLocked = ref(false);

const onCellFocus = (rowIndex: number, field: BatchCodePasteField) => {
  const colIndex = BATCH_CODE_PASTE_FIELDS.indexOf(field);
  if (colIndex >= 0) {
    focusedCell.value = { rowIndex, colIndex };
  }
};

const openColumnPaste = (field: BatchCodePasteField) => {
  pasteStartRowIndex.value = 0;
  pasteField.value = field;
  pasteFieldLocked.value = true;
  pasteDialogOpen.value = true;
};

const onColumnPasteApply = async (payload: { field: BatchCodePasteField; lines: string[] }) => {
  if (isPasting.value) return;
  await pasteColumn(pasteStartRowIndex.value, payload.field, payload.lines);
  pasteDialogOpen.value = false;
};

const onAddLineSubmit = async (payload: BatchCodePasteRow) => {
  if (isAddingRow.value) return;
  try {
    await addLineFromDialog(payload);
    addDialogOpen.value = false;
  } catch {
    // error toast handled in composable
  }
};

const onCsvImportApply = async (rows: BatchCodePasteRow[]) => {
  if (isPasting.value || rows.length === 0) return;
  const matrix = batchCodePasteRowsToMatrix(rows);
  await pasteGrid(savedRows.value.length, 0, matrix);
  importDialogOpen.value = false;
};

const onDateChange = async (itemId: number, field: BatchCodePasteField, value: string | null) => {
  setField({ kind: 'saved', id: itemId }, field, value);
  await commitRow({ kind: 'saved', id: itemId });
};

const onDateClear = async (itemId: number, field: BatchCodePasteField) => {
  setField({ kind: 'saved', id: itemId }, field, null);
  await commitRow({ kind: 'saved', id: itemId });
};

const onGridPaste = (event: ClipboardEvent) => {
  const text = event.clipboardData?.getData('text/plain');
  if (!text) return;

  const matrix = parseBatchCodePasteMatrix(text);
  if (matrix.length === 0) return;

  const isMultiCell = matrix.length > 1 || matrix.some((row) => row.length > 1);
  if (!isMultiCell) return;

  event.preventDefault();
  void pasteGrid(focusedCell.value.rowIndex, focusedCell.value.colIndex, matrix);
};

const displayExpireDate = (itemId: number, savedExpire: string | null): string | null => {
  const draft = getField({ kind: 'saved', id: itemId }, 'expire_date');
  return draft || savedExpire;
};

</script>

<style scoped>
.batch-grid-wrap {
  position: relative;
  min-width: 0;
}

.batch-table-scroll {
  overflow: auto;
  -webkit-overflow-scrolling: touch;
  width: 100%;
}

.batch-table {
  min-width: 920px;
  width: max(100%, 920px);
}

.hide-native-scrollbar {
  scrollbar-width: thin;
}

.hide-native-scrollbar::-webkit-scrollbar {
  height: 6px;
  width: 6px;
}

.hide-native-scrollbar::-webkit-scrollbar-thumb {
  background: rgba(15, 23, 42, 0.2);
  border-radius: 999px;
}

.batch-table-head th {
  position: sticky;
  top: 0;
  z-index: 3;
  background: #f8fafc !important;
  box-shadow: inset 0 -1px 0 rgba(15, 23, 42, 0.08);
}

.batch-col-select {
  width: 40px;
  min-width: 40px;
  position: sticky;
  left: 0;
  z-index: 2;
  background: #fff;
  box-shadow: 1px 0 0 rgba(15, 23, 42, 0.06);
}

.batch-table-head .batch-col-select {
  z-index: 4;
  background: #f8fafc !important;
}

.batch-col-sl {
  width: 48px;
  min-width: 48px;
  position: sticky;
  left: 40px;
  z-index: 2;
  background: #fff;
  box-shadow: 1px 0 0 rgba(15, 23, 42, 0.06);
}

.batch-table-head .batch-col-sl {
  z-index: 4;
  background: #f8fafc !important;
}

.batch-col-data {
  min-width: 112px;
}

.batch-col-expires {
  min-width: 96px;
}

.batch-col-arrived {
  width: 72px;
  min-width: 72px;
}

.batch-col-actions {
  width: 52px;
  min-width: 52px;
}

.batch-header-cell {
  display: flex;
  align-items: center;
  gap: 2px;
  min-height: 28px;
}

.batch-header-label {
  font-size: 12px;
  font-weight: 600;
  color: #475569;
  white-space: nowrap;
}

.batch-header-paste-btn {
  flex-shrink: 0;
}

.shipment-items-markup-table th,
.shipment-items-markup-table td {
  padding: 4px 6px !important;
  vertical-align: top;
}

.shipment-items-markup-table tbody td {
  height: 52px;
}

.shipment-items-markup-table th.bw-ops-col-tint--qty {
  background-color: #d0e6ff !important;
  box-shadow: inset 2px 0 0 #2563eb;
}

.batch-row--warn td {
  color: #b42318;
}

.batch-row--ok td {
  color: #047857;
}

.batch-row--unset td {
  color: #1d4ed8;
}

:deep(.batch-row--warn .q-field__native),
:deep(.batch-row--warn .excel-cell-input-native),
:deep(.batch-row--ok .q-field__native),
:deep(.batch-row--ok .excel-cell-input-native),
:deep(.batch-row--unset .q-field__native),
:deep(.batch-row--unset .excel-cell-input-native) {
  color: inherit !important;
}

:deep(.batch-row--warn .batch-date-icon),
:deep(.batch-row--ok .batch-date-icon),
:deep(.batch-row--unset .batch-date-icon) {
  color: inherit;
  opacity: 0.85;
}

.shipment-items-markup-table tbody tr:hover td {
  filter: brightness(0.98);
}

.batch-empty-row td {
  background-color: #f8fafc !important;
}

.batch-cell {
  min-height: 44px;
  padding: 2px 2px 0;
}

.batch-cell__label {
  display: none;
  font-size: 10px;
  font-weight: 600;
  letter-spacing: 0.03em;
  text-transform: uppercase;
  color: #94a3b8;
  line-height: 1.2;
  margin-bottom: 2px;
}

@media (max-width: 767px) {
  .batch-table {
    min-width: 100%;
    width: 100%;
  }

  .batch-col-data {
    min-width: 128px;
  }

  .batch-cell__label {
    display: block;
  }

  .batch-header-label {
    font-size: 11px;
  }
}

:deep(.excel-cell-input .q-field__control) {
  border-radius: 0 !important;
  border: none !important;
  background-color: transparent !important;
  transition: all 0.1s ease-in-out;
  min-height: 30px !important;
}

:deep(.excel-cell-input .q-field__control:before),
:deep(.excel-cell-input .q-field__control:after) {
  border: none !important;
}

:deep(.excel-cell-input:hover .q-field__control) {
  background-color: rgba(255, 255, 255, 0.4) !important;
}

:deep(.excel-cell-input.q-field--focused .q-field__control) {
  background-color: #ffffff !important;
  border: 1.5px solid #059669 !important;
  box-shadow: 0 0 0 1px #059669 !important;
}

:deep(.batch-date-input .q-field__append) {
  padding-left: 0;
}

.batch-date-icon {
  font-size: 14px;
  color: #64748b;
}
</style>
