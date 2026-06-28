<template>
  <div class="thrift-shipment-items-table-wrap">
    <q-markup-table flat class="thrift-shipment-details-table">
      <thead>
        <tr>
          <th class="text-center col-sticky-sl">SL</th>
          <th class="text-center col-sticky-image">Image</th>
          <th v-if="isVisible('barcode')" class="text-left col-sticky-barcode">Barcode</th>
          <th v-if="isVisible('name')" class="text-left">Name</th>
          <th v-if="isVisible('brand_name')" class="text-left">Brand</th>
          <th v-if="isVisible('category_name')" class="text-left">Category</th>
          <th v-if="isVisible('type_name')" class="text-left">Type</th>
          <th v-if="isVisible('measurements')" class="text-left" style="min-width: 160px;">Measurements</th>
          <th v-if="isVisible('origin_unit_price')" class="text-right">Origin Price</th>
          <th v-if="isVisible('extra_origin_unit_price')" class="text-right">Extra Origin</th>
          <th v-if="isVisible('product_unit_cost')" class="text-right">Product Cost</th>
          <th v-if="isVisible('cargo_share_per_unit')" class="text-right">Cargo/Unit</th>
          <th v-if="isVisible('ops_share_per_unit')" class="text-right">Ops/Unit</th>
          <th v-if="isVisible('additional_charges_cost')" class="text-right">Add'l Charges</th>
          <th v-if="isVisible('landed_unit_cost')" class="text-right">Landed Cost</th>
          <th v-if="isVisible('suggested_sell_unit_price')" class="text-right">Suggested Sell</th>
          <th v-if="isVisible('listed_unit_price')" class="text-right">Listed Sell</th>
          <th v-if="isVisible('is_listed_price_manual')" class="text-center">Manual</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="(row, index) in stocks" :key="row.id">
          <!-- SL -->
          <td class="text-center col-sticky-sl">
            {{ index + 1 }}
          </td>

          <!-- Image -->
          <td class="text-center col-sticky-image">
            <div class="shipment-item-image-box cursor-pointer" @click="openImage(row.image_url)">
              <img :src="row.image_url" v-if="row.image_url" class="shipment-item-image" />
              <q-icon name="image" color="grey" size="24px" v-else />
            </div>
          </td>

          <!-- Barcode -->
          <td v-if="isVisible('barcode')" class="text-left col-sticky-barcode text-mono text-weight-bold">
            {{ row.barcode }}
          </td>

          <!-- Name -->
          <td v-if="isVisible('name')" class="text-left">
            {{ row.name }}
          </td>

          <!-- Brand -->
          <td v-if="isVisible('brand_name')" class="text-left">
            {{ row.brand_name || '—' }}
          </td>

          <!-- Category -->
          <td v-if="isVisible('category_name')" class="text-left">
            {{ row.category_name || '—' }}
          </td>

          <!-- Type -->
          <td v-if="isVisible('type_name')" class="text-left">
            {{ row.type_name || '—' }}
          </td>

          <!-- Measurements -->
          <td v-if="isVisible('measurements')" class="text-left">
            <div class="row items-center justify-between no-wrap">
              <span class="text-caption text-grey-8 ellipsis" style="max-width: 140px;">
                {{ getFormattedMeasurements(row) }}
              </span>
              <q-btn
                flat
                round
                dense
                size="xs"
                icon="straighten"
                color="secondary"
                @click="emit('edit-measurements', row)"
              >
                <q-tooltip>Edit Measurements</q-tooltip>
              </q-btn>
            </div>
          </td>

          <!-- Origin Price -->
          <td v-if="isVisible('origin_unit_price')" class="cursor-pointer text-right text-underline-dashed">
            {{ formatPurchase(row.origin_unit_price || 0) }}
            <q-popup-edit
              :model-value="row.origin_unit_price || 0"
              v-slot="scope"
              buttons
              @save="val => emit('save-stock-value', row, 'origin_unit_price', val)"
            >
              <q-input v-model.number="scope.value" type="number" step="0.01" dense autofocus />
            </q-popup-edit>
          </td>

          <!-- Extra Origin -->
          <td v-if="isVisible('extra_origin_unit_price')" class="cursor-pointer text-right text-underline-dashed">
            {{ formatPurchase(row.extra_origin_unit_price || 0) }}
            <q-popup-edit
              :model-value="row.extra_origin_unit_price || 0"
              v-slot="scope"
              buttons
              @save="val => emit('save-stock-value', row, 'extra_origin_unit_price', val)"
            >
              <q-input v-model.number="scope.value" type="number" step="0.01" dense autofocus />
            </q-popup-edit>
          </td>

          <!-- Product Cost -->
          <td v-if="isVisible('product_unit_cost')" class="text-right text-grey-7">
            {{ formatCost(costingBreakdowns[row.id]?.product_unit_cost || 0) }}
          </td>

          <!-- Cargo share per unit -->
          <td v-if="isVisible('cargo_share_per_unit')" class="text-right text-grey-7">
            {{ formatCost(costingBreakdowns[row.id]?.cargo_share_per_unit || 0) }}
          </td>

          <!-- Ops share per unit -->
          <td v-if="isVisible('ops_share_per_unit')" class="text-right text-grey-7">
            {{ formatCost(costingBreakdowns[row.id]?.ops_share_per_unit || 0) }}
          </td>

          <!-- Additional charges cost -->
          <td v-if="isVisible('additional_charges_cost')" class="cursor-pointer text-right text-underline-dashed">
            {{ formatCost(row.additional_charges_cost || 0) }}
            <q-popup-edit
              :model-value="row.additional_charges_cost || 0"
              v-slot="scope"
              buttons
              @save="val => emit('save-stock-value', row, 'additional_charges_cost', val)"
            >
              <q-input v-model.number="scope.value" type="number" step="0.01" dense autofocus />
            </q-popup-edit>
          </td>

          <!-- Landed unit cost -->
          <td v-if="isVisible('landed_unit_cost')" class="text-right text-weight-bold text-teal">
            {{ formatCost(costingBreakdowns[row.id]?.landed_unit_cost || 0) }}
          </td>

          <!-- Suggested sell price -->
          <td v-if="isVisible('suggested_sell_unit_price')" class="text-right text-grey-7">
            {{ formatCost(costingBreakdowns[row.id]?.suggested_sell_unit_price || 0) }}
          </td>

          <!-- Listed unit price -->
          <td v-if="isVisible('listed_unit_price')" class="cursor-pointer text-right text-weight-bold text-underline-dashed">
            {{ formatCost(row.pricing?.listed_unit_price || 0) }}
            <q-popup-edit
              :model-value="row.pricing?.listed_unit_price || 0"
              v-slot="scope"
              buttons
              @save="val => emit('save-pricing-value', row, 'listed_unit_price', val)"
            >
              <q-input v-model.number="scope.value" type="number" step="1" dense autofocus />
            </q-popup-edit>
          </td>

          <!-- Manual flag toggle -->
          <td v-if="isVisible('is_listed_price_manual')" class="text-center">
            <q-toggle
              :model-value="!!row.pricing?.is_listed_price_manual"
              color="primary"
              dense
              @update:model-value="val => emit('save-pricing-value', row, 'is_listed_price_manual', val)"
            />
          </td>
        </tr>

        <tr v-if="stocks.length === 0">
          <td colspan="100%" class="text-center text-grey q-py-lg">
            No stock items found in this shipment.
          </td>
        </tr>
      </tbody>
    </q-markup-table>
    <q-inner-loading :showing="loading" />
  </div>
</template>

<script setup lang="ts">
import type { ThriftStock } from '../../stock/types';
import type { ThriftUnitCostBreakdown } from '../../shared/utils/computeThriftUnitCosts';
import type { ThriftCurrency } from '../../currency/types';
import { formatThriftStockMeasurements } from '../../shared/utils/formatThriftStockMeasurements';
import { formatThriftAmount } from '../../currency/utils/formatMoney';

const props = defineProps<{
  stocks: ThriftStock[];
  visibleColumns: Set<string>;
  costingBreakdowns: Record<number, ThriftUnitCostBreakdown>;
  purchaseCurrency?: ThriftCurrency;
  costCurrency?: ThriftCurrency;
  loading?: boolean;
}>();

const emit = defineEmits<{
  (e: 'edit-measurements', row: ThriftStock): void;
  (e: 'save-stock-value', row: ThriftStock, field: string, val: number): void;
  (e: 'save-pricing-value', row: ThriftStock, field: string, val: any): void;
}>();

function isVisible(col: string): boolean {
  return props.visibleColumns.has(col);
}

function formatPurchase(amount: number): string {
  return formatThriftAmount(amount, props.purchaseCurrency);
}

function formatCost(amount: number): string {
  return formatThriftAmount(amount, props.costCurrency);
}

function getFormattedMeasurements(row: ThriftStock): string {
  return formatThriftStockMeasurements(row);
}

function openImage(url: string | null | undefined) {
  if (url) {
    window.open(url, '_blank');
  }
}
</script>

<style scoped>
.thrift-shipment-items-table-wrap {
  position: relative;
}

.thrift-shipment-details-table {
  overflow: auto;
  max-height: clamp(400px, calc(100vh - 350px), 80vh);
  --sl-col-width: 60px;
  --image-col-width: 115px;
}

.thrift-shipment-details-table :deep(thead tr th) {
  background: color-mix(in srgb, var(--bw-theme-surface, #fff) 96%, #f7f9fc 4%);
  position: sticky;
  top: 0;
  z-index: 2;
}

/* Sticky SL Column */
.col-sticky-sl {
  position: sticky;
  left: 0;
  width: var(--sl-col-width);
  min-width: var(--sl-col-width);
  max-width: var(--sl-col-width);
}

.thrift-shipment-details-table :deep(td.col-sticky-sl) {
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #bw-theme-surface) 94%, #f8f9fa 6%);
}

/* Sticky Image Column */
.col-sticky-image {
  position: sticky;
  left: var(--sl-col-width);
  width: var(--image-col-width);
  min-width: var(--image-col-width);
  max-width: var(--image-col-width);
}

.thrift-shipment-details-table :deep(td.col-sticky-image) {
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #bw-theme-surface) 96%, #fcfcfc 4%);
}

/* Sticky Barcode Column */
.col-sticky-barcode {
  position: sticky;
  left: calc(var(--sl-col-width) + var(--image-col-width));
  width: 170px;
  min-width: 170px;
  max-width: 170px;
}

.thrift-shipment-details-table :deep(td.col-sticky-barcode) {
  z-index: 1;
  background: color-mix(in srgb, var(--bw-theme-surface, #bw-theme-surface) 96%, #fcfcfc 4%);
}

/* Header Sticky Corners */
.thrift-shipment-details-table :deep(tr:first-child th.col-sticky-sl),
.thrift-shipment-details-table :deep(tr:first-child th.col-sticky-image),
.thrift-shipment-details-table :deep(tr:first-child th.col-sticky-barcode) {
  z-index: 4;
}

.shipment-item-image-box {
  width: 1in;
  height: 1in;
  border-radius: 8px;
  overflow: hidden;
  border: 1px solid rgba(0, 0, 0, 0.08);
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f8f9fa;
}

.shipment-item-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.text-underline-dashed {
  text-decoration: underline dashed rgba(0, 0, 0, 0.3);
}
</style>
