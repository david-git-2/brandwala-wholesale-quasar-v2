<script setup lang="ts">
import { computed } from 'vue';
import { copyToClipboard, useQuasar, type QTableColumn } from 'quasar';
import SmartImage from 'src/components/SmartImage.vue';
import ThriftStockSkeleton from './ThriftStockSkeleton.vue';
import type { ThriftStock, ThriftSection, ThriftCondition } from '../types';
import type { ThriftCurrency } from 'src/modules/thrift/currency/types';
import type { ThriftUnitCostBreakdown } from 'src/modules/thrift/shared/utils/computeThriftUnitCosts';
import { formatThriftAmount } from 'src/modules/thrift/currency/utils/formatMoney';
import { formatThriftStockMeasurements } from 'src/modules/thrift/shared/utils/formatThriftStockMeasurements';
import { resolveListedSellPrice } from 'src/modules/thrift/shared/utils/resolveListedSellPrice';
import { isListedPriceLocked, isItemMarkupLocked } from 'src/modules/thrift/shared/utils/thriftPricingLock';
import { editableStatusOptions, conditionSelectOptions, sectionSelectOptions } from '../composables/useThriftStockColumns';

function formatStockPrice(
  amount: number | null | undefined,
  currency: ThriftCurrency | undefined,
): string {
  if (amount == null) return '—';
  return formatThriftAmount(amount, currency);
}

interface BoxOption {
  id: number;
  name: string;
  shipment_id?: number | null;
}

const props = withDefaults(
  defineProps<{
    stocks: ThriftStock[];
    loading: boolean;
    storePage: number;
    storePageSize: number;
    columns: QTableColumn[];
    visibleColumns: string[];
    tablePagination: { page: number; rowsPerPage: number; rowsNumber: number };
    selectedStockIds: number[];
    allPageRowsSelected: boolean;
    somePageRowsSelected: boolean;
    costBreakdownByStockId: Record<number, ThriftUnitCostBreakdown>;
    boxesList: BoxOption[];
    tableCellClass: (colName: string) => string;
    stickyCellClass: (colName: string) => string;
    shipmentPurchaseCurrency: (shipmentId: number | null | undefined) => ThriftCurrency | undefined;
    shipmentCostCurrency: (shipmentId: number | null | undefined) => ThriftCurrency | undefined;
    itemMarkupPctForRow: (row: ThriftStock) => number | null;
    effectiveMarkupLabel: (row: ThriftStock) => string;
    getBoxName: (boxId: number | undefined | null) => string;
    canEdit?: boolean;
    canDelete?: boolean;
  }>(),
  {
    canEdit: false,
    canDelete: false,
  },
);

const emit = defineEmits<{
  (e: 'update:tablePagination', val: { page: number; rowsPerPage: number; rowsNumber: number }): void;
  (e: 'toggle-select-all-page', val: boolean): void;
  (e: 'toggle-stock-selection', payload: { id: number; checked: boolean }): void;
  (e: 'open-barcode-preview', row: ThriftStock): void;
  (e: 'open-measurements-dialog', row: ThriftStock): void;
  (e: 'open-landed-breakdown-dialog', row: ThriftStock): void;
  (e: 'reset-item-markup-to-shipment', row: ThriftStock): void;
  (e: 'reset-price-to-suggested', row: ThriftStock): void;
  (e: 'open-edit-dialog', row: ThriftStock): void;
  (e: 'confirm-delete', row: ThriftStock): void;
  (e: 'update-status', payload: { id: number; status: string }): void;
  (e: 'open-hold-dialog', row: ThriftStock): void;
  (e: 'release-hold', row: ThriftStock): void;
  (e: 'text-cell-save', payload: { row: ThriftStock; field: string; val: string }): void;
  (e: 'section-save', payload: { row: ThriftStock; val: ThriftSection | null }): void;
  (e: 'box-save', payload: { row: ThriftStock; val: number | null }): void;
  (e: 'number-cell-save', payload: { row: ThriftStock; field: string; val: number }): void;
  (e: 'condition-save', payload: { row: ThriftStock; val: ThriftCondition | null }): void;
  (e: 'origin-unit-price-save', payload: { row: ThriftStock; val: number }): void;
  (e: 'extra-origin-unit-price-save', payload: { row: ThriftStock; val: number }): void;
  (e: 'additional-charges-cost-save', payload: { row: ThriftStock; val: number }): void;
  (e: 'item-markup-save', payload: { row: ThriftStock; val: number }): void;
  (e: 'listed-unit-price-save', payload: { row: ThriftStock; val: number }): void;
  (e: 'status-cell-save', payload: { row: ThriftStock; val: string }): void;
}>();

const $q = useQuasar();

const pagination = computed({
  get: () => props.tablePagination,
  set: (val) => emit('update:tablePagination', val),
});

const effectiveVisibleColumns = computed(() => {
  if (props.canDelete) return props.visibleColumns;
  return props.visibleColumns.filter((name) => name !== 'select');
});

function cellClass(colName: string) {
  return [props.canEdit ? props.tableCellClass(colName) : '', props.stickyCellClass(colName)];
}

function onRequest(requestProps: { pagination: { page: number; rowsPerPage: number; rowsNumber?: number } }) {
  pagination.value = {
    ...props.tablePagination,
    page: requestProps.pagination.page,
    rowsPerPage: requestProps.pagination.rowsPerPage,
  };
}

function toNumber(val: unknown): number {
  if (val == null || val === '') return 0;
  const n = Number(val);
  return Number.isNaN(n) ? 0 : n;
}

function boxesForShipment(shipmentId: number | null | undefined): BoxOption[] {
  if (!shipmentId) return [];
  return props.boxesList.filter((b) => b.shipment_id === shipmentId);
}

function copyText(text: string, label: string) {
  const v = text.trim();
  if (!v || v === '—') return;
  void copyToClipboard(v).then(() => {
    $q.notify({ type: 'positive', message: `Copied ${label}`, timeout: 1200 });
  });
}

function listedPriceText(row: ThriftStock): string {
  return formatStockPrice(
    resolveListedSellPrice(row.pricing, props.costBreakdownByStockId[row.id]),
    props.shipmentCostCurrency(row.shipment_id),
  );
}

const normalizeStatus = (status: string | null | undefined) =>
  (status ?? '').trim().toUpperCase() || 'AVAILABLE';

const statusChipStyle = (status: string | null | undefined) => {
  const v = normalizeStatus(status);
  if (v === 'AVAILABLE')
    return { backgroundColor: '#d1fae5', color: '#065f46', border: '1px solid #6ee7b7' };
  if (v === 'RESERVED')
    return { backgroundColor: '#ffedd5', color: '#9a3412', border: '1px solid #fdba74' };
  if (v === 'OUT_OF_STOCK')
    return { backgroundColor: '#f3f4f6', color: '#374151', border: '1px solid #d1d5db' };
  if (v === 'SOLD')
    return { backgroundColor: '#dbeafe', color: '#1e40af', border: '1px solid #93c5fd' };
  if (v === 'DAMAGED')
    return { backgroundColor: '#fef3c7', color: '#92400e', border: '1px solid #fcd34d' };
  if (v === 'STOLEN')
    return { backgroundColor: '#fee2e2', color: '#7f1d1d', border: '1px solid #fca5a5' };
  return { backgroundColor: '#e5e7eb', color: '#374151', border: '1px solid #d1d5db' };
};

const statusDotColor = (status: string | null | undefined) => {
  const v = normalizeStatus(status);
  if (v === 'AVAILABLE') return '#059669';
  if (v === 'RESERVED') return '#ea580c';
  if (v === 'OUT_OF_STOCK') return '#9ca3af';
  if (v === 'SOLD') return '#2563eb';
  if (v === 'DAMAGED') return '#d97706';
  if (v === 'STOLEN') return '#dc2626';
  return '#9ca3af';
};
</script>

<template>
  <ThriftStockSkeleton v-if="loading && !stocks.length" />

  <!-- Table -->
  <q-card v-else flat class="floating-surface shadow-1 thrift-table-card">
    <q-linear-progress
      v-if="loading && stocks.length > 0"
      indeterminate
      color="primary"
      class="absolute-top"
      style="z-index: 10"
    />
    <q-table
      flat
      :rows="stocks"
      :columns="columns"
      :visible-columns="effectiveVisibleColumns"
      :table-style="{ maxHeight: '100%' }"
      row-key="id"
      v-model:pagination="pagination"
      :rows-per-page-options="[25, 50, 100, 250]"
      :class="[
        'thrift-table',
        { 'thrift-table--loading': loading, 'thrift-table--no-select': !canDelete },
      ]"
      @request="onRequest"
    >
      <template #header-cell-select="headerProps">
        <q-th :props="headerProps" class="col-sticky-select">
          <q-checkbox
            :model-value="allPageRowsSelected"
            :indeterminate="somePageRowsSelected && !allPageRowsSelected"
            dense
            @update:model-value="(checked) => emit('toggle-select-all-page', !!checked)"
          />
        </q-th>
      </template>
      <template #header-cell-sl="headerProps">
        <q-th :props="headerProps" class="col-sticky-sl">{{ headerProps.col.label }}</q-th>
      </template>
      <template #header-cell-image="headerProps">
        <q-th :props="headerProps" class="col-sticky-image">{{ headerProps.col.label }}</q-th>
      </template>
      <template #body="rowProps">
        <q-tr :props="rowProps">
          <q-td
            v-for="col in rowProps.cols"
            :key="col.name"
            :props="{ ...rowProps, col }"
            :class="cellClass(col.name)"
          >
            <template v-if="col.name === 'select'">
              <q-checkbox
                :model-value="selectedStockIds.includes(rowProps.row.id)"
                dense
                @update:model-value="(checked) => emit('toggle-stock-selection', { id: rowProps.row.id, checked: !!checked })"
              />
            </template>
            <template v-else-if="col.name === 'sl'">
              {{ (storePage - 1) * storePageSize + stocks.indexOf(rowProps.row) + 1 }}
            </template>
            <template v-else-if="col.name === 'image'">
              <div class="thrift-stock-image-wrap">
                <SmartImage
                  :key="rowProps.row.id"
                  :src="rowProps.row.image_url"
                  :alt="rowProps.row.name || 'Stock image'"
                  imgClass="thrift-stock-image__img"
                  :enableEdit="false"
                />
              </div>
            </template>
            <template v-else-if="col.name === 'barcode'">
              <div class="editable-value row items-center no-wrap">
                <span class="col ellipsis">{{ rowProps.row.barcode || '—' }}</span>
                <q-btn
                  v-if="rowProps.row.barcode"
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-copy"
                  color="grey-7"
                  class="col-auto"
                  aria-label="Copy barcode"
                  @click.stop="copyText(rowProps.row.barcode, 'barcode')"
                >
                  <q-tooltip>Copy barcode</q-tooltip>
                </q-btn>
                <q-btn
                  v-if="rowProps.row.barcode"
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-qr-code"
                  color="primary"
                  class="col-auto"
                  @click.stop="emit('open-barcode-preview', rowProps.row)"
                >
                  <q-tooltip>Preview barcode</q-tooltip>
                </q-btn>
              </div>
              <q-popup-edit
                v-if="canEdit"
                v-slot="scope"
                :model-value="rowProps.row.barcode"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                @save="(value) => emit('text-cell-save', { row: rowProps.row, field: 'barcode', val: String(value ?? '') })"
              >
                <q-input v-model="scope.value" dense outlined autofocus />
              </q-popup-edit>
            </template>
            <template v-else-if="col.name === 'name'">
              <div class="editable-value">{{ rowProps.row.name || '—' }}</div>
              <q-popup-edit
                v-if="canEdit"
                v-slot="scope"
                :model-value="rowProps.row.name"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                @save="(value) => emit('text-cell-save', { row: rowProps.row, field: 'name', val: String(value ?? '') })"
              >
                <q-input v-model="scope.value" dense outlined autofocus />
              </q-popup-edit>
            </template>
            <template v-else-if="col.name === 'brand_name'">
              <div class="editable-value row items-center no-wrap">
                <span class="col ellipsis">{{ rowProps.row.brand_name || '—' }}</span>
                <q-btn
                  v-if="rowProps.row.brand_name"
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-copy"
                  color="grey-7"
                  class="col-auto"
                  aria-label="Copy brand"
                  @click.stop="copyText(String(rowProps.row.brand_name), 'brand')"
                >
                  <q-tooltip>Copy brand</q-tooltip>
                </q-btn>
              </div>
              <q-popup-edit
                v-if="canEdit"
                v-slot="scope"
                :model-value="rowProps.row.brand_name"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                @save="(value) => emit('text-cell-save', { row: rowProps.row, field: 'brand_name', val: String(value ?? '') })"
              >
                <q-input v-model="scope.value" dense outlined autofocus />
              </q-popup-edit>
            </template>
            <template v-else-if="col.name === 'section'">
              <div class="editable-value">{{ rowProps.row.section || '—' }}</div>
              <q-popup-edit
                v-if="canEdit"
                v-slot="scope"
                :model-value="rowProps.row.section"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                @save="(value) => emit('section-save', { row: rowProps.row, val: value as ThriftSection | null })"
              >
                <q-select
                  v-model="scope.value"
                  :options="[...sectionSelectOptions]"
                  dense
                  outlined
                  clearable
                  autofocus
                />
              </q-popup-edit>
            </template>
            <template v-else-if="col.name === 'size'">
              <div class="row items-center no-wrap q-gutter-x-xs">
                <div
                  class="measurements-cell text-grey-9 text-weight-medium col"
                  :class="{ 'cursor-pointer': canEdit }"
                  @click="canEdit && emit('open-measurements-dialog', rowProps.row)"
                >
                  <span class="measurements-cell__text">
                    {{ formatThriftStockMeasurements(rowProps.row) }}
                  </span>
                  <q-tooltip max-width="320px">
                    {{ formatThriftStockMeasurements(rowProps.row) }}
                  </q-tooltip>
                </div>
                <q-btn
                  v-if="formatThriftStockMeasurements(rowProps.row) !== '—'"
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-copy"
                  color="grey-7"
                  class="col-auto"
                  aria-label="Copy size"
                  @click.stop="copyText(formatThriftStockMeasurements(rowProps.row), 'size')"
                >
                  <q-tooltip>Copy size</q-tooltip>
                </q-btn>
              </div>
            </template>            <template v-else-if="col.name === 'box'">
              <div class="editable-value">{{ getBoxName(rowProps.row.box_id) }}</div>
              <q-popup-edit
                v-if="canEdit"
                v-slot="scope"
                :model-value="rowProps.row.box_id ?? null"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                @save="(value) => emit('box-save', { row: rowProps.row, val: value as number | null })"
              >
                <q-select
                  v-model="scope.value"
                  :options="boxesForShipment(rowProps.row.shipment_id)"
                  option-value="id"
                  option-label="name"
                  emit-value
                  map-options
                  dense
                  outlined
                  clearable
                  autofocus
                />
              </q-popup-edit>
            </template>
            <template v-else-if="col.name === 'product_weight'">
              <div class="editable-value">
                {{ rowProps.row.product_weight ? `${rowProps.row.product_weight} g` : '—' }}
              </div>
              <q-popup-edit
                v-if="canEdit"
                v-slot="scope"
                :model-value="rowProps.row.product_weight ?? 0"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                @save="(value) => emit('number-cell-save', { row: rowProps.row, field: 'product_weight', val: toNumber(value) })"
              >
                <q-input
                  v-model.number="scope.value"
                  type="number"
                  min="0"
                  step="1"
                  dense
                  outlined
                  suffix="g"
                  autofocus
                />
              </q-popup-edit>
            </template>
            <template v-else-if="col.name === 'extra_weight'">
              <div class="editable-value">
                {{ rowProps.row.extra_weight ? `${rowProps.row.extra_weight} g` : '—' }}
              </div>
              <q-popup-edit
                v-if="canEdit"
                v-slot="scope"
                :model-value="rowProps.row.extra_weight ?? 0"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                @save="(value) => emit('number-cell-save', { row: rowProps.row, field: 'extra_weight', val: toNumber(value) })"
              >
                <q-input
                  v-model.number="scope.value"
                  type="number"
                  min="0"
                  step="1"
                  dense
                  outlined
                  suffix="g"
                  autofocus
                />
              </q-popup-edit>
            </template>
            <template v-else-if="col.name === 'condition'">
              <div class="editable-value">{{ rowProps.row.condition || '—' }}</div>
              <q-popup-edit
                v-if="canEdit"
                v-slot="scope"
                :model-value="rowProps.row.condition"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                @save="(value) => emit('condition-save', { row: rowProps.row, val: value as ThriftCondition | null })"
              >
                <q-select
                  v-model="scope.value"
                  :options="[...conditionSelectOptions]"
                  dense
                  outlined
                  clearable
                  autofocus
                />
              </q-popup-edit>
            </template>
            <template v-else-if="col.name === 'quantity'">
              <div class="editable-value">{{ rowProps.row.quantity ?? '—' }}</div>
              <q-popup-edit
                v-if="canEdit"
                v-slot="scope"
                :model-value="rowProps.row.quantity"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                @save="(value) => emit('number-cell-save', { row: rowProps.row, field: 'quantity', val: toNumber(value) })"
              >
                <q-input
                  v-model.number="scope.value"
                  type="number"
                  min="0"
                  step="1"
                  dense
                  outlined
                  autofocus
                />
              </q-popup-edit>
            </template>
            <template v-else-if="col.name === 'origin_unit_price'">
              <div class="editable-value">
                {{
                  formatStockPrice(
                    rowProps.row.origin_unit_price,
                    shipmentPurchaseCurrency(rowProps.row.shipment_id),
                  )
                }}
              </div>
              <q-popup-edit
                v-if="canEdit"
                v-slot="scope"
                :model-value="rowProps.row.origin_unit_price ?? 0"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                @save="(value) => emit('origin-unit-price-save', { row: rowProps.row, val: toNumber(value) })"
              >
                <q-input
                  v-model.number="scope.value"
                  type="number"
                  min="0"
                  step="0.01"
                  dense
                  outlined
                  :prefix="shipmentPurchaseCurrency(rowProps.row.shipment_id)?.symbol"
                  autofocus
                />
              </q-popup-edit>
            </template>
            <template v-else-if="col.name === 'extra_origin_unit_price'">
              <div class="editable-value">
                {{
                  formatStockPrice(
                    rowProps.row.extra_origin_unit_price,
                    shipmentPurchaseCurrency(rowProps.row.shipment_id),
                  )
                }}
              </div>
              <q-popup-edit
                v-if="canEdit"
                v-slot="scope"
                :model-value="rowProps.row.extra_origin_unit_price ?? 0"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                @save="(value) => emit('extra-origin-unit-price-save', { row: rowProps.row, val: toNumber(value) })"
              >
                <q-input
                  v-model.number="scope.value"
                  type="number"
                  min="0"
                  step="0.01"
                  dense
                  outlined
                  :prefix="shipmentPurchaseCurrency(rowProps.row.shipment_id)?.symbol"
                  autofocus
                />
              </q-popup-edit>
            </template>
            <template v-else-if="col.name === 'product_unit_cost'">
              <div class="text-grey-8 thrift-cost-computed">
                {{
                  formatStockPrice(
                    costBreakdownByStockId[rowProps.row.id]?.product_unit_cost || 0,
                    shipmentCostCurrency(rowProps.row.shipment_id),
                  )
                }}
              </div>
            </template>
            <template v-else-if="col.name === 'cargo_share_per_unit'">
              <div class="text-grey-8 thrift-cost-computed">
                {{
                  formatStockPrice(
                    costBreakdownByStockId[rowProps.row.id]?.cargo_share_per_unit || 0,
                    shipmentCostCurrency(rowProps.row.shipment_id),
                  )
                }}
              </div>
            </template>
            <template v-else-if="col.name === 'ops_share_per_unit'">
              <div class="text-grey-8 thrift-cost-computed">
                {{
                  formatStockPrice(
                    costBreakdownByStockId[rowProps.row.id]?.ops_share_per_unit || 0,
                    shipmentCostCurrency(rowProps.row.shipment_id),
                  )
                }}
              </div>
            </template>
            <template v-else-if="col.name === 'additional_charges_cost'">
              <div class="editable-value">
                {{
                  formatStockPrice(
                    rowProps.row.additional_charges_cost || 0,
                    shipmentCostCurrency(rowProps.row.shipment_id),
                  )
                }}
              </div>
              <q-popup-edit
                v-if="canEdit"
                v-slot="scope"
                :model-value="rowProps.row.additional_charges_cost ?? 0"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                @save="(value) => emit('additional-charges-cost-save', { row: rowProps.row, val: toNumber(value) })"
              >
                <q-input
                  v-model.number="scope.value"
                  type="number"
                  min="0"
                  step="0.01"
                  dense
                  outlined
                  :prefix="shipmentCostCurrency(rowProps.row.shipment_id)?.symbol"
                  autofocus
                />
              </q-popup-edit>
            </template>
            <template v-else-if="col.name === 'landed_unit_cost'">
              <div class="row items-center justify-end no-wrap q-gutter-x-xs">
                <div class="text-weight-bold text-teal thrift-cost-computed">
                  {{
                    formatStockPrice(
                      costBreakdownByStockId[rowProps.row.id]?.landed_unit_cost || 0,
                      shipmentCostCurrency(rowProps.row.shipment_id),
                    )
                  }}
                </div>
                <q-btn
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-info"
                  color="primary"
                  @click.stop="emit('open-landed-breakdown-dialog', rowProps.row)"
                >
                  <q-tooltip>Landed cost breakdown</q-tooltip>
                </q-btn>
              </div>
            </template>
            <template v-else-if="col.name === 'suggested_sell_unit_price'">
              <div class="text-grey-8 thrift-cost-computed">
                {{
                  formatStockPrice(
                    costBreakdownByStockId[rowProps.row.id]?.suggested_sell_unit_price || 0,
                    shipmentCostCurrency(rowProps.row.shipment_id),
                  )
                }}
              </div>
            </template>
            <template v-else-if="col.name === 'item_markup_pct'">
              <div
                v-if="isListedPriceLocked(rowProps.row.pricing)"
                class="text-grey-8 thrift-cost-computed"
              >
                {{ effectiveMarkupLabel(rowProps.row) }}
                <q-tooltip>Listed price locked — effective margin</q-tooltip>
              </div>
              <template v-else>
                <div class="row items-center justify-end no-wrap q-gutter-x-xs">
                  <q-icon
                    v-if="isItemMarkupLocked(rowProps.row.pricing)"
                    name="ph ph-lock-key"
                    color="amber-8"
                    size="16px"
                  >
                    <q-tooltip>Item markup locked — won't follow shipment markup</q-tooltip>
                  </q-icon>
                  <div class="editable-value text-grey-8">
                    {{
                      itemMarkupPctForRow(rowProps.row) != null
                        ? `${itemMarkupPctForRow(rowProps.row)}%`
                        : '—'
                    }}
                  </div>
                  <q-btn
                    v-if="isItemMarkupLocked(rowProps.row.pricing)"
                    flat
                    round
                    dense
                    size="xs"
                    icon="ph ph-arrows-clockwise"
                    color="grey-7"
                    :disable="!canEdit"
                    @click.stop="emit('reset-item-markup-to-shipment', rowProps.row)"
                  >
                    <q-tooltip>Reset to shipment markup</q-tooltip>
                  </q-btn>
                </div>
                <q-popup-edit
                  v-if="canEdit"
                  v-slot="scope"
                  :model-value="itemMarkupPctForRow(rowProps.row) ?? 0"
                  buttons
                  persistent
                  label-set="Save"
                  label-cancel="Cancel"
                  @save="(value) => emit('item-markup-save', { row: rowProps.row, val: toNumber(value) })"
                >
                  <q-input
                    v-model.number="scope.value"
                    type="number"
                    min="0"
                    step="1"
                    dense
                    outlined
                    suffix="%"
                    autofocus
                  />
                </q-popup-edit>
              </template>
            </template>
            <template v-else-if="col.name === 'effective_markup_pct'">
              <div class="text-grey-8 thrift-cost-computed">
                {{ effectiveMarkupLabel(rowProps.row) }}
              </div>
            </template>
            <template v-else-if="col.name === 'listed_unit_price'">
              <div class="row items-center justify-end no-wrap q-gutter-x-xs">
                <!-- Lock Icon when Manual -->
                <q-icon
                  v-if="isListedPriceLocked(rowProps.row.pricing)"
                  name="ph ph-lock-key"
                  color="amber-8"
                  size="16px"
                >
                  <q-tooltip>Listed price locked — won't follow markup changes</q-tooltip>
                </q-icon>

                <div class="editable-value text-weight-bold">
                  {{ listedPriceText(rowProps.row) }}
                </div>

                <q-btn
                  v-if="listedPriceText(rowProps.row) !== '—'"
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-copy"
                  color="grey-7"
                  aria-label="Copy listed sell price"
                  @click.stop="copyText(listedPriceText(rowProps.row), 'listed sell price')"
                >
                  <q-tooltip>Copy listed sell price</q-tooltip>
                </q-btn>

                <!-- Reset Button when Manual -->
                <q-btn
                  v-if="isListedPriceLocked(rowProps.row.pricing)"
                  flat
                  round
                  dense
                  size="xs"
                  icon="ph ph-arrows-clockwise"
                  color="grey-7"
                  :disable="!canEdit"
                  @click.stop="emit('reset-price-to-suggested', rowProps.row)"
                >
                  <q-tooltip>Reset to auto price</q-tooltip>
                </q-btn>
              </div>
              <q-popup-edit
                v-if="canEdit"
                v-slot="scope"
                :model-value="
                  resolveListedSellPrice(rowProps.row.pricing, costBreakdownByStockId[rowProps.row.id])
                "
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                @save="(value) => emit('listed-unit-price-save', { row: rowProps.row, val: toNumber(value) })"
              >
                <q-input
                  v-model.number="scope.value"
                  type="number"
                  min="0"
                  step="1"
                  dense
                  outlined
                  :prefix="shipmentCostCurrency(rowProps.row.shipment_id)?.symbol"
                  autofocus
                />
              </q-popup-edit>
            </template>            <template v-else-if="col.name === 'status'">
              <q-chip
                dense
                square
                :style="statusChipStyle(rowProps.row.status)"
                class="thrift-status-chip editable-value"
              >
                <span
                  class="status-dot"
                  :style="{ backgroundColor: statusDotColor(rowProps.row.status) }"
                />
                {{ rowProps.row.status ?? 'AVAILABLE' }}
              </q-chip>
              <q-popup-edit
                v-if="canEdit"
                v-slot="scope"
                :model-value="rowProps.row.status"
                buttons
                persistent
                label-set="Save"
                label-cancel="Cancel"
                @save="(value) => emit('status-cell-save', { row: rowProps.row, val: String(value ?? 'AVAILABLE') })"
              >
                <q-select
                  v-model="scope.value"
                  :options="editableStatusOptions"
                  emit-value
                  map-options
                  dense
                  outlined
                  autofocus
                />
              </q-popup-edit>
              <q-tooltip v-if="normalizeStatus(rowProps.row.status) === 'RESERVED'">
                Held for {{ rowProps.row.held_for_phone || rowProps.row.held_for_name || 'customer' }}
                <template v-if="rowProps.row.hold_note"> · {{ rowProps.row.hold_note }}</template>
              </q-tooltip>
            </template>
            <template v-else-if="col.name === 'actions'">
              <q-btn
                flat
                round
                dense
                icon="ph ph-ruler"
                size="sm"
                color="secondary"
                :disable="!canEdit"
                @click.stop="emit('open-measurements-dialog', rowProps.row)"
              >
                <q-tooltip>Garment Measurements</q-tooltip>
              </q-btn>
              <q-btn
                flat
                round
                dense
                icon="ph ph-pencil-simple"
                size="sm"
                color="primary"
                :disable="!canEdit"
                @click.stop="emit('open-edit-dialog', rowProps.row)"
              >
                <q-tooltip>Edit Details</q-tooltip>
              </q-btn>
              <q-btn
                flat
                round
                dense
                icon="ph ph-trash"
                size="sm"
                color="negative"
                :disable="!canDelete || normalizeStatus(rowProps.row.status) === 'SOLD'"
                @click.stop="emit('confirm-delete', rowProps.row)"
              >
                <q-tooltip>
                  {{
                    !canDelete
                      ? 'No delete permission'
                      : normalizeStatus(rowProps.row.status) === 'SOLD'
                        ? 'Cannot delete sold items'
                        : 'Delete Stock'
                  }}
                </q-tooltip>
              </q-btn>
              <q-btn
                v-if="normalizeStatus(rowProps.row.status) === 'AVAILABLE'"
                flat
                round
                dense
                icon="ph ph-lock-key"
                size="sm"
                color="orange-8"
                :disable="!canEdit"
                @click.stop="emit('open-hold-dialog', rowProps.row)"
              >
                <q-tooltip>Hold for customer</q-tooltip>
              </q-btn>
              <q-btn
                v-else-if="normalizeStatus(rowProps.row.status) === 'RESERVED'"
                flat
                round
                dense
                icon="ph ph-lock-open"
                size="sm"
                color="orange-8"
                :disable="!canEdit"
                @click.stop="emit('release-hold', rowProps.row)"
              >
                <q-tooltip>Release hold</q-tooltip>
              </q-btn>
              <q-btn
                flat
                round
                dense
                icon="ph ph-warning"
                size="sm"
                color="warning"
                :disable="!canEdit"
                @click.stop="emit('update-status', { id: rowProps.row.id, status: 'DAMAGED' })"
              >
                <q-tooltip>Mark Damaged</q-tooltip>
              </q-btn>
              <q-btn
                flat
                round
                dense
                icon="ph ph-prohibit"
                size="sm"
                color="negative"
                :disable="!canEdit"
                @click.stop="emit('update-status', { id: rowProps.row.id, status: 'STOLEN' })"
              >
                <q-tooltip>Mark Stolen</q-tooltip>
              </q-btn>
            </template>
            <template v-else>
              {{ col.value }}
            </template>
          </q-td>
        </q-tr>
      </template>
    </q-table>
  </q-card>
</template>

<style scoped>
.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.thrift-table-card {
  min-width: 0;
  max-width: 100%;
}

.thrift-table {
  max-width: 100%;
  height: clamp(400px, calc(100vh - 280px), 82vh);
  background: var(--bw-theme-base, #eef2f5);
}

.thrift-table :deep(.q-table__middle) {
  height: 100%;
  max-height: 100% !important;
  overflow: auto;
}

.thrift-table :deep(.q-table) {
  min-width: max-content;
  width: max-content;
}

.thrift-table :deep(table) {
  table-layout: fixed;
  min-width: max-content;
  width: max-content;
}

.thrift-table :deep(thead tr th) {
  position: sticky;
  z-index: 2;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
}

.thrift-table :deep(thead tr:first-child th) {
  top: 0;
  z-index: 3;
}

.thrift-table :deep(td.col-sticky-select),
.thrift-table :deep(th.col-sticky-select),
.thrift-table :deep(.col-sticky-select) {
  position: sticky;
  left: 0;
  z-index: 2;
  width: 44px;
  min-width: 44px;
  max-width: 44px;
  padding-left: 4px;
  padding-right: 4px;
  box-sizing: border-box;
  overflow: hidden;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 94%, #f8f9fa 6%);
}

.thrift-table :deep(td.col-sticky-sl),
.thrift-table :deep(th.col-sticky-sl),
.thrift-table :deep(.col-sticky-sl) {
  position: sticky;
  left: 44px;
  z-index: 2;
  width: 50px;
  min-width: 50px;
  max-width: 50px;
  padding-left: 4px;
  padding-right: 4px;
  box-sizing: border-box;
  overflow: hidden;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

.thrift-table :deep(td.col-sticky-image),
.thrift-table :deep(th.col-sticky-image),
.thrift-table :deep(.col-sticky-image) {
  position: sticky;
  left: 94px;
  z-index: 3;
  width: 104px;
  min-width: 104px;
  max-width: 104px;
  padding: 4px;
  box-sizing: border-box;
  overflow: hidden;
  vertical-align: middle;
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #fcfcfc 4%);
}

/* When select column is hidden, shift sticky SL/IMAGE to the left edge */
.thrift-table--no-select :deep(td.col-sticky-sl),
.thrift-table--no-select :deep(th.col-sticky-sl),
.thrift-table--no-select :deep(.col-sticky-sl) {
  left: 0;
}

.thrift-table--no-select :deep(td.col-sticky-image),
.thrift-table--no-select :deep(th.col-sticky-image),
.thrift-table--no-select :deep(.col-sticky-image) {
  left: 50px;
}

.thrift-table :deep(tr:first-child th.col-sticky-select) {
  z-index: 6;
}

.thrift-table :deep(tr:first-child th.col-sticky-sl) {
  z-index: 6;
}

.thrift-table :deep(tr:first-child th.col-sticky-image) {
  z-index: 6;
}

.thrift-stock-image-wrap {
  width: 96px;
  height: 96px;
  max-width: 100%;
  margin: 0 auto;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f7f9fc;
  border-radius: 6px;
  overflow: hidden;
}

.thrift-stock-image-wrap :deep(.smart-image-wrapper) {
  width: 96px;
  height: 96px;
  max-width: 100%;
  overflow: hidden;
}

.thrift-stock-image-wrap :deep(.thrift-stock-image__img),
.thrift-stock-image-wrap :deep(img) {
  width: 96px;
  height: 96px;
  max-width: 100%;
  object-fit: cover;
}

.editable-cell {
  cursor: pointer;
}

.editable-value {
  min-height: 24px;
  display: flex;
  align-items: center;
}

.editable-cell.text-right .editable-value {
  justify-content: flex-end;
}

.thrift-table :deep(th) {
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
}

.thrift-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  padding: 0 8px;
}

.status-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}

:deep(th.measurements-col),
:deep(td.measurements-col) {
  max-width: 180px;
  min-width: 120px;
}

.measurements-cell {
  max-width: 100%;
  min-width: 0;
}

.measurements-cell__text {
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.thrift-table--loading :deep(tbody) {
  opacity: 0.6;
  pointer-events: none;
  transition: opacity 0.3s ease;
}
</style>
