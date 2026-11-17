<template>
  <div class="demand-buy-lines column no-wrap">
    <q-table
      flat
      :rows="tableRows"
      :columns="columns"
      row-key="rowKey"
      hide-pagination
      :pagination="{ rowsPerPage: 0 }"
      class="demand-buy-lines__table shipment-items-markup-table shipment-details-table demand-buy-doc-table"
    >
      <template #body="bp">
        <q-tr :props="bp">
          <q-td key="select" :props="bp" class="demand-buy-lines__select">
            <q-checkbox
              dense
              :model-value="!!props.selectedLineKeys[bp.row.rowKey]"
              @update:model-value="(v) => toggleLineSelect(bp.row, v)"
            />
          </q-td>
          <q-td
            key="sl"
            :props="bp"
            class="demand-line-col demand-line-num text-center text-grey-7 text-weight-medium font-mono"
          >
            {{ bp.rowIndex + 1 }}
          </q-td>
          <q-td key="product" :props="bp" class="demand-buy-lines__product">
            <div class="demand-buy-lines__product-inner">
              <div class="demand-buy-lines__thumb-wrap">
                <SmartImage
                  :src="bp.row.image_url"
                  :alt="bp.row.name"
                  img-class="demand-buy-lines__thumb"
                  fallback-class="demand-buy-lines__thumb-fallback"
                  :enable-edit="false"
                />
              </div>
              <div class="min-width-0 demand-buy-lines__product-text">
                <div class="text-weight-medium demand-buy-lines__name">{{ bp.row.name }}</div>
                <div
                  v-if="bp.row.product_code"
                  class="demand-buy-lines__meta text-caption text-grey-7 font-mono cursor-pointer"
                  role="button"
                  tabindex="0"
                  :title="`Copy SKU ${bp.row.product_code}`"
                  @click.stop="copySku(bp.row.product_code)"
                  @keydown.enter.stop="copySku(bp.row.product_code)"
                >
                  <q-icon name="ph ph-hash" size="12px" class="col-shrink" />
                  <span class="ellipsis">{{ bp.row.product_code }}</span>
                </div>
                <div
                  v-if="bp.row.barcode"
                  class="demand-buy-lines__meta text-caption text-grey-7 font-mono cursor-pointer"
                  role="button"
                  tabindex="0"
                  :title="`Copy barcode ${bp.row.barcode}`"
                  @click.stop="copyBarcode(bp.row.barcode)"
                  @keydown.enter.stop="copyBarcode(bp.row.barcode)"
                >
                  <q-icon name="ph ph-barcode" size="12px" class="col-shrink" />
                  <span class="ellipsis">{{ bp.row.barcode }}</span>
                </div>
              </div>
            </div>
          </q-td>
          <q-td
            key="need"
            :props="bp"
            class="text-center q-pa-none"
            :class="qtySummaryCellClass(bp.row)"
          >
            <div class="demand-excel-readonly font-mono text-weight-bold text-grey-9">
              {{ needQty(bp.row) }}
            </div>
          </q-td>
          <q-td
            key="orderPrice"
            :props="bp"
            class="text-center q-pa-none"
            :class="orderPriceCellClass(bp.row)"
          >
            <div class="demand-excel-readonly font-mono text-weight-bold text-grey-9">
              {{ formatOrderUnitPrice(bp.row) }}
            </div>
          </q-td>
          <q-td
            key="placed"
            :props="bp"
            class="text-center q-pa-none"
            :class="qtySummaryCellClass(bp.row)"
          >
            <div class="demand-excel-readonly font-mono text-weight-bold text-grey-9">
              {{ sumPlacementDraftQty(getDraft(bp.row).placements) }}
            </div>
          </q-td>
          <q-td
            key="remaining"
            :props="bp"
            class="text-center q-pa-none"
            :class="qtySummaryCellClass(bp.row)"
          >
            <div class="demand-excel-readonly font-mono text-weight-bold text-grey-9">
              {{ Math.max(needQty(bp.row) - sumPlacementDraftQty(getDraft(bp.row).placements), 0) }}
            </div>
          </q-td>
          <q-td key="vendors" :props="bp" class="demand-vendor-col q-pa-sm">
            <div class="demand-buy-lines__placement-stack">
              <div
                v-for="(pl, idx) in getDraft(bp.row).placements"
                :key="`${bp.row.rowKey}-pl-${idx}`"
                class="demand-buy-lines__placement-row"
              >
                <q-input
                  :model-value="pl.quantity"
                  type="number"
                  min="0"
                  borderless
                  dense
                  hide-bottom-space
                  placeholder="Qty"
                  class="excel-cell-input demand-buy-field--qty"
                  :class="qtyInputTintClass(bp.row)"
                  input-class="font-mono text-weight-bold excel-cell-input-native text-center"
                  @update:model-value="(v) => onQtyChange(bp.row, idx, v)"
                />
                <q-input
                  :model-value="placementUnitPrice(bp.row, pl)"
                  type="number"
                  min="0"
                  step="any"
                  borderless
                  dense
                  hide-bottom-space
                  prefix="£"
                  class="excel-cell-input demand-buy-field--price"
                  :class="priceInputTintClass(bp.row, pl)"
                  input-class="font-mono excel-cell-input-native"
                  @update:model-value="(v) => onPriceChange(bp.row, idx, v)"
                />
                <q-select
                  :model-value="pl.vendorCode || null"
                  :options="vendorCodeOptions"
                  option-value="code"
                  option-label="label"
                  emit-value
                  map-options
                  borderless
                  dense
                  options-dense
                  hide-bottom-space
                  clearable
                  use-input
                  input-debounce="200"
                  placeholder="Vendor"
                  input-class="font-mono excel-cell-input-native"
                  class="excel-cell-input demand-buy-field--vendor"
                  @filter="onFilterVendors"
                  @update:model-value="(v) => onVendorCodeChange(bp.row, idx, v)"
                />
                <q-btn
                  v-if="getDraft(bp.row).placements.length > 1"
                  flat
                  round
                  dense
                  size="sm"
                  icon="ph ph-trash"
                  color="grey-8"
                  class="demand-buy-lines__remove-vendor"
                  aria-label="Remove vendor row"
                  @click="removePlacementRow(bp.row, idx)"
                />
              </div>
              <q-btn
                flat
                dense
                round
                size="sm"
                color="primary"
                icon="ph ph-plus"
                aria-label="Add vendor"
                class="demand-buy-lines__add-vendor"
                @click="addPlacementRow(bp.row)"
              />
            </div>
          </q-td>
        </q-tr>
      </template>
    </q-table>
    <div ref="scrollSentinelRef" class="demand-scroll-sentinel" aria-hidden="true" />
    <div v-if="isFetchingNextPage" class="row justify-center q-py-sm">
      <q-spinner-dots size="20px" color="primary" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue';
import { copyToClipboard } from 'quasar';
import SmartImage from 'src/components/SmartImage.vue';
import { showSuccessNotification } from 'src/utils/appFeedback';
import { formatSettlementCurrencyAmount } from 'src/utils/currency';
import type { ProcurementDemandItem } from '../repositories/procurementDemandRepository';
import {
  type DemandBuyLineDraft,
  type VendorPlacementDraft,
  coalescePlacementUnitPrice,
  emptyPlacementForItem,
  itemDraftKey,
  defaultVendorCodeForItem,
  orderLineUnitPrice,
  sumPlacementDraftQty,
} from '../utils/demandBuyPlacements';

type ItemRow = ProcurementDemandItem & { rowKey: string };

const props = defineProps<{
  items: ProcurementDemandItem[];
  lineDrafts: Record<string, DemandBuyLineDraft>;
  vendorCodeOptions: Array<{ code: string; label: string }>;
  selectedLineKeys: Record<string, boolean>;
  isFetchingNextPage?: boolean;
}>();

const emit = defineEmits<{
  'filter-vendors': [val: string, update: (fn: () => void) => void];
  'update-draft': [item: ProcurementDemandItem, draft: DemandBuyLineDraft];
  'toggle-line-select': [item: ProcurementDemandItem, selected: boolean];
  'load-more': [];
}>();

const scrollSentinelRef = ref<HTMLElement | null>(null);
let scrollObserver: IntersectionObserver | null = null;

const columns = [
  { name: 'select', label: '', field: 'rowKey', align: 'left' as const },
  {
    name: 'sl',
    label: 'SL',
    field: 'rowKey',
    align: 'center' as const,
    headerClasses: 'demand-line-col',
    classes: 'demand-line-col',
  },
  { name: 'product', label: 'Product', field: 'name', align: 'left' as const },
  { name: 'need', label: 'Need', field: 'quantity', align: 'center' as const },
  { name: 'orderPrice', label: 'Order £', align: 'center' as const },
  { name: 'placed', label: 'Placed', align: 'center' as const },
  { name: 'remaining', label: 'Left', align: 'center' as const },
  { name: 'vendors', label: 'Vendor orders', align: 'left' as const },
];

const tableRows = computed<ItemRow[]>(() =>
  props.items.map((item) => ({
    ...item,
    rowKey: itemDraftKey(item),
  })),
);

const needQty = (item: ProcurementDemandItem) =>
  item.need_quantity ?? item.quantity ?? 0;

const getDraft = (item: ProcurementDemandItem): DemandBuyLineDraft =>
  props.lineDrafts[itemDraftKey(item)] ?? { placements: [emptyPlacementForItem(item)] };

const formatOrderUnitPrice = (item: ProcurementDemandItem) => {
  const amount = orderLineUnitPrice(item);
  return amount == null ? '—' : formatSettlementCurrencyAmount(amount, 'GBP');
};

const placementUnitPrice = (item: ProcurementDemandItem, pl: VendorPlacementDraft) =>
  coalescePlacementUnitPrice(item, pl);

const placedQtyForLine = (item: ProcurementDemandItem) =>
  sumPlacementDraftQty(getDraft(item).placements);

const PRICE_COMPARE_EPS = 0.005;

type QtyVsNeed = 'match' | 'over' | 'under';

const qtyVsNeed = (item: ProcurementDemandItem): QtyVsNeed => {
  const need = needQty(item);
  const placed = placedQtyForLine(item);
  if (need <= 0) return 'match';
  if (placed > need) return 'over';
  if (placed < need) return 'under';
  return 'match';
};

const qtySummaryCellClass = (item: ProcurementDemandItem) => {
  const vs = qtyVsNeed(item);
  if (vs === 'over') return 'demand-buy-lines__cell--qty-over';
  if (vs === 'under') return 'demand-buy-lines__cell--qty-under';
  return '';
};

const qtyInputTintClass = (item: ProcurementDemandItem) => {
  const vs = qtyVsNeed(item);
  if (vs === 'over') return 'excel-cell-input--qty-over';
  if (vs === 'under') return 'excel-cell-input--qty-under';
  return '';
};

type PriceVsOrder = 'match' | 'high' | 'low';

const priceVsOrder = (item: ProcurementDemandItem, pl: VendorPlacementDraft): PriceVsOrder | null => {
  const order = orderLineUnitPrice(item);
  if (order == null) return null;
  const code = pl.vendorCode.trim();
  const qty = Math.max(0, Math.floor(Number(pl.quantity) || 0));
  if (!code || qty <= 0) return null;
  const unit = placementUnitPrice(item, pl);
  if (unit == null || !Number.isFinite(Number(unit))) return null;
  const diff = Number(unit) - Number(order);
  if (Math.abs(diff) <= PRICE_COMPARE_EPS) return 'match';
  return diff > 0 ? 'high' : 'low';
};

const priceInputTintClass = (item: ProcurementDemandItem, pl: VendorPlacementDraft) => {
  const vs = priceVsOrder(item, pl);
  if (vs === 'high') return 'excel-cell-input--price-high';
  if (vs === 'low') return 'excel-cell-input--price-low';
  return '';
};

/** Order £ reference cell: red if any vendor price above order, green if below (no red). */
const orderPriceCellClass = (item: ProcurementDemandItem) => {
  let anyHigh = false;
  let anyLow = false;
  for (const pl of getDraft(item).placements) {
    const vs = priceVsOrder(item, pl);
    if (vs === 'high') anyHigh = true;
    if (vs === 'low') anyLow = true;
  }
  if (anyHigh) return 'demand-buy-lines__cell--qty-under';
  if (anyLow) return 'demand-buy-lines__cell--qty-over';
  return '';
};

const patchDraft = (item: ProcurementDemandItem, draft: DemandBuyLineDraft) => {
  emit('update-draft', item, draft);
};

const onVendorCodeChange = (item: ProcurementDemandItem, idx: number, code: string | null) => {
  const draft = getDraft(item);
  const placements = draft.placements.map((p, i) =>
    i === idx ? { ...p, vendorCode: code?.trim() ?? '' } : p,
  );
  patchDraft(item, { placements });
};

const onQtyChange = (item: ProcurementDemandItem, idx: number, value: string | number | null) => {
  const draft = getDraft(item);
  const qty =
    value === '' || value === null ? null : Math.max(0, Math.floor(Number(value) || 0));
  const fallbackVendor = defaultVendorCodeForItem(item);
  const placements = draft.placements.map((p, i) => {
    if (i !== idx) return p;
    const next = { ...p, quantity: qty };
    if (qty != null && qty > 0 && !next.vendorCode.trim() && fallbackVendor) {
      next.vendorCode = fallbackVendor;
    }
    return next;
  });
  patchDraft(item, { placements });
};

const onPriceChange = (item: ProcurementDemandItem, idx: number, value: string | number | null) => {
  const draft = getDraft(item);
  const unitPrice =
    value === '' || value === null ? null : Math.max(0, Number(value) || 0);
  const placements = draft.placements.map((p, i) =>
    i === idx ? { ...p, unitPrice } : p,
  );
  patchDraft(item, { placements });
};

const addPlacementRow = (item: ProcurementDemandItem) => {
  const draft = getDraft(item);
  patchDraft(item, {
    placements: [...draft.placements, emptyPlacementForItem(item)],
  });
};

const removePlacementRow = (item: ProcurementDemandItem, idx: number) => {
  const draft = getDraft(item);
  patchDraft(item, {
    placements: draft.placements.filter((_, i) => i !== idx),
  });
};

const onFilterVendors = (val: string, update: (fn: () => void) => void) => {
  emit('filter-vendors', val, update);
};

const copyField = (label: string, value: string) => {
  void copyToClipboard(value).then(() => {
    showSuccessNotification(`${label} copied`);
  });
};

const copySku = (value: string) => copyField('SKU', value);
const copyBarcode = (value: string) => copyField('Barcode', value);

const toggleLineSelect = (row: ItemRow, selected: boolean) => {
  const { rowKey: _rk, ...item } = row;
  emit('toggle-line-select', item as ProcurementDemandItem, selected);
};

watch(scrollSentinelRef, (el) => {
  scrollObserver?.disconnect();
  scrollObserver = null;
  if (!el) return;
  scrollObserver = new IntersectionObserver(
    (entries) => {
      if (entries.some((e) => e.isIntersecting)) emit('load-more');
    },
    { rootMargin: '120px' },
  );
  scrollObserver.observe(el);
});

onMounted(() => {
  if (scrollSentinelRef.value) {
    scrollObserver = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) emit('load-more');
      },
      { rootMargin: '120px' },
    );
    scrollObserver.observe(scrollSentinelRef.value);
  }
});

onUnmounted(() => {
  scrollObserver?.disconnect();
});

defineExpose({ tableRows });
</script>

<style scoped lang="scss">
/* Shipment table layout; neutral white — qty/placed tint green over / red under; price reversed */
.demand-buy-doc-table.shipment-items-markup-table :deep(th),
.demand-buy-doc-table.shipment-items-markup-table :deep(td) {
  padding: 4px 4px !important;
  height: 48px;
  vertical-align: middle;
  color: var(--tf-theme-ink);
}

.demand-buy-doc-table.shipment-items-markup-table :deep(thead th) {
  background: color-mix(in srgb, var(--tf-theme-surface) 92%, var(--tf-theme-base) 8%) !important;
  color: var(--tf-theme-muted) !important;
  border-bottom: 1px solid var(--tf-theme-border);
  font-weight: 700;
  font-size: 11px;
}

.demand-buy-doc-table.shipment-items-markup-table :deep(tbody td) {
  background-color: var(--tf-theme-surface) !important;
}

.demand-buy-doc-table.shipment-items-markup-table :deep(tbody td.demand-buy-lines__cell--qty-over) {
  background-color: var(--tf-success-soft) !important;
}

.demand-buy-doc-table.shipment-items-markup-table :deep(tbody td.demand-buy-lines__cell--qty-under) {
  background-color: var(--tf-error-soft) !important;
}

.demand-buy-doc-table.shipment-items-markup-table :deep(tr:hover td) {
  filter: brightness(0.98);
}

.demand-buy-doc-table :deep(.demand-line-col) {
  width: 40px;
  min-width: 40px;
  max-width: 40px;
}

.demand-buy-doc-table :deep(.demand-line-num) {
  font-size: 12px;
}

.demand-buy-doc-table :deep(.demand-excel-readonly) {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 44px;
  padding: 0 6px;
  font-variant-numeric: tabular-nums;
}

.demand-buy-lines__thumb {
  width: 40px;
  height: 40px;
  object-fit: cover;
  border-radius: var(--tf-radius-sm, 4px);
}
.demand-buy-lines__thumb-fallback {
  width: 40px;
  height: 40px;
}
.demand-buy-lines__meta {
  display: flex;
  align-items: center;
  gap: 4px;
  max-width: 100%;
  margin-top: 2px;
}
.demand-buy-lines__select {
  width: 40px;
  padding: 4px !important;
}
.demand-buy-lines__product {
  min-width: 112px;
  max-width: 168px;
  white-space: normal;
  vertical-align: middle;
  padding: 6px 8px !important;
}
.demand-buy-lines__product-inner {
  display: flex;
  flex-direction: row;
  flex-wrap: nowrap;
  align-items: center;
  gap: 8px;
  max-width: 100%;
}
.demand-buy-lines__thumb-wrap {
  flex: 0 0 auto;
  align-self: center;
  line-height: 0;
}
.demand-buy-lines__name {
  white-space: normal;
  word-break: break-word;
  line-height: 1.25;
  font-size: 12px;
}
.demand-buy-doc-table :deep(.demand-vendor-col) {
  min-width: 320px;
}

.demand-buy-lines__placement-stack {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 4px;
  width: 100%;
}
.demand-buy-lines__placement-row {
  display: flex;
  flex-wrap: nowrap;
  align-items: center;
  gap: 6px;
  max-width: 100%;
  width: 100%;
}
.demand-buy-field--qty {
  width: 72px;
  flex: 0 0 auto;
}
.demand-buy-field--price {
  width: 100px;
  flex: 0 0 auto;
  min-width: 0;
}
.demand-buy-field--vendor {
  flex: 1 1 140px;
  min-width: 124px;
  max-width: min(168px, 44vw);
}
.demand-buy-lines__remove-vendor {
  flex: 0 0 auto;
}
.demand-buy-lines__add-vendor {
  margin-top: 2px;
}

.demand-buy-doc-table :deep(input[type='number']::-webkit-outer-spin-button),
.demand-buy-doc-table :deep(input[type='number']::-webkit-inner-spin-button) {
  -webkit-appearance: none !important;
  margin: 0 !important;
}

.demand-buy-doc-table :deep(input[type='number']) {
  -moz-appearance: textfield !important;
  appearance: textfield !important;
}

.demand-buy-doc-table :deep(.excel-cell-input.q-field) {
  font-size: 12px;
}

.demand-buy-doc-table :deep(.excel-cell-input .q-field__control) {
  border-radius: 6px !important;
  border: 1px solid var(--tf-neutral-border-strong, #cbd5e1) !important;
  background-color: var(--tf-theme-surface) !important;
  box-shadow: inset 0 1px 2px color-mix(in srgb, var(--tf-theme-ink) 5%, transparent) !important;
  min-height: 32px !important;
  height: 32px !important;
  padding: 0 2px !important;
  transition:
    border-color 0.12s ease-in-out,
    background-color 0.12s ease-in-out,
    box-shadow 0.12s ease-in-out;
}

.demand-buy-doc-table :deep(.excel-cell-input .q-field__control:before),
.demand-buy-doc-table :deep(.excel-cell-input .q-field__control:after) {
  border: none !important;
}

.demand-buy-doc-table :deep(.excel-cell-input .q-field__control-container) {
  padding-top: 0 !important;
  padding-bottom: 0 !important;
}

.demand-buy-doc-table :deep(.excel-cell-input .q-field__marginal) {
  height: auto;
}

.demand-buy-doc-table :deep(.excel-cell-input:hover .q-field__control) {
  border-color: color-mix(in srgb, var(--tf-theme-ink) 28%, var(--tf-neutral-border-strong)) !important;
  background-color: var(--tf-theme-surface) !important;
}

.demand-buy-doc-table :deep(.excel-cell-input.q-field--focused .q-field__control) {
  background-color: var(--tf-theme-surface) !important;
  border: 1.5px solid var(--tf-theme-primary) !important;
  box-shadow: 0 0 0 2px color-mix(in srgb, var(--tf-theme-primary) 18%, transparent) !important;
}

.demand-buy-doc-table :deep(.demand-buy-field--price .q-field__native) {
  text-align: right;
}

.demand-buy-doc-table :deep(.excel-cell-input .q-field__prefix) {
  font-size: 11px;
  font-weight: 600;
  color: var(--tf-theme-muted);
  padding-left: 6px;
  padding-right: 2px;
}

.demand-buy-doc-table :deep(.demand-buy-field--vendor .q-field__native) {
  min-width: 0;
  padding: 0 4px !important;
}

.demand-buy-doc-table :deep(.excel-cell-input .q-field__append) {
  padding-left: 0;
  padding-right: 4px;
}

.demand-buy-doc-table :deep(.excel-cell-input--qty-over .q-field__control),
.demand-buy-doc-table :deep(.excel-cell-input--qty-under .q-field__control),
.demand-buy-doc-table :deep(.excel-cell-input--price-high .q-field__control),
.demand-buy-doc-table :deep(.excel-cell-input--price-low .q-field__control) {
  box-shadow: none !important;
}

.demand-buy-doc-table :deep(.excel-cell-input--qty-over .q-field__control) {
  background: var(--tf-success-soft) !important;
  border-color: var(--tf-success) !important;
}

.demand-buy-doc-table :deep(.excel-cell-input--qty-over.q-field--focused .q-field__control) {
  background: var(--tf-success-soft) !important;
  border: 1.5px solid var(--tf-success) !important;
}

.demand-buy-doc-table :deep(.excel-cell-input--qty-under .q-field__control) {
  background: var(--tf-error-soft) !important;
  border-color: var(--tf-error) !important;
}

.demand-buy-doc-table :deep(.excel-cell-input--qty-under.q-field--focused .q-field__control) {
  background: var(--tf-error-soft) !important;
  border: 1.5px solid var(--tf-error) !important;
}

.demand-buy-doc-table :deep(.excel-cell-input--price-high .q-field__control) {
  background: var(--tf-error-soft) !important;
  border-color: var(--tf-error) !important;
}

.demand-buy-doc-table :deep(.excel-cell-input--price-high.q-field--focused .q-field__control) {
  background: var(--tf-error-soft) !important;
  border: 1.5px solid var(--tf-error) !important;
}

.demand-buy-doc-table :deep(.excel-cell-input--price-low .q-field__control) {
  background: var(--tf-success-soft) !important;
  border-color: var(--tf-success) !important;
}

.demand-buy-doc-table :deep(.excel-cell-input--price-low.q-field--focused .q-field__control) {
  background: var(--tf-success-soft) !important;
  border: 1.5px solid var(--tf-success) !important;
}

.demand-buy-doc-table :deep(.excel-cell-input .q-field__native),
.demand-buy-doc-table :deep(.excel-cell-input input),
.demand-buy-doc-table :deep(.excel-cell-input-native) {
  font-size: 12px;
  min-height: 30px !important;
  line-height: 30px;
  padding: 0 6px !important;
}

</style>
