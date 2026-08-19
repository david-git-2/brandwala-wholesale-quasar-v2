<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide" persistent>
    <q-card class="q-dialog-plugin column no-wrap" style="width: 800px; max-width: 95vw; max-height: 90vh">
      <q-card-section class="row items-center q-pb-none col-auto">
        <div class="text-h6 text-primary text-weight-bold">
          {{ $t('product_based_costing.bulk_paste_title') }}
        </div>
        <q-space />
        <q-btn icon="ph ph-x" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-pa-md q-gutter-y-md col scroll">
        <q-banner class="bg-blue-1 text-blue-9 rounded-borders">
          <template #avatar>
            <q-icon name="ph ph-info" size="sm" />
          </template>
          {{ $t('product_based_costing.bulk_paste_hint') }}
        </q-banner>

        <div v-if="!parsedRows.length">
          <q-input
            v-model="rawPasteText"
            type="textarea"
            filled
            rows="10"
            :placeholder="$t('product_based_costing.bulk_paste_placeholder')"
            @update:model-value="onPasteUpdate"
          />
        </div>

        <div v-else class="column q-gutter-y-md">
          <div class="row justify-between items-center">
            <div class="text-subtitle2 text-grey-8">
              {{
                $t('product_based_costing.bulk_parsed_rows', {
                  rows: parsedRows.length,
                  cols: maxColumns,
                })
              }}
            </div>
            <q-btn
              flat
              no-caps
              dense
              color="primary"
              :label="$t('product_based_costing.bulk_clear_paste_again')"
              icon="ph ph-arrows-clockwise"
              @click="resetPaste"
            />
          </div>

          <!-- Column Header Mappings Selector -->
          <div class="bg-grey-2 q-pa-md rounded-borders">
            <div class="text-caption text-weight-medium text-grey-7 q-mb-sm">
              {{ $t('product_based_costing.bulk_map_columns') }}
            </div>
            <div class="row q-col-gutter-sm">
              <div v-for="colIdx in maxColumns" :key="colIdx" class="col-12 col-sm-3">
                <q-select
                  v-model="colMappings[colIdx - 1]"
                  :options="mappingOptions"
                  :label="$t('product_based_costing.bulk_column_n', { n: colIdx })"
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
          <div class="text-subtitle2 text-grey-8 q-mb-xs">
            {{ $t('product_based_costing.bulk_preview_updates') }}
          </div>
          <q-markup-table flat bordered dense class="preview-table">
            <thead>
              <tr>
                <th class="text-left" style="width: 50px">SL</th>
                <th class="text-left">
                  {{ $t('product_based_costing.bulk_costing_product') }}
                </th>
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
                    {{
                      $t('product_based_costing.bulk_current_row', {
                        qty: item.quantity,
                        price: item.price_gbp,
                        weight: item.product_weight,
                        pkgWeight: item.package_weight,
                      })
                    }}
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
                  <q-icon name="ph ph-warning" size="14px" class="q-mr-xs" />
                  {{
                    parsedRows.length > currentItems.length
                      ? $t('product_based_costing.bulk_more_rows_than_items', {
                          rows: parsedRows.length,
                          items: currentItems.length,
                        })
                      : $t('product_based_costing.bulk_fewer_rows_than_items', {
                          rows: parsedRows.length,
                          items: currentItems.length,
                        })
                  }}
                </td>
              </tr>
            </tbody>
          </q-markup-table>
        </div>
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md bg-grey-1 col-auto">
        <q-btn flat :label="$t('product_based_costing.cancel')" color="grey-8" v-close-popup no-caps />
        <q-btn
          color="primary"
          unelevated
          :label="$t('product_based_costing.bulk_apply_updates')"
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
import { useI18n } from 'vue-i18n';
import { useProductBasedCostingStore } from '../stores/productBasedCostingStore';
import type { ProductBasedCostingItemUpdateInput } from '../types';

defineEmits([...useDialogPluginComponent.emits]);

const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent();
const costingStore = useProductBasedCostingStore();
const $q = useQuasar();
const { t } = useI18n();

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
  { label: t('product_based_costing.bulk_ignore'), value: 'ignore' },
  { label: t('product_based_costing.table_col_qty'), value: 'quantity' },
  { label: t('product_based_costing.bulk_price_gbp'), value: 'price_gbp' },
  { label: t('product_based_costing.bulk_product_weight_g'), value: 'product_weight' },
  { label: t('product_based_costing.bulk_package_weight_g'), value: 'package_weight' },
];

const getColumnLabel = (mapping?: string) => {
  return mappingOptions.find((opt) => opt.value === mapping)?.label || t('product_based_costing.bulk_ignore');
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

  if (mapping === 'quantity') return `${Math.floor(num)} ${t('product_based_costing.pcs')}`;
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
        message: result.error ?? t('product_based_costing.bulk_update_failed'),
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
  max-height: 320px;
  overflow-y: auto;
}
.preview-table :deep(thead th) {
  position: sticky;
  top: 0;
  z-index: 1;
  background-color: #fff;
}
.font-mono {
  font-family: monospace;
}
</style>
