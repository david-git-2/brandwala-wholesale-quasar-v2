<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide" persistent>
    <q-card class="q-dialog-plugin" style="width: 800px; max-width: 95vw">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-primary text-weight-bold">Bulk Paste Costing Updates</div>
        <q-space />
        <q-btn icon="close" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-pa-md q-gutter-y-md">
        <q-banner class="bg-blue-1 text-blue-9 rounded-borders">
          <template #avatar>
            <q-icon name="info" size="sm" />
          </template>
          Copy cells from Excel or Google Sheets (Quantity, Price, Product Weight, or Package
          Weight) and paste them below. Values are applied to items top to bottom in table order.
        </q-banner>

        <div v-if="!parsedRows.length">
          <q-input
            v-model="rawPasteText"
            type="textarea"
            filled
            rows="10"
            placeholder="Paste your copied Excel data here..."
            @update:model-value="onPasteUpdate"
          />
        </div>

        <div v-else class="column q-gutter-y-md">
          <div class="row justify-between items-center">
            <div class="text-subtitle2 text-grey-8">
              Parsed {{ parsedRows.length }} rows with {{ maxColumns }} columns
            </div>
            <q-btn
              flat
              no-caps
              dense
              color="primary"
              label="Clear & Paste Again"
              icon="refresh"
              @click="resetPaste"
            />
          </div>

          <div class="bg-grey-2 q-pa-md rounded-borders">
            <div class="text-caption text-weight-medium text-grey-7 q-mb-sm">
              Map Columns to Fields:
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

          <div class="text-subtitle2 text-grey-8 q-mb-xs">Preview Matches & Updates</div>
          <q-markup-table flat bordered dense class="preview-table">
            <thead>
              <tr>
                <th class="text-left" style="width: 50px">SL</th>
                <th class="text-left">Costing Product</th>
                <th v-for="colIdx in maxColumns" :key="colIdx" class="text-center">
                  {{ getColumnLabel(colMappings[colIdx - 1]) }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(item, index) in previewRows" :key="item.id">
                <td class="text-left text-grey-6">{{ index + 1 }}</td>
                <td class="text-left text-weight-medium ellipsis" style="max-width: 250px">
                  {{ item.name }}
                  <div class="text-caption text-grey-6">
                    Current: Qty {{ item.quantity }} · Price £{{ item.price_gbp }} · Wt
                    {{ item.product_weight }}g · Pkg Wt {{ item.package_weight }}g
                  </div>
                </td>
                <td v-for="colIdx in maxColumns" :key="colIdx" class="text-center font-mono">
                  <template v-if="getPastedValueForCell(index, colIdx - 1) !== null">
                    <span class="text-weight-bold text-primary">
                      {{
                        formatPreviewValue(
                          getPastedValueForCell(index, colIdx - 1),
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
              <tr v-if="parsedRows.length !== currentItems.length" class="bg-amber-1">
                <td
                  :colspan="maxColumns + 2"
                  class="text-center text-amber-9 text-caption text-weight-medium q-py-sm"
                >
                  <q-icon name="warning" size="14px" class="q-mr-xs" />
                  {{
                    parsedRows.length > currentItems.length
                      ? `You pasted ${parsedRows.length} rows, but this file only has ${currentItems.length} items. Extra rows will be ignored.`
                      : `You pasted ${parsedRows.length} rows, but this file has ${currentItems.length} items. Remaining items will not be updated.`
                  }}
                </td>
              </tr>
            </tbody>
          </q-markup-table>
        </div>
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md bg-grey-1">
        <q-btn flat label="Cancel" color="grey-8" v-close-popup no-caps />
        <q-btn
          color="primary"
          unelevated
          label="Apply Updates"
          :disable="!parsedRows.length || !hasActiveMappings"
          :loading="submitting"
          no-caps
          @click="onApply"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useDialogPluginComponent, useQuasar } from 'quasar';
import { useProductBasedCostingStore } from '../stores/productBasedCostingStore';
import type { ProductBasedCostingItemUpdateInput } from '../types';

defineEmits([...useDialogPluginComponent.emits]);

const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent();
const costingStore = useProductBasedCostingStore();
const $q = useQuasar();

const submitting = ref(false);
const rawPasteText = ref('');
const parsedRows = ref<Array<string[]>>([]);
const maxColumns = ref(0);
const colMappings = ref<string[]>([]);

const currentItems = computed(() => costingStore.costingItems);

const previewRows = computed(() => {
  const len = Math.max(parsedRows.value.length, currentItems.value.length);
  return currentItems.value.slice(0, len);
});

const mappingOptions = [
  { label: 'Ignore', value: 'ignore' },
  { label: 'Quantity', value: 'quantity' },
  { label: 'Price (£)', value: 'price_gbp' },
  { label: 'Product Weight (g)', value: 'product_weight' },
  { label: 'Package Weight (g)', value: 'package_weight' },
];

const getColumnLabel = (mapping?: string) => {
  return mappingOptions.find((opt) => opt.value === mapping)?.label || 'Ignore';
};

const hasActiveMappings = computed(() => {
  return colMappings.value.some((mapping) => mapping && mapping !== 'ignore');
});

const onPasteUpdate = (val: string | number | null) => {
  if (!val) {
    parsedRows.value = [];
    maxColumns.value = 0;
    return;
  }

  const rows = String(val).split(/\r?\n/);
  const data: Array<string[]> = [];
  let maxCols = 0;

  for (const row of rows) {
    if (row.trim() === '') continue;
    const cols = row.split('\t').map((c) => c.trim());
    data.push(cols);
    if (cols.length > maxCols) maxCols = cols.length;
  }

  parsedRows.value = data;
  maxColumns.value = maxCols;

  const defaultMappings = ['quantity', 'price_gbp', 'product_weight', 'package_weight'];
  colMappings.value = Array.from({ length: maxCols }, (_, idx) => {
    return defaultMappings[idx] || 'ignore';
  });
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
  if (!mapping || mapping === 'ignore' || val === null || val === '') return val || '';
  const num = Number(val.replace(/[^0-9.-]/g, ''));
  if (isNaN(num)) return val;

  if (mapping === 'quantity') return `${Math.floor(num)} pcs`;
  if (mapping === 'price_gbp') return `£${num.toFixed(2)}`;
  if (mapping === 'product_weight' || mapping === 'package_weight') return `${num} g`;
  return val;
};

const onApply = async () => {
  if (!parsedRows.value.length || !hasActiveMappings.value) return;
  submitting.value = true;

  const updates: ProductBasedCostingItemUpdateInput[] = [];
  const limit = Math.min(parsedRows.value.length, currentItems.value.length);

  for (let i = 0; i < limit; i++) {
    const item = currentItems.value[i];
    const row = parsedRows.value[i];
    if (!item || !row) continue;

    const payload: ProductBasedCostingItemUpdateInput = { id: item.id };

    colMappings.value.forEach((mapping, colIdx) => {
      if (!mapping || mapping === 'ignore' || colIdx >= row.length) return;
      const cellVal = row[colIdx];
      if (cellVal === undefined || cellVal === '') return;

      const cleaned = cellVal.replace(/[^0-9.-]/g, '');
      if (cleaned === '') return;
      const numVal = Number(cleaned);
      if (isNaN(numVal)) return;

      if (mapping === 'quantity') {
        payload.quantity = Math.max(1, Math.floor(numVal));
      } else if (mapping === 'price_gbp') {
        payload.price_gbp = Math.max(0, numVal);
      } else if (mapping === 'product_weight' || mapping === 'package_weight') {
        payload[mapping] = Math.max(0, numVal);
      }
    });

    if (Object.keys(payload).length > 1) {
      updates.push(payload);
    }
  }

  try {
    if (updates.length > 0) {
      const result = await costingStore.updateProductBasedCostingItemsBulk(updates);
      if (!result.success) {
        $q.notify({
          type: 'negative',
          message: result.error ?? 'Bulk update failed.',
        });
        return;
      }
    }
    onDialogOK();
  } finally {
    submitting.value = false;
  }
};
</script>

<style scoped>
.preview-table {
  max-height: 350px;
  overflow-y: auto;
}
.font-mono {
  font-family: monospace;
}
</style>
