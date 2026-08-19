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
            Copy cells from Excel or Google Sheets (columns containing <strong>Quantity</strong>, <strong>Price</strong>, <strong>Product Weight</strong>, or <strong>Package Weight</strong>) and paste them below. Values will be applied to items sequentially from top to bottom.
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
                <th v-for="colIdx in maxColumns" :key="colIdx" class="text-center">
                  {{ getColumnLabel(colMappings[colIdx - 1]) }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(item, index) in previewRows" :key="item.id">
                <td class="text-left text-dark text-weight-medium" style="color: #475569">{{ index + 1 }}</td>
                <td class="text-left text-weight-medium ellipsis text-dark" style="max-width: 260px; color: #0f172a">
                  <div>{{ item.name }}</div>
                  <div class="text-caption text-grey-7">
                    Current: Qty {{ item.ordered_quantity }} · Price £{{ item.purchase_price }} · Wt
                    {{ item.product_weight }}g · Pkg Wt {{ item.package_weight }}g
                  </div>
                </td>
                <td v-for="colIdx in maxColumns" :key="colIdx" class="text-center font-mono">
                  <template v-if="getPastedValueForCell(index, colIdx - 1) !== null">
                    <span class="text-weight-bolder text-dark" style="color: #0f172a; font-size: 13px">
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
              <!-- Warning if pasted rows count doesn't match table items count -->
              <tr v-if="parsedRows.length !== currentItems.length" class="bg-amber-1">
                <td
                  :colspan="maxColumns + 2"
                  class="text-center text-amber-10 text-caption text-weight-bold q-py-sm"
                  style="color: #78350f"
                >
                  <q-icon name="ph ph-warning" size="16px" class="q-mr-xs" />
                  {{
                    parsedRows.length > currentItems.length
                      ? `You pasted ${parsedRows.length} rows, but this shipment only has ${currentItems.length} items. Extra rows will be ignored.`
                      : `You pasted ${parsedRows.length} rows, but this shipment has ${currentItems.length} items. Remaining items will not be updated.`
                  }}
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
          :disable="!parsedRows.length || !hasActiveMappings"
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

const previewRows = computed(() => {
  // Only show as many preview rows as we have shipment items
  const len = Math.max(parsedRows.value.length, currentItems.value.length);
  return currentItems.value.slice(0, len);
});

const mappingOptions = [
  { label: 'Ignore', value: 'ignore' },
  { label: 'Quantity', value: 'ordered_quantity' },
  { label: 'Price (£)', value: 'purchase_price' },
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

  const valStr = String(val);
  // Parse clipboard TSV format (Excel/Google Sheets copy paste)
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

  parsedRows.value = data;
  maxColumns.value = maxCols;

  // Set default column mappings sequentially
  const defaultMappings = [
    'ordered_quantity',
    'purchase_price',
    'product_weight',
    'package_weight',
  ];
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
  console.log('onApply clicked!');
  console.log('parsedRows:', parsedRows.value);
  console.log('currentItems:', currentItems.value);
  console.log('colMappings:', colMappings.value);

  if (!parsedRows.value.length || !hasActiveMappings.value) {
    console.log('Early return: parsedRows empty or no active mappings');
    return;
  }
  submitting.value = true;

  const updates: Array<{
    id: number;
    payload: Partial<Omit<GlobalShipmentItem, 'id' | 'created_at' | 'updated_at' | 'shipment_id'>>;
  }> = [];

  // Iterate over both arrays, capping at the length of shipment items
  const limit = Math.min(parsedRows.value.length, currentItems.value.length);
  console.log('limit:', limit);

  for (let i = 0; i < limit; i++) {
    const item = currentItems.value[i];
    const row = parsedRows.value[i];
    if (!item || !row) continue;
    const payload: any = {};

    colMappings.value.forEach((mapping, colIdx) => {
      if (!mapping || mapping === 'ignore' || colIdx >= row.length) return;
      const cellVal = row[colIdx];
      if (cellVal === undefined || cellVal === '') return; // skip empty cells

      // Strip symbols like £, $, g, etc.
      const cleaned = cellVal.replace(/[^0-9.-]/g, '');
      if (cleaned === '') {
        console.log(`Row ${i}, Col ${colIdx}: Value '${cellVal}' has no numeric content, skipping`);
        return;
      }
      const numVal = Number(cleaned);
      if (isNaN(numVal)) {
        console.log(`Row ${i}, Col ${colIdx}: Value '${cellVal}' parsed as NaN`);
        return;
      }

      if (mapping === 'ordered_quantity') {
        payload[mapping] = Math.max(1, Math.floor(numVal));
      } else if (mapping === 'purchase_price') {
        payload[mapping] = Math.max(0, numVal);
      } else if (mapping === 'product_weight' || mapping === 'package_weight') {
        payload[mapping] = Math.max(0, numVal);
      }
    });

    if (Object.keys(payload).length > 0) {
      updates.push({
        id: item.id,
        payload,
      });
    }
  }

  console.log('Updates payload to send:', updates);

  try {
    if (updates.length > 0 && shipmentStore.currentShipment?.id) {
      console.log('Calling shipmentStore.updateShipmentItemsBulk...');
      await shipmentStore.updateShipmentItemsBulk(shipmentStore.currentShipment.id, updates);
      console.log('Bulk update completed successfully');
    } else {
      console.log('No updates compiled to send!');
    }
    onDialogOK();
  } catch (err: any) {
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
