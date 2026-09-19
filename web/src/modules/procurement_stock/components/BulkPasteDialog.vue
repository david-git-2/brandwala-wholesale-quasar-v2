<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide" persistent>
    <q-card class="q-dialog-plugin column no-wrap modern-dialog" style="width: 820px; max-width: 95vw; max-height: 90vh; border-radius: 12px">
      <!-- Header -->
      <q-card-section class="row items-center q-px-lg q-py-md col-auto border-bottom-subtle">
        <div class="row items-center q-gutter-x-sm">
          <q-avatar size="32px" color="grey-2" text-color="grey-9" font-size="18px" icon="ph ph-clipboard-text" square style="border-radius: 6px" />
          <div>
            <div class="text-h6 text-weight-bold text-dark" style="color: #0f172a; line-height: 1.2">Bulk Paste Shipment Updates</div>
            <div class="text-caption text-grey-7">Copy table rows from Excel or Google Sheets to batch update shipment items</div>
          </div>
        </div>
        <q-space />
        <q-btn icon="ph ph-x" flat round dense color="grey-7" v-close-popup />
      </q-card-section>

      <!-- Main Body -->
      <q-card-section class="q-pa-lg q-gutter-y-md col scroll">
        <!-- Modern Instruction Banner -->
        <div class="instruction-box q-pa-md row items-start no-wrap q-gutter-x-md">
          <q-icon name="ph ph-info" size="20px" class="q-mt-xs text-dark" style="color: #0f172a" />
          <div class="text-body2 text-dark" style="color: #1e293b; line-height: 1.5">
            Paste from Excel or Sheets. Map a <strong>Barcode</strong> or <strong>Product code</strong> column to update the matching line, even if rows are out of order. With no key column, values apply from top to bottom.
          </div>
        </div>

        <!-- Step 1: Text Area for pasting -->
        <div v-if="!parsedRows.length" class="paste-input-container">
          <q-input
            v-model="rawPasteText"
            type="textarea"
            outlined
            rows="10"
            placeholder="Paste your copied Excel or Sheets rows here (Ctrl+V / Cmd+V)..."
            class="modern-paste-textarea"
            @update:model-value="onPasteUpdate"
          />
        </div>

        <!-- Step 2: Mapping & Preview -->
        <div v-else class="column q-gutter-y-md">
          <div class="row justify-between items-center q-px-xs">
            <div class="text-subtitle2 text-weight-bold text-dark" style="color: #0f172a">
              Parsed {{ parsedRows.length }} rows with {{ maxColumns }} columns
            </div>
            <q-btn
              flat
              no-caps
              dense
              color="primary"
              label="Clear & Paste Again"
              icon="ph ph-arrows-clockwise"
              class="text-weight-medium"
              @click="resetPaste"
            />
          </div>

          <!-- Section Selector & Column Header Mappings Selector -->
          <div class="mapping-box q-pa-md rounded-borders column q-gutter-y-sm">
            <div v-if="sectionOptions.length > 0" class="row items-center q-col-gutter-sm">
              <div class="col-12 col-sm-6">
                <q-select
                  v-model="targetSectionId"
                  :options="sectionOptions"
                  label="Target Vendor Section"
                  outlined
                  dense
                  bg-color="white"
                  emit-value
                  map-options
                >
                  <template #prepend>
                    <q-icon name="ph ph-folder" size="18px" color="grey-7" />
                  </template>
                </q-select>
              </div>
              <div class="col-12 col-sm-6 text-caption text-dark text-weight-medium" style="color: #334155">
                Items will be filtered or assigned to this section.
              </div>
            </div>

            <div class="text-caption text-weight-bold text-dark q-mt-xs" style="color: #0f172a">
              Map columns. Use Barcode or Product code when rows are not in sheet order.
            </div>
            <div class="row q-col-gutter-sm">
              <div v-for="colIdx in maxColumns" :key="colIdx" class="col-12 col-sm-3">
                <q-select
                  v-model="colMappings[colIdx - 1]"
                  :options="mappingOptions"
                  :label="`Column ${colIdx}`"
                  outlined
                  dense
                  bg-color="white"
                  emit-value
                  map-options
                />
              </div>
            </div>
          </div>

          <!-- Preview Table -->
          <div class="row items-center justify-between q-mt-sm">
            <div class="text-subtitle2 text-weight-bold text-dark" style="color: #0f172a">Preview Matches & Updates</div>
            <div class="text-caption text-grey-7">{{ previewRows.length }} items shown</div>
          </div>

          <q-markup-table flat bordered dense class="preview-table">
            <thead>
              <tr>
                <th class="text-left" style="width: 50px">SL</th>
                <th class="text-left">Shipment Product</th>
                <th class="text-left" style="width: 88px">Match</th>
                <th v-for="colIdx in maxColumns" :key="colIdx" class="text-center">
                  {{ getColumnLabel(colMappings[colIdx - 1]) }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in previewRows" :key="row.rowKey">
                <td class="text-left text-dark text-weight-medium" style="color: #475569">{{ row.sl }}</td>
                <td class="text-left text-weight-medium ellipsis text-dark" style="max-width: 260px; color: #0f172a">
                  <div>{{ row.item?.name || 'No match' }}</div>
                  <div v-if="row.item" class="text-caption text-grey-7">
                    Current: Qty {{ row.item.ordered_quantity }} · Price £{{ row.item.purchase_price }} · Wt
                    {{ row.item.product_weight }}g · Pkg Wt {{ row.item.package_weight }}g
                  </div>
                  <div v-else class="text-caption text-grey-7">{{ row.matchHint }}</div>
                </td>
                <td class="text-left text-caption text-weight-bold" :class="row.matchClass">
                  {{ row.matchLabel }}
                </td>
                <td v-for="colIdx in maxColumns" :key="colIdx" class="text-center font-mono">
                  <template v-if="getPastedValueForCell(row.pasteIndex, colIdx - 1) !== null">
                    <span class="text-weight-bolder text-dark" style="color: #0f172a; font-size: 13px">
                      {{
                        formatPreviewValue(
                          getPastedValueForCell(row.pasteIndex, colIdx - 1),
                          colMappings[colIdx - 1],
                        )
                      }}
                    </span>
                  </template>
                  <template v-else>
                    <span class="text-grey-4">—</span>
                  </template>
                </td>
              </tr>
              <tr v-if="previewFooter" class="bg-amber-1">
                <td
                  :colspan="maxColumns + 3"
                  class="text-center text-amber-10 text-caption text-weight-bold q-py-sm"
                  style="color: #78350f"
                >
                  <q-icon name="ph ph-warning" size="16px" class="q-mr-xs" />
                  {{ previewFooter }}
                </td>
              </tr>
            </tbody>
          </q-markup-table>
        </div>
      </q-card-section>

      <!-- Footer Actions -->
      <q-card-actions align="right" class="q-px-lg q-py-md bg-grey-1 col-auto border-top-subtle">
        <q-btn flat label="Cancel" color="grey-8" v-close-popup no-caps />
        <q-btn
          color="primary"
          unelevated
          label="Apply Updates"
          :disable="!parsedRows.length || !hasValueMappings || applyCount === 0"
          :loading="submitting"
          no-caps
          class="rounded-sq-btn"
          style="border-radius: 8px; font-weight: 600"
          @click="onApply"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useDialogPluginComponent } from 'quasar';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import type { GlobalShipmentItem } from '../repositories/globalShipmentRepository';

const props = defineProps<{
  initialSectionId?: number | null;
}>();

defineEmits([...useDialogPluginComponent.emits]);

const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent();
const shipmentStore = useGlobalShipmentStore();

const targetSectionId = ref<number | null>(props.initialSectionId ?? null);

const sectionOptions = computed(() => {
  const sections = shipmentStore.currentShipmentSections ?? [];
  return [
    { label: 'All Sections (Sequential across shipment)', value: null },
    ...sections.map((s) => ({
      label: s.vendor?.name ? `${s.title} (${s.vendor.name})` : s.title,
      value: s.id,
    })),
  ];
});

const submitting = ref(false);
const rawPasteText = ref('');
const parsedRows = ref<Array<string[]>>([]);
const maxColumns = ref(0);
const colMappings = ref<string[]>([]);

const currentItems = computed(() => {
  const all = shipmentStore.currentShipmentItems ?? [];
  if (targetSectionId.value == null) return all;
  const firstSectionId = shipmentStore.currentShipmentSections[0]?.id ?? null;
  return all.filter(
    (item) =>
      item.section_id === targetSectionId.value ||
      (item.section_id == null && targetSectionId.value === firstSectionId),
  );
});

const KEY_FIELDS = ['barcode', 'product_code'] as const;
const VALUE_FIELDS = ['ordered_quantity', 'purchase_price', 'product_weight', 'package_weight'] as const;

type PreviewRow = {
  rowKey: string;
  pasteIndex: number;
  sl: number;
  item: GlobalShipmentItem | null;
  matchLabel: string;
  matchClass: string;
  matchHint: string;
  canApply: boolean;
};

const mappingOptions = [
  { label: 'Ignore', value: 'ignore' },
  { label: 'Barcode (match)', value: 'barcode' },
  { label: 'Product code (match)', value: 'product_code' },
  { label: 'Quantity', value: 'ordered_quantity' },
  { label: 'Price (£)', value: 'purchase_price' },
  { label: 'Product Weight (g)', value: 'product_weight' },
  { label: 'Package Weight (g)', value: 'package_weight' },
];

const getColumnLabel = (mapping?: string) => {
  return mappingOptions.find((opt) => opt.value === mapping)?.label || 'Ignore';
};

const hasValueMappings = computed(() =>
  colMappings.value.some((mapping) => VALUE_FIELDS.includes(mapping as (typeof VALUE_FIELDS)[number])),
);

const usesKeyMatch = computed(() =>
  colMappings.value.some((mapping) => KEY_FIELDS.includes(mapping as (typeof KEY_FIELDS)[number])),
);

const normalizeKey = (value: string | null | undefined): string => {
  if (!value) return '';
  return value.trim().replace(/^['`]+/, '').replace(/\s+/g, '').toLowerCase();
};

const looksNumeric = (value: string): boolean => {
  const cleaned = value.replace(/[^0-9.-]/g, '');
  if (cleaned === '' || cleaned === '-' || cleaned === '.') return false;
  return !Number.isNaN(Number(cleaned));
};

const guessHeaderMapping = (cell: string): string | null => {
  const n = cell.trim().toLowerCase().replace(/[_-]+/g, ' ');
  if (['barcode', 'bar code', 'ean', 'upc'].includes(n)) return 'barcode';
  if (['product code', 'productcode', 'sku', 'code', 'style', 'style code'].includes(n)) {
    return 'product_code';
  }
  if (['qty', 'quantity', 'pcs', 'ordered quantity'].includes(n)) return 'ordered_quantity';
  if (['price', 'gbp', 'cost', 'unit price', 'purchase price'].includes(n)) return 'purchase_price';
  if (['product weight', 'weight', 'wt', 'item weight'].includes(n)) return 'product_weight';
  if (['package weight', 'pkg weight', 'pkg', 'carton weight'].includes(n)) return 'package_weight';
  return null;
};

const guessColumnMappings = (rows: string[][], colCount: number): string[] => {
  const first = rows[0] ?? [];
  const headerGuess = first.map((cell) => guessHeaderMapping(cell));
  if (headerGuess.some((g) => g != null)) {
    return Array.from({ length: colCount }, (_, idx) => headerGuess[idx] || 'ignore');
  }

  const valueQueue = [...VALUE_FIELDS];
  let usedBarcode = false;
  let usedProductCode = false;

  return Array.from({ length: colCount }, (_, idx) => {
    const samples = rows
      .slice(0, 8)
      .map((row) => row[idx] ?? '')
      .filter((cell) => cell !== '');
    const numericCount = samples.filter((cell) => looksNumeric(cell)).length;
    const isKeyish = samples.length > 0 && numericCount < samples.length / 2;

    if (isKeyish && !usedBarcode) {
      usedBarcode = true;
      return 'barcode';
    }
    if (isKeyish && !usedProductCode) {
      usedProductCode = true;
      return 'product_code';
    }
    return valueQueue.shift() || 'ignore';
  });
};

const buildKeyIndex = (field: 'barcode' | 'product_code') => {
  const map = new Map<string, GlobalShipmentItem[]>();
  for (const item of currentItems.value) {
    const key = normalizeKey(item[field]);
    if (!key) continue;
    const list = map.get(key) ?? [];
    list.push(item);
    map.set(key, list);
  }
  return map;
};

const payloadFromRow = (row: string[]): Record<string, number> => {
  const payload: Record<string, number> = {};
  colMappings.value.forEach((mapping, colIdx) => {
    if (!VALUE_FIELDS.includes(mapping as (typeof VALUE_FIELDS)[number]) || colIdx >= row.length) return;
    const cellVal = row[colIdx];
    if (cellVal === undefined || cellVal === '') return;
    const cleaned = cellVal.replace(/[^0-9.-]/g, '');
    if (cleaned === '') return;
    const numVal = Number(cleaned);
    if (Number.isNaN(numVal)) return;
    if (mapping === 'ordered_quantity') {
      payload[mapping] = Math.max(1, Math.floor(numVal));
    } else if (mapping === 'purchase_price' || mapping === 'product_weight' || mapping === 'package_weight') {
      payload[mapping] = Math.max(0, numVal);
    }
  });
  return payload;
};

const resolveRowItem = (
  row: string[],
  barcodeIndex: Map<string, GlobalShipmentItem[]>,
  productCodeIndex: Map<string, GlobalShipmentItem[]>,
): { item: GlobalShipmentItem | null; status: 'matched' | 'unmatched' | 'duplicate' } => {
  const barcodeCol = colMappings.value.indexOf('barcode');
  const productCodeCol = colMappings.value.indexOf('product_code');

  const lookup = (field: 'barcode' | 'product_code', col: number) => {
    if (col < 0) return null;
    const key = normalizeKey(row[col] ?? '');
    if (!key) return null;
    const hits = field === 'barcode' ? barcodeIndex.get(key) : productCodeIndex.get(key);
    if (!hits || hits.length === 0) return { item: null, status: 'unmatched' as const };
    if (hits.length > 1) return { item: null, status: 'duplicate' as const };
    return { item: hits[0] ?? null, status: 'matched' as const };
  };

  const byBarcode = lookup('barcode', barcodeCol);
  if (byBarcode) return byBarcode;
  const byCode = lookup('product_code', productCodeCol);
  if (byCode) return byCode;
  return { item: null, status: 'unmatched' };
};

const previewRows = computed((): PreviewRow[] => {
  const barcodeIndex = buildKeyIndex('barcode');
  const productCodeIndex = buildKeyIndex('product_code');
  const usedIds = new Set<number>();

  if (usesKeyMatch.value) {
    return parsedRows.value.map((row, index) => {
      const resolved = resolveRowItem(row, barcodeIndex, productCodeIndex);
      let status = resolved.status;
      let item = resolved.item;
      if (item && usedIds.has(item.id)) {
        status = 'duplicate';
        item = null;
      } else if (item) {
        usedIds.add(item.id);
      }

      const canApply = status === 'matched' && item != null && Object.keys(payloadFromRow(row)).length > 0;
      const matchLabel =
        status === 'matched' ? 'Matched' : status === 'duplicate' ? 'Duplicate' : 'Unmatched';
      const matchClass =
        status === 'matched' ? 'text-positive' : status === 'duplicate' ? 'text-amber-9' : 'text-negative';

      return {
        rowKey: `paste-${index}`,
        pasteIndex: index,
        sl: index + 1,
        item,
        matchLabel,
        matchClass,
        matchHint:
          status === 'duplicate'
            ? 'This code matches more than one line, or was already used in this paste.'
            : 'No shipment line has this barcode or product code.',
        canApply,
      };
    });
  }

  const limit = Math.max(parsedRows.value.length, currentItems.value.length);
  const rows: PreviewRow[] = [];
  for (let i = 0; i < limit; i++) {
    const item = currentItems.value[i] ?? null;
    const row = parsedRows.value[i];
    const canApply = !!item && !!row && Object.keys(payloadFromRow(row)).length > 0;
    rows.push({
      rowKey: `order-${item?.id ?? 'x'}-${i}`,
      pasteIndex: i,
      sl: i + 1,
      item,
      matchLabel: item && row ? 'In order' : item ? 'No paste' : 'Extra paste',
      matchClass: item && row ? 'text-grey-7' : 'text-amber-9',
      matchHint: item ? '' : 'No shipment line at this position.',
      canApply,
    });
  }
  return rows;
});

const applyCount = computed(() => previewRows.value.filter((row) => row.canApply).length);

const previewFooter = computed(() => {
  if (usesKeyMatch.value) {
    const unmatched = previewRows.value.filter((row) => row.matchLabel === 'Unmatched').length;
    const duplicate = previewRows.value.filter((row) => row.matchLabel === 'Duplicate').length;
    const parts: string[] = [];
    if (unmatched) parts.push(`${unmatched} unmatched`);
    if (duplicate) parts.push(`${duplicate} duplicate`);
    if (parts.length === 0) return '';
    return `${parts.join(', ')}. Those rows will not be updated.`;
  }
  if (parsedRows.value.length === currentItems.value.length) return '';
  if (parsedRows.value.length > currentItems.value.length) {
    return `You pasted ${parsedRows.value.length} rows, but this list has ${currentItems.value.length} items. Extra rows will be ignored.`;
  }
  return `You pasted ${parsedRows.value.length} rows, but this list has ${currentItems.value.length} items. Remaining items will not be updated.`;
});

const onPasteUpdate = (val: string | number | null) => {
  if (!val) {
    parsedRows.value = [];
    maxColumns.value = 0;
    return;
  }

  const valStr = String(val);
  const rows = valStr.split(/\r?\n/);
  const data: Array<string[]> = [];
  let maxCols = 0;

  for (const row of rows) {
    if (row.trim() === '') continue;
    const cols = row.split('\t').map((c) => c.trim());
    data.push(cols);
    if (cols.length > maxCols) {
      maxCols = cols.length;
    }
  }

  const headerGuess = (data[0] ?? []).map((cell) => guessHeaderMapping(cell));
  const hasHeaderRow = headerGuess.some((g) => g != null);
  const body = hasHeaderRow ? data.slice(1) : data;
  parsedRows.value = body;
  maxColumns.value = maxCols;
  colMappings.value = hasHeaderRow
    ? Array.from({ length: maxCols }, (_, idx) => headerGuess[idx] || 'ignore')
    : guessColumnMappings(body, maxCols);
};

const resetPaste = () => {
  rawPasteText.value = '';
  parsedRows.value = [];
  maxColumns.value = 0;
  colMappings.value = [];
};

const getPastedValueForCell = (rowIdx: number, colIdx: number): string | null => {
  if (rowIdx >= parsedRows.value.length) return null;
  const row = parsedRows.value[rowIdx];
  if (!row) return null;
  return colIdx < row.length ? (row[colIdx] ?? null) : null;
};

const formatPreviewValue = (val: string | null, mapping?: string): string => {
  if (!mapping || mapping === 'ignore' || KEY_FIELDS.includes(mapping as (typeof KEY_FIELDS)[number])) {
    return val || '';
  }
  if (val === null || val === '') return val || '';
  const num = Number(val.replace(/[^0-9.-]/g, ''));
  if (Number.isNaN(num)) return val;

  if (mapping === 'ordered_quantity') {
    return `${Math.floor(num)} pcs`;
  }
  if (mapping === 'purchase_price') {
    return `£${num.toFixed(2)}`;
  }
  if (mapping === 'product_weight' || mapping === 'package_weight') {
    return `${num} g`;
  }
  return val;
};

const onApply = async () => {
  if (!parsedRows.value.length || !hasValueMappings.value || applyCount.value === 0) return;
  submitting.value = true;

  const updates: Array<{
    id: number;
    payload: Partial<Omit<GlobalShipmentItem, 'id' | 'created_at' | 'updated_at' | 'shipment_id'>>;
  }> = [];

  for (const preview of previewRows.value) {
    if (!preview.canApply || !preview.item) continue;
    const row = parsedRows.value[preview.pasteIndex];
    if (!row) continue;
    const payload = payloadFromRow(row);
    if (Object.keys(payload).length === 0) continue;
    updates.push({
      id: preview.item.id,
      payload,
    });
  }

  try {
    if (updates.length > 0 && shipmentStore.currentShipment?.id) {
      await shipmentStore.updateShipmentItemsBulk(shipmentStore.currentShipment.id, updates);
    }
    onDialogOK();
  } catch (err: unknown) {
    console.error('Bulk update failed', err);
  } finally {
    submitting.value = false;
  }
};
</script>

<style scoped>
.modern-dialog {
  background: #ffffff;
  box-shadow: 0 20px 45px -10px rgba(51, 65, 85, 0.15), 0 10px 20px -5px rgba(51, 65, 85, 0.08);
}

.border-bottom-subtle {
  border-bottom: 1px solid #e2e8f0;
}

.border-top-subtle {
  border-top: 1px solid #e2e8f0;
}

.instruction-box {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
}

.mapping-box {
  background: #f1f5f9;
  border: 1px solid #e2e8f0;
}

.modern-paste-textarea :deep(.q-field__control) {
  border-radius: 8px;
  background-color: #fafafa;
}

.modern-paste-textarea :deep(textarea) {
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 13px;
  color: #0f172a;
}

.preview-table {
  max-height: 340px;
  overflow-y: auto;
  border-radius: 8px;
  border-color: #e2e8f0;
}

.preview-table :deep(thead th) {
  position: sticky;
  top: 0;
  z-index: 2;
  background-color: #f8fafc;
  color: #0f172a;
  font-weight: 700;
  font-size: 12px;
  border-bottom: 1px solid #cbd5e1;
}

.preview-table :deep(tbody td) {
  font-size: 13px;
  color: #0f172a;
  border-bottom: 1px solid #f1f5f9;
}

.font-mono {
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
}
</style>
