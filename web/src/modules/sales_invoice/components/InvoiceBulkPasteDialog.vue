<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide" persistent>
    <q-card class="q-dialog-plugin" style="width: 800px; max-width: 95vw">
      <q-card-section class="row items-center q-pb-none">
        <div class="text-h6 text-primary text-weight-bold">Bulk Paste Invoice Updates</div>
        <q-space />
        <q-btn icon="close" flat round dense v-close-popup />
      </q-card-section>

      <q-card-section class="q-pa-md q-gutter-y-md">
        <!-- Banner alert -->
        <q-banner class="bg-blue-1 text-blue-9 rounded-borders">
          <template #avatar>
            <q-icon name="info" size="sm" />
          </template>
          Copy cells from Excel or Google Sheets (columns containing Quantity, Sell Price, or
          Recipient Price) and paste them below. Values will be applied to items sequentially from
          top to bottom.
        </q-banner>

        <!-- Step 1: Text Area for pasting -->
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

        <!-- Step 2: Mapping & Preview -->
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

          <!-- Column Header Mappings Selector -->
          <div class="bg-grey-2 q-pa-md rounded-borders">
            <div class="text-caption text-weight-medium text-grey-7 q-mb-sm">
              Map Columns to Fields:
            </div>
            <div class="row q-col-gutter-sm">
              <div v-for="colIdx in maxColumns" :key="colIdx" class="col-12 col-sm-4">
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
          <div class="text-subtitle2 text-grey-8 q-mb-xs">Preview Matches & Updates</div>
          <q-markup-table flat bordered dense class="preview-table">
            <thead>
              <tr>
                <th class="text-left" style="width: 50px">SL</th>
                <th class="text-left">Invoice Product</th>
                <th v-for="colIdx in maxColumns" :key="colIdx" class="text-center">
                  {{ getColumnLabel(colMappings[colIdx - 1]) }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(item, index) in previewRows" :key="item.id">
                <td class="text-left text-grey-6">{{ index + 1 }}</td>
                <td class="text-left text-weight-medium ellipsis" style="max-width: 250px">
                  {{ item.name_snapshot }}
                  <div class="text-caption text-grey-6">
                    Current: Qty {{ item.quantity }} · Sell
                    {{ formatAmount(item.sell_price_amount) }}
                    <template v-if="isDropship">
                      · Recipient
                      {{ formatAmount(item.recipient_price_amount ?? item.sell_price_amount) }}
                    </template>
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
              <!-- Warning if pasted rows count doesn't match table items count -->
              <tr v-if="parsedRows.length !== items.length" class="bg-amber-1">
                <td
                  :colspan="maxColumns + 2"
                  class="text-center text-amber-9 text-caption text-weight-medium q-py-sm"
                >
                  <q-icon name="warning" size="14px" class="q-mr-xs" />
                  {{
                    parsedRows.length > items.length
                      ? `You pasted ${parsedRows.length} rows, but this invoice only has ${items.length} items. Extra rows will be ignored.`
                      : `You pasted ${parsedRows.length} rows, but this invoice has ${items.length} items. Remaining items will not be updated.`
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
import { useDialogPluginComponent } from 'quasar';
import { formatAmountBdt } from 'src/utils/currency';
import { showWarningNotification } from 'src/utils/appFeedback';
import { invoiceRepository } from '../repositories/invoiceRepository';
import type { GlobalInvoiceItemRow } from '../types';

const props = defineProps<{
  items: GlobalInvoiceItemRow[];
  isDropship: boolean;
}>();

defineEmits([...useDialogPluginComponent.emits]);

const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent();

const submitting = ref(false);
const rawPasteText = ref('');
const parsedRows = ref<Array<string[]>>([]);
const maxColumns = ref(0);
const colMappings = ref<string[]>([]);

const formatAmount = (val: number) => formatAmountBdt(val);

const previewRows = computed(() => {
  const len = Math.max(parsedRows.value.length, props.items.length);
  return props.items.slice(0, len);
});

const mappingOptions = computed(() => {
  const options = [
    { label: 'Ignore', value: 'ignore' },
    { label: 'Quantity', value: 'quantity' },
    { label: 'Sell Price', value: 'sell_price_amount' },
  ];
  if (props.isDropship) {
    options.push({ label: 'Recipient Price', value: 'recipient_price_amount' });
  }
  return options;
});

const getColumnLabel = (mapping?: string) => {
  return mappingOptions.value.find((opt) => opt.value === mapping)?.label || 'Ignore';
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

  const defaultMappings = ['quantity', 'sell_price_amount'];
  if (props.isDropship) {
    defaultMappings.push('recipient_price_amount');
  }

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

  if (mapping === 'quantity') {
    return `${Math.floor(num)} pcs`;
  }
  if (mapping === 'sell_price_amount' || mapping === 'recipient_price_amount') {
    return formatAmount(num);
  }
  return val;
};

const onApply = async () => {
  if (!parsedRows.value.length || !hasActiveMappings.value) {
    return;
  }
  submitting.value = true;

  const updates: Array<{
    id: number;
    quantity: number;
    sell_price_amount: number;
    recipient_price_amount?: number;
  }> = [];

  const limit = Math.min(parsedRows.value.length, props.items.length);

  for (let i = 0; i < limit; i++) {
    const item = props.items[i];
    const row = parsedRows.value[i];
    if (!item || !row) continue;
    const payload: any = {};

    colMappings.value.forEach((mapping, colIdx) => {
      if (!mapping || mapping === 'ignore' || colIdx >= row.length) return;
      const cellVal = row[colIdx];
      if (cellVal === undefined || cellVal === '') return;

      const cleaned = cellVal.replace(/[^0-9.-]/g, '');
      const numVal = Number(cleaned);
      if (isNaN(numVal)) {
        return;
      }

      if (mapping === 'quantity') {
        payload[mapping] = Math.max(1, Math.floor(numVal));
      } else if (mapping === 'sell_price_amount') {
        payload[mapping] = Math.max(0, numVal);
      } else if (mapping === 'recipient_price_amount') {
        payload[mapping] = Math.max(0, numVal);
      }
    });

    const finalQuantity = payload.quantity ?? item.quantity;
    const finalSellPrice = payload.sell_price_amount ?? item.sell_price_amount;
    const finalRecipientPrice = props.isDropship
      ? (payload.recipient_price_amount ?? item.recipient_price_amount ?? item.sell_price_amount)
      : undefined;

    updates.push({
      id: item.id,
      quantity: finalQuantity,
      sell_price_amount: finalSellPrice,
      ...(props.isDropship ? { recipient_price_amount: finalRecipientPrice } : {}),
    });
  }

  try {
    if (updates.length > 0) {
      await invoiceRepository.updateInvoiceItemsBulk(updates);
    }
    onDialogOK();
  } catch (err: any) {
    showWarningNotification(err instanceof Error ? err.message : 'Bulk update failed');
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
