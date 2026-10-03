<template>
  <div class="line-card" :class="{ 'line-card--selected': item.selected }">
    <div class="line-card__select" @click.stop>
      <q-checkbox
        :model-value="item.selected"
        dense
        size="xs"
        @update:model-value="(val) => emit('toggle-select', item.id, !!val)"
      />
    </div>

    <div class="line-card__lead" @click.stop>
      <input
        :value="item.sl"
        type="number"
        min="1"
        class="sl-input font-mono line-card__lead-sl"
        aria-label="Line number"
        @change="(e) => emit('sl-change', item, (e.target as HTMLInputElement).value)"
        @keydown.enter="(e) => (e.target as HTMLInputElement).blur()"
      />
      <div class="item-img-container line-card__lead-img">
        <SmartImage
          :src="item.image_url"
          :alt="item.name"
          img-class="item-img-element"
          class="item-img-smart"
          fallback-icon="ph ph-t-shirt"
        />
        <q-btn
          v-if="item.image_url"
          flat
          round
          dense
          size="xs"
          icon="ph ph-magnifying-glass-plus"
          class="img-expand-btn"
          aria-label="View large photo"
          @click.stop="emit('preview-image', item.image_url)"
        >
          <q-tooltip>View large photo</q-tooltip>
        </q-btn>
      </div>
      <div v-if="item.barcode" class="line-card__id-row line-card__lead-span font-mono">
        <span class="line-card__id-k">BAR</span>
        <span class="line-card__id-v">{{ item.barcode }}</span>
      </div>
      <div v-if="item.product_code" class="line-card__id-row line-card__lead-span font-mono">
        <span class="line-card__id-k">CODE</span>
        <span class="line-card__id-v">{{ item.product_code }}</span>
      </div>
      <div v-if="item.product_id != null" class="line-card__id-row line-card__lead-span font-mono">
        <span class="line-card__id-k">ID</span>
        <span class="line-card__id-v">{{ item.product_id }}</span>
      </div>
      <q-btn
        v-if="showBatch"
        outline
        dense
        no-caps
        size="sm"
        class="line-card__batch-btn line-card__lead-span"
        :class="batchSummary.toneClass"
        @click.stop="emit('open-batch', item)"
      >
        <span class="line-card__batch-label">Batch</span>
        <span class="line-card__batch-num font-mono">{{
          batchSummary.lineCount > 0 ? batchSummary.compactLabel : '—'
        }}</span>
      </q-btn>
    </div>

    <div class="line-card__product">
      <div class="line-card__name">{{ item.name }}</div>
      <div v-if="item.style_code" class="line-card__style">{{ item.style_code }}</div>
      <div class="line-card__cell line-card__cell--plain">
        <span class="line-card__side-label">Product wt g</span>
        <q-input
          :model-value="getDraft('product_weight')"
          type="number"
          step="0.001"
          dense
          borderless
          input-class="font-mono text-center text-weight-bold excel-cell-input-native"
          class="excel-cell-input excel-cell-input--weight-tint"
          :disable="!canEditCosts"
          @update:model-value="(val) => emit('cell-input', item, 'product_weight', val)"
          @blur="emit('cell-blur', item, 'product_weight')"
          @keydown.enter="(e: Event) => (e.target as HTMLInputElement).blur()"
        />
      </div>
      <div class="line-card__cell line-card__cell--plain line-card__cell--package-wt">
        <span class="line-card__side-label">Package wt g</span>
        <q-input
          :model-value="getDraft('package_weight')"
          type="number"
          step="0.001"
          dense
          borderless
          input-class="font-mono text-center text-weight-bold excel-cell-input-native"
          class="excel-cell-input"
          :disable="!canEditCosts"
          @update:model-value="(val) => emit('cell-input', item, 'package_weight', val)"
          @blur="emit('cell-blur', item, 'package_weight')"
          @keydown.enter="(e: Event) => (e.target as HTMLInputElement).blur()"
        />
      </div>
    </div>

    <div class="line-card__grid">
      <div class="line-card__head">Price {{ currencySymbol }}</div>
      <div class="line-card__head">Cost</div>
      <div class="line-card__head">Qty</div>
      <div class="line-card__head line-card__head--hint">
        Stock impact
        <q-tooltip anchor="top middle" self="bottom middle">At receive: warehouse stock vs loss (not shelf condition)</q-tooltip>
      </div>
      <div class="line-card__head line-card__head--hint">
        Land reason
        <q-tooltip anchor="top middle" self="bottom middle">What arrived on the truck (fixed after receive)</q-tooltip>
      </div>
      <div class="line-card__head" />

      <div class="line-card__cell line-card__cell--plain">
        <q-input
          :model-value="getDraft('purchase_price')"
          type="number"
          step="0.01"
          dense
          borderless
          input-class="text-center font-mono text-weight-bold excel-cell-input-native"
          class="excel-cell-input excel-cell-input--price-tint"
          :disable="!canEditCosts"
          @update:model-value="(val) => emit('cell-input', item, 'purchase_price', val)"
          @blur="emit('cell-blur', item, 'purchase_price')"
          @keydown.enter="(e: Event) => (e.target as HTMLInputElement).blur()"
        />
      </div>
      <div class="line-card__cell line-card__cell--plain">
        <div class="line-card__num-fill line-card__num-fill--cost font-mono">
          {{ (item.landed_cost_bdt ?? item.unitCost ?? 0).toFixed(2) }}
        </div>
      </div>
      <div class="line-card__cell line-card__cell--plain">
        <q-input
          v-if="!isReceived"
          :model-value="getDraft('ordered_quantity')"
          type="number"
          min="1"
          step="1"
          dense
          borderless
          input-class="text-center font-mono text-weight-bold excel-cell-input-native"
          class="excel-cell-input excel-cell-input--qty-tint"
          :disable="!canEditStructure"
          @update:model-value="(val) => emit('cell-input', item, 'ordered_quantity', val)"
          @blur="emit('cell-blur', item, 'ordered_quantity')"
          @keydown.enter="(e: Event) => (e.target as HTMLInputElement).blur()"
        />
        <div v-else class="line-card__num-fill line-card__num-fill--qty font-mono">
          {{ item.ordered_quantity }}
        </div>
      </div>
      <div class="line-card__cell line-card__cell--plain">
        <span class="line-card__chip-btn line-card__chip-btn--row-ordered">Ordered</span>
      </div>
      <div />
      <div />

      <template v-for="row in extraOutcomes" :key="row.id">
        <div class="line-card__cell line-card__cell--plain">
          <q-input
            :model-value="row.purchase_price"
            type="number"
            step="0.01"
            dense
            borderless
            input-class="text-center font-mono text-weight-bold excel-cell-input-native"
            class="excel-cell-input excel-cell-input--price-tint"
            :disable="!canEditSplits"
            @change="(val: string | number | null) => onExtraNumber(row, 'purchase_price', val)"
          />
        </div>
        <div class="line-card__cell line-card__cell--plain">
          <div class="line-card__num-fill line-card__num-fill--cost font-mono text-slate-600">
            {{ extraCostBdt(row).toFixed(2) }}
          </div>
        </div>
        <div class="line-card__cell line-card__cell--plain">
          <q-input
            :model-value="row.quantity"
            type="number"
            min="0"
            step="1"
            dense
            borderless
            input-class="text-center font-mono text-weight-bold excel-cell-input-native"
            class="excel-cell-input excel-cell-input--qty-tint"
            :disable="!canEditSplits"
            @change="(val: string | number | null) => onExtraNumber(row, 'quantity', val)"
          />
        </div>
        <div class="line-card__cell line-card__cell--plain">
          <q-btn
            flat
            dense
            no-caps
            size="sm"
            class="line-card__chip-btn"
            :class="kindChipClass(row.kind)"
            :disable="!canEditSplits"
            :label="optionLabel(kindOptions, row.kind)"
          >
            <q-menu auto-close>
              <q-list dense style="min-width: 160px">
                <q-item
                  v-for="opt in kindOptions"
                  :key="opt.value"
                  clickable
                  v-close-popup
                  :active="row.kind === opt.value"
                  @click="emit('update-extra', row.id, { kind: opt.value })"
                >
                  <q-item-section>{{ opt.label }}</q-item-section>
                </q-item>
              </q-list>
            </q-menu>
          </q-btn>
        </div>
        <div class="line-card__cell line-card__cell--plain">
          <q-btn
            flat
            dense
            no-caps
            size="sm"
            class="line-card__chip-btn"
            :class="reasonChipClass(row.reason)"
            :disable="!canEditSplits || row.reason === 'vendor_discount'"
            :label="reasonLabel(row.reason)"
          >
            <q-menu auto-close>
              <q-list dense style="min-width: 180px">
                <q-item
                  v-for="opt in reasonOptions"
                  :key="opt.value"
                  clickable
                  v-close-popup
                  :active="row.reason === opt.value"
                  @click="emit('update-extra', row.id, { reason: opt.value })"
                >
                  <q-item-section>{{ opt.label }}</q-item-section>
                </q-item>
              </q-list>
            </q-menu>
          </q-btn>
        </div>
        <q-btn
          flat
          round
          dense
          size="xs"
          icon="ph ph-trash"
          color="negative"
          class="line-card__trash"
          aria-label="Remove split"
          :disable="!canEditSplits"
          @click="emit('delete-extra', row.id)"
        />
      </template>

      <div v-if="canAddSplit || canShowVendorDiscount" class="line-card__actions">
        <q-btn
          v-if="canAddSplit"
          flat
          dense
          no-caps
          size="sm"
          color="primary"
          icon="ph ph-plus"
          label="Add split"
          :disable="!canEditSplits"
          :loading="addingExtra"
          @click="emit('add-extra', item)"
        >
          <q-tooltip>Missing, damaged, or good qty when goods land</q-tooltip>
        </q-btn>

        <q-btn
          v-if="canShowVendorDiscount"
          flat
          dense
          no-caps
          size="sm"
          color="deep-orange-9"
          icon="ph ph-tag"
          label="Record vendor credit"
          :disable="!canEditLineCostFields"
          @click="emit('open-vendor-discount', item)"
        >
          <q-tooltip>Log vendor price credit (does not move stock)</q-tooltip>
        </q-btn>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import SmartImage from 'src/components/SmartImage.vue';
import type { ShipmentItemOutcome } from '../repositories/globalShipmentRepository';
import {
  OUTCOME_KIND_OPTIONS,
  OUTCOME_REASON_PICKER_OPTIONS,
  formatOutcomeReason,
} from '../constants/shipmentOutcomeLabels';

const props = defineProps<{
  item: Record<string, any>;
  extraOutcomes: ShipmentItemOutcome[];
  currencySymbol: string;
  canEditCosts: boolean;
  canEditLineCostFields: boolean;
  canEditStructure: boolean;
  isReceived: boolean;
  canAddSplit: boolean;
  canEditSplits: boolean;
  canShowVendorDiscount: boolean;
  showBatch: boolean;
  batchSummary: { compactLabel: string; lineCount: number; toneClass: string };
  addingExtra: boolean;
  getDraft: (field: string) => string | number | null;
}>();

const emit = defineEmits<{
  'toggle-select': [id: number, selected: boolean];
  'sl-change': [item: Record<string, any>, value: string];
  'preview-image': [url: string];
  'cell-input': [item: Record<string, any>, field: string, val: string | number | null];
  'cell-blur': [item: Record<string, any>, field: string];
  'open-batch': [item: Record<string, any>];
  'add-extra': [item: Record<string, any>];
  'open-vendor-discount': [item: Record<string, any>];
  'update-extra': [id: number, patch: Partial<ShipmentItemOutcome>];
  'delete-extra': [id: number];
}>();

const kindOptions = OUTCOME_KIND_OPTIONS;
const reasonOptions = OUTCOME_REASON_PICKER_OPTIONS;
const reasonLabel = formatOutcomeReason;

const optionLabel = (opts: { label: string; value: string }[], value: string) =>
  opts.find((opt) => opt.value === value)?.label ?? value;

const kindChipClass = (kind: string) =>
  kind === 'unsellable' ? 'line-card__chip-btn--kind-unsellable' : 'line-card__chip-btn--kind-sellable';

const reasonChipClass = (reason: string) => {
  switch (reason) {
    case 'vendor_discount':
      return 'line-card__chip-btn--reason-vendor-discount';
    case 'missing':
      return 'line-card__chip-btn--reason-missing';
    case 'damaged':
      return 'line-card__chip-btn--reason-damaged';
    case 'other':
      return 'line-card__chip-btn--reason-other';
    default:
      return 'line-card__chip-btn--reason-general';
  }
};

const orderedUnitCost = () =>
  Number(props.item.landed_cost_bdt ?? props.item.unitCost ?? 0) || 0;

const extraCostBdt = (row: ShipmentItemOutcome) => {
  const orderedPrice = Number(props.getDraft('purchase_price') ?? props.item.purchase_price) || 0;
  const splitPrice = Number(row.purchase_price) || 0;
  const base = orderedUnitCost();
  if (orderedPrice <= 0) return splitPrice > 0 ? splitPrice : base;
  return Math.round(base * (splitPrice / orderedPrice) * 100) / 100;
};

const onExtraNumber = (
  row: ShipmentItemOutcome,
  field: 'purchase_price' | 'quantity',
  val: string | number | null,
) => {
  const num = Number(val);
  if (!Number.isFinite(num) || num === Number(row[field])) return;
  if (field === 'purchase_price') {
    emit('update-extra', row.id, { purchase_price: num, cost: extraCostBdt({ ...row, purchase_price: num }) });
    return;
  }
  emit('update-extra', row.id, { quantity: num });
};
</script>

<style scoped>
.line-card {
  --line-card-value-h: 32px;
  display: grid;
  grid-template-columns: 18px 172px minmax(112px, 156px) minmax(0, 1.7fr);
  gap: 8px 8px;
  align-items: start;
  padding: 8px 10px;
  border: 1px solid var(--bw-theme-border);
  border-radius: 12px;
  background: #fff;
}
.line-card--selected {
  box-shadow: inset 3px 0 0 var(--bw-theme-primary);
  background: #fff;
}
.line-card__name {
  font-size: 14px;
  font-weight: 700;
  line-height: 1.25;
  color: var(--bw-theme-ink);
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.line-card__style {
  font-size: 11px;
  color: var(--bw-theme-muted);
}
.line-card__lead {
  display: grid;
  grid-template-columns: 40px 96px;
  column-gap: 6px;
  row-gap: 4px;
  align-items: start;
  min-width: 0;
}
.line-card__lead-sl {
  justify-self: center;
  align-self: start;
  margin-top: 2px;
}
.line-card__lead-img {
  justify-self: stretch;
}
.line-card__lead-span {
  grid-column: 1 / -1;
}
.line-card__id-row {
  display: grid;
  grid-template-columns: 36px minmax(0, 1fr);
  column-gap: 6px;
  width: 100%;
  font-size: 11px;
  line-height: 1.35;
  color: var(--bw-theme-muted);
}
.line-card__id-k {
  font-size: 9px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--bw-theme-muted);
}
.line-card__id-v {
  min-width: 0;
  color: var(--bw-theme-ink);
  font-weight: 600;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.line-card__batch-btn {
  margin-top: 4px;
  justify-content: space-between;
  border-radius: 8px;
  padding: 0 8px;
  min-height: 28px;
}
.line-card__batch-btn :deep(.q-btn__content) {
  width: 100%;
  justify-content: space-between;
  gap: 8px;
}
.line-card__batch-label {
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
  color: var(--bw-theme-muted);
}
.line-card__batch-num {
  font-size: 13px;
  font-weight: 800;
}
.line-card__product {
  display: flex;
  flex-direction: column;
  gap: 6px;
  min-width: 0;
}
.line-card__product .line-card__cell {
  width: 100%;
  min-height: var(--line-card-value-h);
  height: var(--line-card-value-h);
  padding: 0;
}
.line-card__cell--plain {
  background: transparent;
  padding-left: 0;
  padding-right: 0;
}
.line-card__cell--package-wt :deep(.q-field__control),
.excel-cell-input--weight-tint :deep(.q-field__control),
.excel-cell-input--price-tint :deep(.q-field__control),
.excel-cell-input--qty-tint :deep(.q-field__control) {
  box-shadow: none !important;
  border-radius: 6px;
}
.line-card__cell--package-wt :deep(.q-field__control) {
  background-color: transparent !important;
}
.line-card__cell--package-wt:hover :deep(.q-field__control),
.line-card__cell--package-wt :deep(.q-field--focused .q-field__control) {
  background-color: transparent !important;
}
.excel-cell-input--weight-tint :deep(.q-field__control) {
  background-color: color-mix(in srgb, var(--bw-ops-hue-weight) 78%, #fff) !important;
}
.excel-cell-input--price-tint :deep(.q-field__control) {
  background-color: color-mix(in srgb, var(--bw-ops-hue-price) 78%, #fff) !important;
}
.excel-cell-input--qty-tint :deep(.q-field__control) {
  background-color: color-mix(in srgb, var(--bw-ops-hue-qty) 78%, #fff) !important;
}
.excel-cell-input--weight-tint:hover :deep(.q-field__control) {
  background-color: color-mix(in srgb, var(--bw-ops-hue-weight) 88%, #fff) !important;
}
.excel-cell-input--price-tint:hover :deep(.q-field__control) {
  background-color: color-mix(in srgb, var(--bw-ops-hue-price) 88%, #fff) !important;
}
.excel-cell-input--qty-tint:hover :deep(.q-field__control) {
  background-color: color-mix(in srgb, var(--bw-ops-hue-qty) 88%, #fff) !important;
}
.excel-cell-input--weight-tint.q-field--focused :deep(.q-field__control) {
  background-color: color-mix(in srgb, var(--bw-ops-hue-weight) 88%, #fff) !important;
  border: 1.5px solid var(--bw-ops-accent-weight) !important;
  box-shadow: none !important;
}
.excel-cell-input--price-tint.q-field--focused :deep(.q-field__control) {
  background-color: color-mix(in srgb, var(--bw-ops-hue-price) 88%, #fff) !important;
  border: 1.5px solid var(--bw-ops-accent-price) !important;
  box-shadow: none !important;
}
.excel-cell-input--qty-tint.q-field--focused :deep(.q-field__control) {
  background-color: color-mix(in srgb, var(--bw-ops-hue-qty) 88%, #fff) !important;
  border: 1.5px solid var(--bw-ops-accent-qty) !important;
  box-shadow: none !important;
}
.line-card__num-fill {
  flex: 1 1 auto;
  min-width: 0;
  width: 100%;
  height: var(--line-card-value-h);
  min-height: var(--line-card-value-h);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 6px;
  border-radius: 6px;
  text-align: center;
  font-size: 13px;
  font-weight: 700;
}
.line-card__num-fill--cost {
  background-color: color-mix(in srgb, var(--bw-ops-hue-cost) 78%, #fff);
}
.line-card__num-fill--qty {
  background-color: color-mix(in srgb, var(--bw-ops-hue-qty) 78%, #fff);
}
.line-card__grid .line-card__cell--plain {
  padding-left: 0;
  padding-right: 0;
}
.line-card__grid {
  display: grid;
  grid-template-columns: minmax(72px, 0.85fr) minmax(80px, 0.9fr) minmax(56px, 0.65fr) minmax(88px, 0.95fr) minmax(96px, 1fr) 28px;
  gap: 4px 6px;
  align-items: center;
  min-width: 0;
}
.line-card__grid > *:not(.line-card__head):not(.line-card__actions) {
  min-height: var(--line-card-value-h);
  height: var(--line-card-value-h);
}
.line-card__grid > .line-card__cell {
  padding: 0;
}
.line-card__head {
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.03em;
  text-transform: uppercase;
  color: var(--bw-theme-muted);
  padding: 4px 4px;
  line-height: 1;
  background: #fff;
  border-radius: 4px;
  text-align: center;
  display: flex;
  align-items: center;
  justify-content: center;
}
.line-card__head--hint {
  cursor: help;
  text-decoration: underline dotted rgba(0, 0, 0, 0.25);
  text-underline-offset: 2px;
}
.line-card__cell {
  min-width: 0;
  min-height: var(--line-card-value-h);
  display: flex;
  flex-direction: row;
  align-items: center;
  gap: 4px;
  border-radius: 6px;
  padding: 0 4px;
}
.line-card__side-label {
  flex: 0 0 auto;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
  color: var(--bw-theme-muted);
  white-space: nowrap;
}
.line-card__value {
  flex: 1 1 auto;
  min-width: 0;
  text-align: right;
  font-size: 13px;
  font-weight: 700;
}
.line-card__chip-btn--row-ordered {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: var(--line-card-value-h);
  min-height: var(--line-card-value-h);
  padding: 0 8px;
  background: color-mix(in srgb, var(--bw-theme-ink) 8%, #fff);
  color: var(--bw-theme-ink);
  border-color: var(--bw-theme-border);
  font-size: 12px;
}
.line-card__actions {
  grid-column: 1 / -1;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
  margin-top: 2px;
}
.line-card__add {
  grid-column: 1 / 4;
  justify-self: start;
  margin-top: 2px;
}
.line-card__trash {
  justify-self: center;
}
.line-card__chip-btn {
  flex: 1 1 auto;
  min-width: 0;
  width: 100%;
  height: var(--line-card-value-h);
  min-height: var(--line-card-value-h);
  border-radius: 8px;
  border: 1px solid transparent;
  font-weight: 700;
}
.line-card__chip-btn :deep(.q-btn__content) {
  justify-content: center;
}
.line-card__chip-btn--kind-sellable {
  background: color-mix(in srgb, #10b981 24%, #fff);
  color: #047857;
  border-color: color-mix(in srgb, #10b981 42%, var(--bw-theme-border));
}
.line-card__chip-btn--kind-unsellable {
  background: color-mix(in srgb, #ef4444 22%, #fff);
  color: #b91c1c;
  border-color: color-mix(in srgb, #ef4444 40%, var(--bw-theme-border));
}
.line-card__chip-btn--reason-general {
  background: color-mix(in srgb, var(--bw-theme-ink) 8%, #fff);
  color: var(--bw-theme-ink);
  border-color: var(--bw-theme-border);
}
.line-card__chip-btn--reason-vendor-discount {
  background: color-mix(in srgb, #14b8a6 22%, #fff);
  color: #0f766e;
  border-color: color-mix(in srgb, #14b8a6 40%, var(--bw-theme-border));
}
.line-card__chip-btn--reason-missing {
  background: color-mix(in srgb, #f59e0b 26%, #fff);
  color: #b45309;
  border-color: color-mix(in srgb, #f59e0b 44%, var(--bw-theme-border));
}
.line-card__chip-btn--reason-damaged {
  background: color-mix(in srgb, #f97316 24%, #fff);
  color: #c2410c;
  border-color: color-mix(in srgb, #f97316 42%, var(--bw-theme-border));
}
.line-card__chip-btn--reason-other {
  background: color-mix(in srgb, #6366f1 22%, #fff);
  color: #4338ca;
  border-color: color-mix(in srgb, #6366f1 40%, var(--bw-theme-border));
}
.line-card__cell :deep(.excel-cell-input),
.line-card__cell :deep(.q-field) {
  flex: 1 1 auto;
  min-width: 0;
  width: 100%;
  height: var(--line-card-value-h);
}
.line-card__cell :deep(.q-field__inner) {
  min-height: var(--line-card-value-h);
}
.line-card__cell :deep(.q-field__control) {
  min-height: var(--line-card-value-h) !important;
  height: var(--line-card-value-h) !important;
  padding: 0 4px !important;
}
.line-card__cell :deep(.q-field__native),
.line-card__cell :deep(.excel-cell-input-native) {
  text-align: center !important;
  min-height: var(--line-card-value-h);
  line-height: var(--line-card-value-h);
  padding: 0 !important;
}
.line-card__cell :deep(.q-field__marginal) {
  height: var(--line-card-value-h);
}
.item-img-container {
  position: relative;
  width: 96px;
  height: 96px;
  max-width: 96px;
  max-height: 96px;
  border-radius: 8px;
  overflow: hidden;
  background: var(--bw-neutral-surface-subtle, #f1f5f9);
  border: 1px solid var(--bw-theme-border);
}
.item-img-container :deep(.item-img-smart),
.item-img-container :deep(.smart-image-wrapper),
.item-img-container :deep(.smart-image__img),
.item-img-container :deep(.item-img-element),
.item-img-container :deep(img) {
  width: 100% !important;
  height: 100% !important;
  max-width: 100% !important;
  max-height: 100% !important;
  object-fit: contain !important;
}
.img-expand-btn {
  position: absolute;
  bottom: 1px;
  right: 1px;
  background: rgba(15, 23, 42, 0.7);
  color: #fff !important;
}
.sl-input {
  width: 36px;
  height: 32px;
  text-align: center;
  font-size: 16px;
  font-weight: 700;
  border: 1px solid transparent;
  border-radius: 4px;
  background: transparent;
}
</style>
