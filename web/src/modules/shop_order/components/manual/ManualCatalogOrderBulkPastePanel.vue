<template>
  <AppResizableOverlayPanel
    v-model="showBulkPasteDialog"
    storage-key="shop_order.manual-catalog-bulk-paste-width"
    :default-width="640"
    :min-width="400"
    :max-width="960"
    aria-label="Bulk paste manual catalog order lines"
  >
    <div class="bulk-paste-overlay column no-wrap full-height">
      <div class="bulk-paste-overlay__header row items-center justify-between q-px-md q-pt-md q-pb-sm shrink-0">
        <div class="row items-center q-gutter-x-sm min-width-0">
          <q-avatar color="primary" text-color="white" icon="ph ph-clipboard-text" size="32px" />
          <div class="min-width-0">
            <div class="text-subtitle1 text-weight-bold text-grey-9">
              Bulk Paste {{ bulkPasteField === 'all' ? 'Values' : bulkPasteFieldLabel }}
            </div>
            <div class="text-caption text-grey-6">
              Click a cell, then paste. Data fills from that cell, like Excel.
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
          @click="showBulkPasteDialog = false"
        />
      </div>

      <div class="q-px-md q-pb-sm shrink-0 column q-gutter-y-sm">
        <div class="row items-center q-col-gutter-sm">
          <div class="col text-caption text-grey-7">
            {{ bulkPasteTargetItems.length }} line{{ bulkPasteTargetItems.length === 1 ? '' : 's' }}
          </div>
          <div class="col-auto">
            <q-btn
              flat
              dense
              no-caps
              color="primary"
              icon="ph ph-copy"
              label="Copy names"
              :disable="bulkPasteTargetItems.length === 0"
              @click="copyBulkPasteProductNames()"
            />
          </div>
        </div>
        <q-select
          v-model="bulkPasteField"
          :options="bulkPasteFieldOptions"
          outlined
          dense
          emit-value
          map-options
          label="Column to update"
          class="full-width"
        />
      </div>

      <div class="bulk-paste-overlay__body col q-px-md q-py-sm overflow-auto">
        <div class="bulk-paste-grid-wrap" @paste.capture="onBulkPasteGridPaste">
          <table class="bulk-paste-grid" :class="{ 'bulk-paste-grid--wide': bulkPasteField === 'all' }">
            <thead>
              <tr>
                <th v-for="col in bulkPasteGridColumns" :key="col">
                  {{ bulkPasteColumnLabel(col) }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, rowIdx) in bulkPasteRows" :key="row.rowKey">
                <td v-for="(col, colIdx) in bulkPasteGridColumns" :key="col">
                  <input
                    :value="bulkPasteCellValue(row, col)"
                    class="manual-catalog-bulk-paste-cell bulk-paste-cell"
                    :class="{ 'bulk-paste-cell--value': col !== 'barcode' && col !== 'product_code' }"
                    :data-row="rowIdx"
                    :data-col="colIdx"
                    @input="onBulkPasteCellInput(row, col, $event)"
                    @focus="onBulkPasteCellFocus(rowIdx, colIdx)"
                  />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="bulk-paste-overlay__footer row items-center justify-end q-gutter-sm q-pa-md shrink-0">
        <q-btn
          flat
          label="Cancel"
          color="grey-7"
          no-caps
          :disable="bulkPasteSaving"
          @click="showBulkPasteDialog = false"
        />
        <q-btn
          unelevated
          label="Apply Paste"
          color="primary"
          no-caps
          icon="ph ph-check"
          class="rounded-borders q-px-md text-weight-bold"
          :loading="bulkPasteSaving"
          :disable="bulkPasteSaving || bulkPasteTargetItems.length === 0"
          @click="applyBulkPaste()"
        />
      </div>
    </div>
  </AppResizableOverlayPanel>
</template>

<script setup lang="ts">
import { toRef } from 'vue';
import AppResizableOverlayPanel from 'src/components/ui/AppResizableOverlayPanel.vue';
import type { ManualCatalogLineItem } from '../../composables/useManualCatalogOrder';
import { useManualCatalogOrderBulkPaste } from '../../composables/useManualCatalogOrderBulkPaste';

const props = defineProps<{
  items: ManualCatalogLineItem[];
}>();

const itemsRef = toRef(props, 'items');

const {
  showBulkPasteDialog,
  bulkPasteField,
  bulkPasteRows,
  bulkPasteGridColumns,
  bulkPasteColumnLabel,
  bulkPasteCellValue,
  onBulkPasteCellInput,
  onBulkPasteCellFocus,
  onBulkPasteGridPaste,
  bulkPasteFieldOptions,
  bulkPasteFieldLabel,
  bulkPasteTargetItems,
  bulkPasteSaving,
  applyBulkPaste,
  openBulkPasteDialog,
  copyBulkPasteProductNames,
} = useManualCatalogOrderBulkPaste({
  items: itemsRef,
});

defineExpose({ openBulkPasteDialog });
</script>

<style scoped lang="scss">
.bulk-paste-overlay {
  background: var(--tf-neutral-surface, #fff);
  min-height: 0;
}

.bulk-paste-overlay__footer {
  border-top: 1px solid var(--tf-neutral-border, #e0e0e0);
}

.bulk-paste-overlay__body .bulk-paste-grid-wrap {
  min-height: 120px;
}

.bulk-paste-grid-wrap {
  overflow: auto;
  border: 1px solid var(--tf-neutral-border, #e0e0e0);
  border-radius: var(--tf-radius-sm, 4px);
}

.bulk-paste-grid {
  width: 100%;
  border-collapse: collapse;
  table-layout: fixed;
}

.bulk-paste-grid--wide {
  min-width: 520px;
}

.bulk-paste-grid--wide th {
  font-size: 10px;
}

.bulk-paste-grid th {
  position: sticky;
  top: 0;
  z-index: 1;
  background: var(--tf-neutral-chrome, #f5f5f5);
  border-bottom: 1px solid var(--tf-neutral-border, #e0e0e0);
  padding: 4px 6px;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.bulk-paste-grid td {
  border-bottom: 1px solid var(--tf-neutral-border, #eee);
  padding: 0;
}

.bulk-paste-cell {
  width: 100%;
  border: none;
  outline: none;
  padding: 4px 6px;
  font-size: 12px;
  background: transparent;
  box-sizing: border-box;
}

.bulk-paste-cell:focus {
  background: rgba(var(--q-primary-rgb, 25, 118, 210), 0.08);
}

.bulk-paste-cell--value {
  text-align: right;
  font-variant-numeric: tabular-nums;
}
</style>
