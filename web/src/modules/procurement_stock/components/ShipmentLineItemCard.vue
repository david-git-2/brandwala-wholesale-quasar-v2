<template>
  <div
    class="line-card"
    :class="{
      'line-card--selected': item.selected,
      'line-card--outcomes': showOutcomeColumns,
      'line-card--actions': showActionsColumn,
      'line-card--land-attention': !!landSplitAttention,
    }"
    :style="{ '--line-card-rows': 1 + extraOutcomes.length + vendorCredits.length }"
  >
    <div class="line-card__lead" @click.stop>
    <div class="line-card__select" @click.stop>
      <q-checkbox
        :model-value="item.selected"
        dense
        size="xs"
        @update:model-value="(val) => emit('toggle-select', item.id, !!val)"
      />
    </div>

    <input
      :value="item.sl"
      type="number"
      min="1"
      class="sl-input font-mono"
      aria-label="Line number"
      @click.stop
      @change="(e) => emit('sl-change', item, (e.target as HTMLInputElement).value)"
      @keydown.enter="(e) => (e.target as HTMLInputElement).blur()"
    />

    <div class="item-img-container" @click.stop="copyBarcode">
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

    <div class="line-card__product">
      <div class="line-card__name">{{ item.name }}</div>
      <div
        v-if="item.barcode"
        class="line-card__id-row line-card__id-row--copy font-mono"
        @click.stop="copyBarcode"
      >
        <span class="line-card__id-k">BAR</span>
        <span class="line-card__id-v">{{ item.barcode }}</span>
      </div>
      <div
        v-if="item.product_code"
        class="line-card__id-row line-card__id-row--copy font-mono"
        @click.stop="copyProductCode"
      >
        <span class="line-card__id-k">CODE</span>
        <span class="line-card__id-v">{{ item.product_code }}</span>
      </div>
      <div
        v-if="item.product_id != null"
        class="line-card__id-row line-card__id-row--copy font-mono"
        @click.stop="copyProductId"
      >
        <span class="line-card__id-k">ID</span>
        <span class="line-card__id-v">{{ item.product_id }}</span>
      </div>
      <div v-if="item.style_code" class="line-card__style">{{ item.style_code }}</div>
      <div v-if="landSplitAttention" class="line-card__land-attention" @click.stop>
        <q-icon name="ph ph-warning" size="14px" />
        <span>{{ landSplitAttention }}</span>
      </div>
      <div v-if="showBatch" class="line-card__product-actions" @click.stop>
        <q-btn
          outline
          dense
          no-caps
          size="sm"
          class="line-card__batch-btn"
          :class="batchSummary.toneClass"
          @click="emit('open-batch', item)"
        >
          <span class="line-card__batch-label">Batch</span>
          <span class="line-card__batch-num font-mono">{{
            batchSummary.lineCount > 0 ? batchSummary.compactLabel : '—'
          }}</span>
        </q-btn>
      </div>
    </div>
    </div>

    <div class="line-card__metrics-stack">
    <div class="line-card__metric-row">
    <div class="line-card__cell" @click.stop>
      <q-input
        :model-value="blankZero(getDraft('product_weight'))"
        type="number"
        step="0.001"
        dense
        borderless
        placeholder="—"
        input-class="font-mono text-right excel-cell-input-native"
        class="excel-cell-input excel-cell-input--weight-tint"
        :disable="!canEditCosts"
        @update:model-value="(val) => emit('cell-input', item, 'product_weight', val)"
        @blur="emit('cell-blur', item, 'product_weight')"
        @keydown.enter="(e: Event) => (e.target as HTMLInputElement).blur()"
      />
    </div>
    <div class="line-card__cell" @click.stop>
      <q-input
        :model-value="blankZero(getDraft('package_weight'))"
        type="number"
        step="0.001"
        dense
        borderless
        placeholder="—"
        input-class="font-mono text-right excel-cell-input-native"
        class="excel-cell-input"
        :disable="!canEditCosts"
        @update:model-value="(val) => emit('cell-input', item, 'package_weight', val)"
        @blur="emit('cell-blur', item, 'package_weight')"
        @keydown.enter="(e: Event) => (e.target as HTMLInputElement).blur()"
      />
    </div>

    <div class="line-card__cell" @click.stop>
      <q-input
        :model-value="getDraft('purchase_price')"
        type="number"
        step="0.01"
        dense
        borderless
        input-class="font-mono text-right excel-cell-input-native"
        class="excel-cell-input excel-cell-input--price-tint"
        :disable="!canEditCosts"
        @update:model-value="(val) => emit('cell-input', item, 'purchase_price', val)"
        @blur="emit('cell-blur', item, 'purchase_price')"
        @keydown.enter="(e: Event) => (e.target as HTMLInputElement).blur()"
      />
    </div>
    <div class="line-card__cell" @click.stop>
      <div class="line-card__num-fill line-card__num-fill--cost font-mono">
        {{ (item.landed_cost_bdt ?? item.unitCost ?? 0).toFixed(2) }}
      </div>
    </div>
    <div class="line-card__cell" @click.stop>
      <q-input
        v-if="!isReceived"
        :model-value="getDraft('ordered_quantity')"
        type="number"
        min="1"
        step="1"
        dense
        borderless
        input-class="font-mono text-right excel-cell-input-native"
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
    <template v-if="showOutcomeColumns">
      <div class="line-card__paper-tag">Paper</div>
      <div class="line-card__paper-tag">—</div>
      <div />
    </template>

    <div
      v-if="showActionsColumn"
      class="line-card__trailing-actions"
      @click.stop
    >
      <q-btn
        v-if="canAddSplit"
        flat
        dense
        no-caps
        size="sm"
        color="primary"
        icon="ph ph-plus"
        label="Add split"
        class="line-card__split-btn"
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
        label="Vendor credit"
        :disable="!canEditLineCostFields"
        @click="emit('open-vendor-discount', item)"
      >
        <q-tooltip>Log vendor price credit (does not move stock)</q-tooltip>
      </q-btn>
    </div>
    </div>

    <div
      v-for="row in extraOutcomes"
      :key="row.id"
      class="line-card__metric-row line-card__metric-row--split"
      @click.stop
    >
      <div class="line-card__metric-pad" aria-hidden="true" />
      <div class="line-card__metric-pad" aria-hidden="true" />
        <div class="line-card__cell" @click.stop>
          <q-input
            :model-value="row.purchase_price"
            type="number"
            step="0.01"
            dense
            borderless
            input-class="font-mono text-right excel-cell-input-native"
            class="excel-cell-input excel-cell-input--price-tint"
            :disable="!canEditSplits"
            @change="(val: string | number | null) => onExtraNumber(row, 'purchase_price', val)"
          />
        </div>
        <div class="line-card__cell" @click.stop>
          <div class="line-card__num-fill line-card__num-fill--cost font-mono text-slate-600">
            {{ extraCostBdt(row).toFixed(2) }}
          </div>
        </div>
        <div class="line-card__cell" @click.stop>
          <q-input
            :model-value="row.quantity"
            type="number"
            min="0"
            step="1"
            dense
            borderless
            input-class="font-mono text-right excel-cell-input-native"
            class="excel-cell-input excel-cell-input--qty-tint"
            :disable="!canEditSplits"
            @change="(val: string | number | null) => onExtraNumber(row, 'quantity', val)"
          />
        </div>
        <div class="line-card__cell" @click.stop>
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
        <div class="line-card__cell" @click.stop>
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
      <div v-if="showActionsColumn" class="line-card__metric-pad" aria-hidden="true" />
    </div>

    <div
      v-for="credit in vendorCredits"
      :key="`vc-${credit.id}`"
      class="line-card__metric-row line-card__metric-row--vendor-credit"
      @click.stop
    >
      <div class="line-card__metric-pad" aria-hidden="true" />
      <div class="line-card__metric-pad" aria-hidden="true" />
      <div class="line-card__cell">
        <div class="line-card__num-fill line-card__num-fill--price font-mono">
          {{ Number(credit.new_purchase_price).toFixed(2) }}
        </div>
      </div>
      <div class="line-card__cell">
        <div class="line-card__num-fill line-card__num-fill--cost font-mono text-slate-600">
          {{ vendorCreditCostBdt(credit).toFixed(2) }}
        </div>
      </div>
      <div class="line-card__cell">
        <div class="line-card__num-fill line-card__num-fill--qty font-mono">
          {{ credit.quantity }}
        </div>
      </div>
      <div class="line-card__cell">
        <span class="line-card__chip-btn line-card__chip-btn--vendor-credit">Vendor credit</span>
      </div>
      <div class="line-card__cell">
        <span class="line-card__chip-btn line-card__chip-btn--reason-vendor-discount text-caption">
          {{ currencySymbol }}{{ Number(credit.previous_purchase_price).toFixed(2) }}
          → {{ Number(credit.new_purchase_price).toFixed(2) }}
        </span>
      </div>
      <q-btn
        v-if="showActionsColumn"
        flat
        round
        dense
        size="xs"
        icon="ph ph-trash"
        color="negative"
        class="line-card__trash"
        aria-label="Remove vendor credit"
        :disable="!canDeleteVendorCredit"
        @click="emit('delete-vendor-credit', credit.id)"
      />
      <div v-if="showActionsColumn" class="line-card__metric-pad" aria-hidden="true" />
    </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { copyToClipboard } from 'quasar';
import SmartImage from 'src/components/SmartImage.vue';
import { showSuccessNotification } from 'src/utils/appFeedback';
import type {
  ShipmentItemOutcome,
  ShipmentOutcomeVendorCredit,
} from '../repositories/globalShipmentRepository';
import {
  OUTCOME_KIND_OPTIONS,
  OUTCOME_REASON_PICKER_OPTIONS,
  formatOutcomeReason,
} from '../constants/shipmentOutcomeLabels';

const props = defineProps<{
  item: Record<string, any>;
  extraOutcomes: ShipmentItemOutcome[];
  vendorCredits: ShipmentOutcomeVendorCredit[];
  currencySymbol: string;
  canEditCosts: boolean;
  canEditLineCostFields: boolean;
  canEditStructure: boolean;
  isReceived: boolean;
  canAddSplit: boolean;
  canEditSplits: boolean;
  canShowVendorDiscount: boolean;
  canDeleteVendorCredit: boolean;
  showBatch: boolean;
  showOutcomeColumns: boolean;
  showActionsColumn: boolean;
  landSplitAttention?: string | null;
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
  'delete-vendor-credit': [id: number];
}>();

const kindOptions = OUTCOME_KIND_OPTIONS;
const reasonOptions = OUTCOME_REASON_PICKER_OPTIONS;
const reasonLabel = formatOutcomeReason;

const copyText = (text: string | number | null | undefined, label: string) => {
  if (text === null || text === undefined || text === '') return;
  void copyToClipboard(String(text)).then(() => {
    showSuccessNotification(`Copied ${label}`);
  });
};

const copyBarcode = () => copyText(props.item.barcode, 'barcode');
const copyProductCode = () => copyText(props.item.product_code, 'product code');
const copyProductId = () => copyText(props.item.product_id, 'product ID');

const blankZero = (val: string | number | null) => {
  if (val === null || val === '') return '';
  const num = Number(val);
  if (Number.isFinite(num) && num === 0) return '';
  return val;
};

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

const scaledUnitCostBdt = (purchasePrice: number) => {
  const orderedPrice = Number(props.getDraft('purchase_price') ?? props.item.purchase_price) || 0;
  const splitPrice = Number(purchasePrice) || 0;
  const base = orderedUnitCost();
  if (orderedPrice <= 0) return splitPrice > 0 ? splitPrice : base;
  return Math.round(base * (splitPrice / orderedPrice) * 100) / 100;
};

const extraCostBdt = (row: ShipmentItemOutcome) => scaledUnitCostBdt(Number(row.purchase_price));

const vendorCreditCostBdt = (credit: ShipmentOutcomeVendorCredit) =>
  scaledUnitCostBdt(Number(credit.new_purchase_price));

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
  --line-cols: 22px 32px 1in minmax(220px, 1fr) 68px 68px 76px 76px 60px;
  --metric-tail-cols: 68px 68px 76px 76px 60px;
  display: grid;
  grid-template-columns: var(--line-cols);
  column-gap: 8px;
  row-gap: 0;
  align-items: start;
  padding: 6px 8px;
  border-bottom: 1px solid var(--bw-theme-border);
  background: #fff;
}
.line-card__lead {
  grid-column: 1 / 5;
  grid-row: 1 / span var(--line-card-rows);
  display: grid;
  grid-template-columns: 22px 32px 1in minmax(0, 1fr);
  column-gap: 8px;
  align-items: start;
  min-width: 0;
}
.line-card__metrics-stack {
  grid-column: 5 / -1;
  grid-row: 1 / span var(--line-card-rows);
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}
.line-card__metric-row {
  display: grid;
  grid-template-columns: var(--metric-tail-cols);
  column-gap: 8px;
  align-items: center;
}
.line-card__metric-pad {
  min-height: var(--line-card-value-h);
}
.line-card--actions:not(.line-card--outcomes) {
  --line-cols: 22px 32px 1in minmax(220px, 1fr) 68px 68px 76px 76px 60px 96px;
  --metric-tail-cols: 68px 68px 76px 76px 60px 96px;
}
.line-card--outcomes {
  --line-cols: 22px 32px 1in minmax(200px, 1fr) 68px 68px 76px 76px 60px 92px 104px 24px;
  --metric-tail-cols: 68px 68px 76px 76px 60px 92px 104px 24px;
}
.line-card--outcomes.line-card--actions {
  --line-cols: 22px 32px 1in minmax(200px, 1fr) 68px 68px 76px 76px 60px 92px 104px 24px 96px;
  --metric-tail-cols: 68px 68px 76px 76px 60px 92px 104px 24px 96px;
}
.line-card--selected {
  box-shadow: inset 3px 0 0 var(--bw-theme-primary);
  background: color-mix(in srgb, var(--bw-theme-primary) 4%, #fff);
}
.line-card--land-attention {
  box-shadow: inset 3px 0 0 var(--bw-warning, #b45309);
  background: color-mix(in srgb, var(--bw-warning, #b45309) 6%, #fff);
}
.line-card__land-attention {
  display: flex;
  align-items: flex-start;
  gap: 4px;
  margin-top: 2px;
  padding: 2px 6px;
  border-radius: 6px;
  font-size: 11px;
  font-weight: 600;
  line-height: 1.3;
  color: #b45309;
  background: color-mix(in srgb, #f59e0b 18%, #fff);
}
.line-card__name {
  font-size: 13px;
  font-weight: 650;
  line-height: 1.25;
  color: var(--bw-theme-ink);
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.line-card__id-row {
  display: grid;
  grid-template-columns: 36px minmax(0, 1fr);
  column-gap: 6px;
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
}
.line-card__id-row--copy {
  cursor: pointer;
  border-radius: 4px;
}
.line-card__id-row--copy:hover {
  background: color-mix(in srgb, var(--bw-theme-ink) 6%, #fff);
}
.line-card__style {
  font-size: 11px;
  line-height: 1.3;
  color: var(--bw-theme-muted);
}
.line-card__product {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
  padding-top: 2px;
}
.line-card__product-actions {
  margin-top: 2px;
}
.line-card__trailing-actions {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  justify-content: flex-start;
  gap: 2px;
  padding-top: 2px;
  min-width: 0;
}
.line-card__split-btn {
  white-space: nowrap;
}
.line-card__batch-btn {
  align-self: start;
  margin-top: 2px;
  min-height: 28px;
  padding: 0 8px;
  border-radius: 8px;
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
  font-size: 12px;
  font-weight: 800;
}
.line-card__cell {
  min-width: 0;
  min-height: var(--line-card-value-h);
  display: flex;
  align-items: center;
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
  padding: 0 6px !important;
  border-radius: 6px;
}
.line-card__cell :deep(.q-field__native),
.line-card__cell :deep(.excel-cell-input-native) {
  text-align: right !important;
  min-height: var(--line-card-value-h);
  line-height: var(--line-card-value-h);
  padding: 0 !important;
  font-size: 14px;
  font-weight: 700;
}
.line-card__cell :deep(.q-field__marginal) {
  height: var(--line-card-value-h);
}
.excel-cell-input--weight-tint :deep(.q-field__control) {
  background-color: color-mix(in srgb, var(--bw-ops-hue-weight) 42%, #fff) !important;
}
.excel-cell-input--price-tint :deep(.q-field__control) {
  background-color: color-mix(in srgb, var(--bw-ops-hue-price) 42%, #fff) !important;
}
.excel-cell-input--qty-tint :deep(.q-field__control) {
  background-color: color-mix(in srgb, var(--bw-ops-hue-qty) 42%, #fff) !important;
}
.line-card__num-fill {
  width: 100%;
  height: var(--line-card-value-h);
  display: flex;
  align-items: center;
  justify-content: flex-end;
  padding: 0 6px;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 700;
}
.line-card__num-fill--cost {
  background-color: color-mix(in srgb, var(--bw-ops-hue-cost) 42%, #fff);
}
.line-card__num-fill--qty {
  background-color: color-mix(in srgb, var(--bw-ops-hue-qty) 42%, #fff);
}
.line-card__num-fill--price {
  background-color: color-mix(in srgb, var(--bw-ops-hue-price) 42%, #fff);
}
.line-card__num-fill--vendor-credit {
  background-color: color-mix(in srgb, #14b8a6 28%, #fff);
  color: #0f766e;
}
.line-card__chip-btn--vendor-credit {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: var(--line-card-value-h);
  padding: 0 6px;
  font-size: 11px;
  font-weight: 700;
  background: color-mix(in srgb, #14b8a6 22%, #fff);
  color: #0f766e;
  border: 1px solid color-mix(in srgb, #14b8a6 40%, var(--bw-theme-border));
  border-radius: 8px;
}
.line-card__metric-row--vendor-credit .line-card__chip-btn--reason-vendor-discount {
  height: auto;
  min-height: var(--line-card-value-h);
  white-space: normal;
  line-height: 1.2;
  padding: 2px 6px;
}
.line-card__paper-tag {
  font-size: 11px;
  font-weight: 600;
  color: var(--bw-theme-muted);
  text-align: center;
}
.line-card__actions {
  grid-column: 1 / -1;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 4px;
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
  font-size: 12px;
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
.item-img-container {
  position: relative;
  cursor: pointer;
  width: 1in;
  height: 1in;
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
  object-fit: contain !important;
}
.img-expand-btn {
  position: absolute;
  bottom: 0;
  right: 0;
  background: rgba(15, 23, 42, 0.7);
  color: #fff !important;
}
.sl-input {
  width: 32px;
  height: 28px;
  margin-top: 10px;
  text-align: center;
  font-size: 13px;
  font-weight: 700;
  border: 1px solid transparent;
  border-radius: 4px;
  background: transparent;
}
.line-card__select {
  padding-top: 14px;
}
</style>
