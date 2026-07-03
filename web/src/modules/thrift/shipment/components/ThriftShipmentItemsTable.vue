<template>
  <div class="thrift-shipment-items-table-wrap">
    <!-- Skeleton loader for initial load -->
    <q-markup-table flat class="thrift-shipment-details-table" v-if="loading && !stocks.length">
      <thead>
        <tr>
          <th class="text-center col-sticky-sl">SL</th>
          <th class="text-center col-sticky-image">Image</th>
          <th v-if="isVisible('barcode')" class="text-left col-sticky-barcode">Barcode</th>
          <th v-if="isVisible('name')" class="text-left">Name</th>
          <th v-if="isVisible('brand_name')" class="text-left">Brand</th>
          <th v-if="isVisible('category_name')" class="text-left">Category</th>
          <th v-if="isVisible('type_name')" class="text-left">Type</th>
          <th v-if="isVisible('measurements')" class="text-left measurements-col">Measurements</th>
          <th v-if="isVisible('origin_unit_price')" class="text-right">Origin Price</th>
          <th v-if="isVisible('extra_origin_unit_price')" class="text-right">Extra Origin</th>
          <th v-if="isVisible('product_unit_cost')" class="text-right">Product Cost</th>
          <th v-if="isVisible('cargo_share_per_unit')" class="text-right">Cargo/Unit</th>
          <th v-if="isVisible('ops_share_per_unit')" class="text-right">Ops/Unit</th>
          <th v-if="isVisible('additional_charges_cost')" class="text-right">Add'l Charges</th>
          <th v-if="isVisible('landed_unit_cost')" class="text-right">Landed Cost</th>
          <th v-if="isVisible('item_markup_pct')" class="text-right">Item Markup %</th>
          <th v-if="isVisible('effective_markup_pct')" class="text-right">Effective Markup %</th>
          <th v-if="isVisible('suggested_sell_unit_price')" class="text-right">Suggested Sell</th>
          <th v-if="isVisible('listed_unit_price')" class="text-right">Listed Sell</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="i in 8" :key="i">
          <td class="text-center col-sticky-sl"><q-skeleton type="text" width="20px" class="inline-block" /></td>
          <td class="text-center col-sticky-image">
            <div class="shipment-item-image-box">
              <q-skeleton type="rect" style="width: 100%; height: 100%;" />
            </div>
          </td>
          <td v-if="isVisible('barcode')" class="text-left col-sticky-barcode"><q-skeleton type="text" /></td>
          <td v-if="isVisible('name')" class="text-left"><q-skeleton type="text" /></td>
          <td v-if="isVisible('brand_name')" class="text-left"><q-skeleton type="text" /></td>
          <td v-if="isVisible('category_name')" class="text-left"><q-skeleton type="text" /></td>
          <td v-if="isVisible('type_name')" class="text-left"><q-skeleton type="text" /></td>
          <td v-if="isVisible('measurements')" class="text-left measurements-col"><q-skeleton type="text" /></td>
          <td v-if="isVisible('origin_unit_price')" class="text-right"><q-skeleton type="text" /></td>
          <td v-if="isVisible('extra_origin_unit_price')" class="text-right"><q-skeleton type="text" /></td>
          <td v-if="isVisible('product_unit_cost')" class="text-right"><q-skeleton type="text" /></td>
          <td v-if="isVisible('cargo_share_per_unit')" class="text-right"><q-skeleton type="text" /></td>
          <td v-if="isVisible('ops_share_per_unit')" class="text-right"><q-skeleton type="text" /></td>
          <td v-if="isVisible('additional_charges_cost')" class="text-right"><q-skeleton type="text" /></td>
          <td v-if="isVisible('landed_unit_cost')" class="text-right"><q-skeleton type="text" /></td>
          <td v-if="isVisible('item_markup_pct')" class="text-right"><q-skeleton type="text" /></td>
          <td v-if="isVisible('effective_markup_pct')" class="text-right"><q-skeleton type="text" /></td>
          <td v-if="isVisible('suggested_sell_unit_price')" class="text-right"><q-skeleton type="text" /></td>
          <td v-if="isVisible('listed_unit_price')" class="text-right"><q-skeleton type="text" /></td>
        </tr>
      </tbody>
    </q-markup-table>

    <!-- Actual table -->
    <q-markup-table flat class="thrift-shipment-details-table" v-else :class="{ 'thrift-table-stale': loading }">
      <thead>
        <tr>
          <th class="text-center col-sticky-sl">SL</th>
          <th class="text-center col-sticky-image">Image</th>
          <th v-if="isVisible('barcode')" class="text-left col-sticky-barcode">Barcode</th>
          <th v-if="isVisible('name')" class="text-left">Name</th>
          <th v-if="isVisible('brand_name')" class="text-left">Brand</th>
          <th v-if="isVisible('category_name')" class="text-left">Category</th>
          <th v-if="isVisible('type_name')" class="text-left">Type</th>
          <th v-if="isVisible('measurements')" class="text-left measurements-col">Measurements</th>
          <th v-if="isVisible('origin_unit_price')" class="text-right">Origin Price</th>
          <th v-if="isVisible('extra_origin_unit_price')" class="text-right">Extra Origin</th>
          <th v-if="isVisible('product_unit_cost')" class="text-right">Product Cost</th>
          <th v-if="isVisible('cargo_share_per_unit')" class="text-right">Cargo/Unit</th>
          <th v-if="isVisible('ops_share_per_unit')" class="text-right">Ops/Unit</th>
          <th v-if="isVisible('additional_charges_cost')" class="text-right">Add'l Charges</th>
          <th v-if="isVisible('landed_unit_cost')" class="text-right">Landed Cost</th>
          <th v-if="isVisible('item_markup_pct')" class="text-right">Item Markup %</th>
          <th v-if="isVisible('effective_markup_pct')" class="text-right">Effective Markup %</th>
          <th v-if="isVisible('suggested_sell_unit_price')" class="text-right">Suggested Sell</th>
          <th v-if="isVisible('listed_unit_price')" class="text-right">Listed Sell</th>
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
            <div class="shipment-item-image-box">
              <SmartImage
                :key="row.id"
                :src="row.image_url"
                :alt="row.name || 'Stock image'"
                imgClass="shipment-item-image"
                :enableEdit="false"
                style="width: 100%; height: 100%;"
              />
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
          <td v-if="isVisible('measurements')" class="text-left measurements-col">
            <div class="row items-center no-wrap measurements-cell">
              <span class="measurements-cell__text col text-caption text-grey-8">
                {{ getFormattedMeasurements(row) }}
                <q-tooltip v-if="getFormattedMeasurements(row) !== '—'" max-width="320px">
                  {{ getFormattedMeasurements(row) }}
                </q-tooltip>
              </span>
              <q-btn
                flat
                round
                dense
                size="xs"
                icon="straighten"
                color="secondary"
                class="col-auto"
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
            <div class="row items-center justify-end no-wrap q-gutter-x-xs">
              <span>{{ formatCost(costingBreakdowns[row.id]?.landed_unit_cost || 0) }}</span>
              <q-btn
                flat
                round
                dense
                size="xs"
                icon="info"
                color="primary"
                @click="emit('open-landed-breakdown', row)"
              >
                <q-tooltip>Landed cost breakdown</q-tooltip>
              </q-btn>
            </div>
          </td>

          <!-- Item markup % -->
          <td v-if="isVisible('item_markup_pct')" class="text-right">
            <div
              v-if="isListedPriceLocked(row.pricing)"
              class="text-grey-7"
            >
              {{ effectiveMarkupLabel(row) }}
              <q-tooltip>Listed price locked — effective margin</q-tooltip>
            </div>
            <template v-else>
              <div class="row items-center justify-end no-wrap q-gutter-x-xs">
                <q-icon
                  v-if="isItemMarkupLocked(row.pricing)"
                  name="lock"
                  color="amber-8"
                  size="16px"
                >
                  <q-tooltip>Item markup locked — won't follow shipment markup</q-tooltip>
                </q-icon>
                <span class="text-underline-dashed cursor-pointer">
                  {{ itemMarkupLabel(row) }}
                </span>
                <q-btn
                  v-if="isItemMarkupLocked(row.pricing)"
                  flat
                  round
                  dense
                  size="xs"
                  icon="refresh"
                  color="grey-7"
                  @click.stop="emit('reset-item-markup', row)"
                >
                  <q-tooltip>Reset to shipment markup</q-tooltip>
                </q-btn>
              </div>
              <q-popup-edit
                :model-value="itemMarkupPct(row) ?? 0"
                v-slot="scope"
                buttons
                @save="val => emit('save-pricing-value', row, 'markup_rate_override', Number(val) / 100)"
              >
                <q-input v-model.number="scope.value" type="number" min="0" step="1" suffix="%" dense autofocus />
              </q-popup-edit>
            </template>
          </td>

          <!-- Effective markup % -->
          <td v-if="isVisible('effective_markup_pct')" class="text-right text-grey-7">
            {{ effectiveMarkupLabel(row) }}
          </td>

          <!-- Suggested sell price -->
          <td v-if="isVisible('suggested_sell_unit_price')" class="text-right text-grey-7">
            {{ formatCost(costingBreakdowns[row.id]?.suggested_sell_unit_price || 0) }}
          </td>

          <!-- Listed unit price -->
          <td v-if="isVisible('listed_unit_price')" class="text-right">
            <div class="row items-center justify-end no-wrap q-gutter-x-xs">
              <q-icon
                v-if="isListedPriceLocked(row.pricing)"
                name="lock"
                color="amber-8"
                size="16px"
              >
                <q-tooltip>Listed price locked — won't follow markup changes</q-tooltip>
              </q-icon>

              <span class="text-weight-bold text-underline-dashed cursor-pointer">
                {{ formatCost(resolvedListedPrice(row)) }}
              </span>

              <q-btn
                v-if="isListedPriceLocked(row.pricing)"
                flat
                round
                dense
                size="xs"
                icon="refresh"
                color="grey-7"
                @click.stop="emit('reset-listed-price', row)"
              >
                <q-tooltip>Reset to auto price</q-tooltip>
              </q-btn>
            </div>
            <q-popup-edit
              :model-value="resolvedListedPrice(row)"
              v-slot="scope"
              buttons
              @save="val => emit('save-pricing-value', row, 'listed_unit_price', val)"
            >
              <q-input v-model.number="scope.value" type="number" step="1" dense autofocus />
            </q-popup-edit>
          </td>
        </tr>

        <tr v-if="stocks.length === 0">
          <td colspan="100%" class="text-center text-grey q-py-lg">
            No stock items found in this shipment.
          </td>
        </tr>
      </tbody>
    </q-markup-table>
    <q-linear-progress v-if="loading && stocks.length > 0" indeterminate color="primary" class="absolute-top" style="z-index: 10" />
  </div>
</template>

<script setup lang="ts">
import type { ThriftStock } from '../../stock/types';
import SmartImage from 'src/components/SmartImage.vue';
import type { ThriftUnitCostBreakdown } from '../../shared/utils/computeThriftUnitCosts';
import type { ThriftCurrency } from '../../currency/types';
import { formatThriftStockMeasurements } from '../../shared/utils/formatThriftStockMeasurements';
import { formatThriftAmount } from '../../currency/utils/formatMoney';
import { resolveListedSellPrice } from '../../shared/utils/resolveListedSellPrice';
import { isListedPriceLocked, isItemMarkupLocked } from '../../shared/utils/thriftPricingLock';

const props = defineProps<{
  stocks: ThriftStock[];
  visibleColumns: Set<string>;
  costingBreakdowns: Record<number, ThriftUnitCostBreakdown>;
  purchaseCurrency: ThriftCurrency | undefined;
  costCurrency: ThriftCurrency | undefined;
  loading?: boolean;
}>();

const emit = defineEmits<{
  (e: 'edit-measurements', row: ThriftStock): void;
  (e: 'open-landed-breakdown', row: ThriftStock): void;
  (e: 'save-stock-value', row: ThriftStock, field: string, val: number): void;
  (e: 'save-pricing-value', row: ThriftStock, field: string, val: any): void;
  (e: 'reset-listed-price', row: ThriftStock): void;
  (e: 'reset-item-markup', row: ThriftStock): void;
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



function itemMarkupPct(row: ThriftStock): number | null {
  if (isListedPriceLocked(row.pricing)) return null;
  if (row.pricing?.markup_rate_override != null) {
    return Math.round(row.pricing.markup_rate_override * 1000) / 10;
  }
  const breakdown = props.costingBreakdowns[row.id];
  if (!breakdown) return null;
  return Math.round(breakdown.applied_markup_rate * 1000) / 10;
}

function itemMarkupLabel(row: ThriftStock): string {
  const pct = itemMarkupPct(row);
  return pct != null ? `${pct}%` : '—';
}

function effectiveMarkupLabel(row: ThriftStock): string {
  const breakdown = props.costingBreakdowns[row.id];
  if (!breakdown || breakdown.effective_markup_pct == null) return '—';
  return `${Math.round(breakdown.effective_markup_pct * 10) / 10}%`;
}

function resolvedListedPrice(row: ThriftStock): number {
  return resolveListedSellPrice(row.pricing, props.costingBreakdowns[row.id]);
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

.measurements-col {
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

.thrift-table-stale :deep(tbody) {
  opacity: 0.6;
  pointer-events: none;
  transition: opacity 0.3s ease;
}
</style>
