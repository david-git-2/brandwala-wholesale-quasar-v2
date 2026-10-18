<template>
  <tr v-if="isLoading && demandItems.length === 0" class="demand-item-row">
    <td :colspan="tableColCount" class="text-center text-grey-7 q-py-md">
      <q-spinner-dots size="24px" color="primary" />
    </td>
  </tr>
  <tr
    v-else-if="!isLoading && visibleDemandItems.length === 0 && isPackedCloseMode"
    class="demand-item-row"
  >
    <td :colspan="tableColCount" class="text-center text-grey-7 q-py-xl">
      <q-icon name="ph ph-clipboard-text" size="36px" class="q-mb-sm text-grey-5" />
      <div class="text-body2 text-grey-8">{{ packedCloseEmptyLabel }}</div>
    </td>
  </tr>
  <tr
    v-for="(item, lineIndex) in visibleDemandItems"
    :key="itemRowKey(item)"
    class="demand-item-row"
    :style="lineStatusStyle(item)"
  >
    <td class="text-center demand-line-col demand-line-num text-grey-7 font-mono text-weight-medium">
      {{ lineIndex + 1 }}
    </td>
    <td class="text-center demand-image-col">
      <div class="shipment-item-image-box mx-auto">
        <SmartImage
          :src="item.image_url"
          :alt="item.name"
          img-class="shipment-item-image"
          fallback-class="shipment-item-image-fallback"
          :enable-edit="false"
        />
      </div>
    </td>
    <td class="demand-product-col shipment-item-name-cell">
      <div class="demand-product-identity">
        <div class="demand-product-name">{{ item.name }}</div>
        <div v-if="item.brand" class="demand-product-brand">{{ item.brand }}</div>
      </div>
    </td>
    <td class="demand-code-col text-left" @click.stop>
      <div
        v-if="item.product_code"
        class="row items-center no-wrap q-gutter-x-xs demand-code-line"
      >
        <span class="demand-product-code col font-mono text-weight-medium text-grey-9 ellipsis">
          {{ item.product_code }}
        </span>
        <q-btn
          flat
          round
          dense
          size="xs"
          color="grey-6"
          icon="ph ph-copy"
          class="demand-code-copy-btn"
          aria-label="Copy SKU"
          @click="copyProductCode(item)"
        >
          <q-tooltip>Copy SKU</q-tooltip>
        </q-btn>
      </div>
      <div
        v-if="item.barcode"
        class="row items-center no-wrap q-gutter-x-xs demand-code-line"
      >
        <span class="demand-product-barcode col font-mono text-grey-7 ellipsis">
          {{ item.barcode }}
        </span>
        <q-btn
          flat
          round
          dense
          size="xs"
          color="grey-6"
          icon="ph ph-copy"
          class="demand-code-copy-btn"
          aria-label="Copy barcode"
          @click="copyBarcode(item)"
        >
          <q-tooltip>Copy barcode</q-tooltip>
        </q-btn>
      </div>
      <span v-if="!item.product_code && !item.barcode" class="text-grey-5">—</span>
    </td>
    <td class="text-center demand-qty-col tf-ops-col-tint--qty tf-ops-col-tint--qty-readonly">
      <div class="demand-excel-readonly font-mono text-weight-bold text-grey-9">
        {{ displayLineQuantity(item) }}
      </div>
    </td>
    <td
      v-if="isBuyMode"
      class="text-center demand-place-col tf-ops-col-tint--qty q-pa-none"
      @click.stop
    >
      <q-input
        :model-value="getDraft(item).quantity"
        type="number"
        min="0"
        dense
        borderless
        hide-bottom-space
        input-class="font-mono text-weight-bold text-slate-800 excel-cell-input-native"
        class="excel-cell-input excel-cell-input--qty"
        :disable="!canEditProcuring || isRowSaving(item)"
        :loading="isRowSaving(item)"
        @update:model-value="(v) => onPlacedQuantityInput(item, v)"
        @blur="() => flushProcuringSave(item)"
        @keydown.enter="(e: Event) => (e.target as HTMLInputElement).blur()"
      />
    </td>
    <td v-if="isBuyMode" class="demand-vendor-col tf-ops-col-tint--vendor q-pa-none" @click.stop>
      <q-select
        :model-value="getDraft(item).vendorId"
        :options="vendorOptions"
        option-value="id"
        option-label="label"
        emit-value
        map-options
        dense
        borderless
        hide-bottom-space
        clearable
        use-input
        input-debounce="200"
        placeholder="Vendor"
        input-class="font-mono excel-cell-input-native"
        class="excel-cell-input excel-cell-input--vendor"
        :disable="!canEditProcuring || isRowSaving(item)"
        :loading="vendorsLoading || isRowSaving(item)"
        @filter="onFilterVendors"
        @update:model-value="(v) => onVendorChange(item, v)"
        @blur="() => flushProcuringSave(item)"
      />
    </td>
    <td v-if="isFulfillMode" class="text-center demand-delivered-col q-pa-sm">
      <template v-if="isPackedCloseMode">
        <ul
          v-if="getDraft(item).stockPicks.length"
          class="demand-pick-list q-ma-none q-pa-none"
        >
          <li
            v-for="lot in pickLotsForItem(item)"
            :key="lot.globalStockId"
            class="demand-packed-lot q-mb-sm"
          >
            <div class="text-caption text-grey-8 text-left q-mb-xs ellipsis">
              {{ lot.shipmentName || lot.globalStockId }}
              <span v-if="lot.locationName"> · {{ lot.locationName }}</span>
            </div>
            <div
              v-for="pick in lot.rows"
              :key="pick.clientKey"
              class="row items-center no-wrap q-gutter-xs demand-packed-pick-controls q-mb-xs"
            >
              <q-input
                :model-value="pick.quantity"
                type="number"
                min="0"
                dense
                borderless
                hide-bottom-space
                input-class="font-mono text-center excel-cell-input-native"
                class="excel-cell-input excel-cell-input--qty"
                aria-label="Quantity"
                :disable="isRowSaving(item)"
                @update:model-value="(v) => emitPickQuantityInput(item, pick.clientKey, v)"
              />
              <q-select
                :model-value="pick.closeAction ?? 'take'"
                :options="closeActionSelectOptionsForPick(pick)"
                emit-value
                map-options
                dense
                borderless
                hide-bottom-space
                placeholder="Close"
                input-class="excel-cell-input-native"
                class="excel-cell-input excel-cell-input--vendor demand-close-select col"
                :disable="isRowSaving(item)"
                :loading="isRowSaving(item)"
                @update:model-value="(v) => emitCloseAction(item, pick.clientKey, v)"
              />
              <q-btn
                v-if="pick.isCloseSplit"
                flat
                round
                dense
                color="negative"
                icon="ph ph-trash"
                aria-label="Remove split"
                :disable="isRowSaving(item)"
                @click="emit('delete-close-pick', item, pick.clientKey)"
              >
                <q-tooltip>Remove split</q-tooltip>
              </q-btn>
            </div>
            <q-btn
              unelevated
              dense
              no-caps
              color="primary"
              label="Split"
              class="demand-split-btn"
              :disable="isRowSaving(item)"
              @click="emit('add-close-split', item, lot.globalStockId)"
            />
          </li>
        </ul>
        <q-btn
          v-if="isRowDirty(item)"
          unelevated
          dense
          no-caps
          color="primary"
          label="Save"
          class="demand-split-btn q-mt-xs"
          :loading="isRowSaving(item)"
          :disable="isRowSaving(item)"
          @click="emit('save-packed-picks', item)"
        />
        <span v-else-if="!getDraft(item).stockPicks.length" class="text-caption text-grey-6">No stock picks</span>
      </template>
      <template v-else>
        <div class="row items-center justify-center no-wrap demand-delivered-cell">
          <q-btn
            flat
            round
            dense
            color="primary"
            icon="ph ph-package"
            class="demand-pick-stock-btn"
            :disable="!canPickStock || !item.product_id || isRowSaving(item)"
            :loading="isRowSaving(item)"
            @click="emit('pick-stock', item)"
          >
            <q-tooltip>Pick stock</q-tooltip>
          </q-btn>
        </div>
        <ul
          v-if="getDraft(item).stockPicks.length"
          class="demand-pick-list q-mt-xs q-pl-md q-ma-none"
        >
          <li
            v-for="pick in getDraft(item).stockPicks"
            :key="pick.clientKey || `${pick.globalStockId}-${pick.quantity}`"
            class="text-caption text-grey-7"
          >
            {{ pick.shipmentName || pick.globalStockId }} · {{ pick.quantity }}
          </li>
        </ul>
      </template>
    </td>
  </tr>
  <tr
    v-if="hasMoreItems || isFetchingNextPage"
    class="demand-item-row demand-scroll-sentinel-row"
  >
    <td :colspan="tableColCount" class="text-center q-py-xs">
      <div ref="scrollSentinelRef" class="demand-scroll-sentinel" aria-hidden="true" />
      <q-spinner-dots v-if="isFetchingNextPage" size="20px" color="primary" class="q-mt-xs" />
    </td>
  </tr>
</template>

<script setup lang="ts">
import { computed, inject, onUnmounted, ref, watch } from 'vue';
import { copyToClipboard } from 'quasar';
import { showSuccessNotification } from 'src/utils/appFeedback';
import { PROCUREMENT_DEMAND_TABLE_SCROLL_KEY } from '../shared/procurementDemandScroll';
import SmartImage from 'src/components/SmartImage.vue';
import type {
  DemandCloseAction,
  DemandStockPickSelection,
} from './ProcurementDemandStockPickDialog.vue';
import { useProcurementDemandGroupItemsInfiniteQuery } from '../composables/useProcurementDemandGroupItemsInfiniteQuery';
import { useProcurementFulfillGroupItemsInfiniteQuery } from '../composables/useProcurementFulfillGroupItemsInfiniteQuery';
import {
  getItemDeliveredQuantity,
  getItemPlacedQuantity,
  getItemRemainingQuantity,
  type ProcurementDemandGroup,
  type ProcurementDemandItem,
} from '../repositories/procurementDemandRepository';
import {
  closeActionSelectOptionsForPick,
  demandPickVisibleInPackedCloseList,
} from '../utils/demandClosePickFilter';
import { sumWarehousePackagedPickQty } from '../utils/demandStockPickQty';

export type DemandItemDraft = {
  vendorId: number | null;
  quantity: number | null;
  deliveredQuantity: number | null;
  stockPicks: DemandStockPickSelection[];
};

const props = defineProps<{
  group: ProcurementDemandGroup;
  tenantId: number;
  search: string | null;
  enabled: boolean;
  isBuyMode: boolean;
  isFulfillMode: boolean;
  canEditProcuring: boolean;
  canPickStock: boolean;
  isPackedCloseMode: boolean;
  onlyLinesWithStockPicks: boolean;
  packedCloseActionFilter: DemandCloseAction | null;
  closeActionOptions: Array<{ label: string; value: DemandCloseAction }>;
  tableColCount: number;
  vendorOptions: Array<{ id: number; label: string }>;
  vendorsLoading: boolean;
  drafts: Record<string, DemandItemDraft>;
  savingRowKeys: Set<string>;
  dirtyRowKeys: Set<string>;
  vendorLabel: (vendorId: number | null) => string;
}>();

const emit = defineEmits<{
  'sync-items': [items: ProcurementDemandItem[]];
  'filter-vendors': [val: string, update: (fn: () => void) => void];
  'placed-quantity-input': [item: ProcurementDemandItem, value: string | number | null];
  'vendor-change': [item: ProcurementDemandItem, value: number | null];
  'flush-save': [item: ProcurementDemandItem];
  'pick-stock': [item: ProcurementDemandItem];
  'close-action-change': [
    item: ProcurementDemandItem,
    clientKey: string,
    action: DemandCloseAction | null,
  ];
  'pick-quantity-input': [
    item: ProcurementDemandItem,
    clientKey: string,
    value: string | number | null,
  ];
  'add-close-split': [item: ProcurementDemandItem, globalStockId: number];
  'delete-close-pick': [item: ProcurementDemandItem, clientKey: string];
  'save-packed-picks': [item: ProcurementDemandItem];
}>();

type PackedPickLot = {
  globalStockId: number;
  shipmentName: string;
  locationName: string;
  rows: DemandStockPickSelection[];
};

const pickLotsForItem = (item: ProcurementDemandItem): PackedPickLot[] => {
  const filter = props.packedCloseActionFilter;
  const picks = getDraft(item).stockPicks.filter((pick) =>
    demandPickVisibleInPackedCloseList(pick, filter),
  );
  const order: number[] = [];
  const byStockId = new Map<number, PackedPickLot>();
  for (const pick of picks) {
    if (!byStockId.has(pick.globalStockId)) {
      order.push(pick.globalStockId);
      byStockId.set(pick.globalStockId, {
        globalStockId: pick.globalStockId,
        shipmentName: pick.shipmentName,
        locationName: pick.locationName,
        rows: [],
      });
    }
    byStockId.get(pick.globalStockId)?.rows.push(pick);
  }
  return order.map((id) => byStockId.get(id)!);
};

const emitCloseAction = (
  item: ProcurementDemandItem,
  clientKey: string,
  action: DemandCloseAction | null,
) => {
  emit('close-action-change', item, clientKey, action);
};

const emitPickQuantityInput = (
  item: ProcurementDemandItem,
  clientKey: string,
  value: string | number | null,
) => {
  emit('pick-quantity-input', item, clientKey, value);
};

const documentType = computed(() => props.group.document_type);
const documentId = computed(() => props.group.document_id);
const listEnabled = computed(() => props.enabled);

const demandItemsQuery = useProcurementDemandGroupItemsInfiniteQuery({
  tenantId: computed(() => props.tenantId),
  documentType,
  documentId,
  search: computed(() => props.search),
  enabled: computed(() => listEnabled.value && props.isBuyMode),
});

const fulfillItemsQuery = useProcurementFulfillGroupItemsInfiniteQuery({
  tenantId: computed(() => props.tenantId),
  documentType,
  documentId,
  search: computed(() => props.search),
  enabled: computed(() => listEnabled.value && props.isFulfillMode),
});

const activeItemsQuery = computed(() =>
  props.isFulfillMode ? fulfillItemsQuery : demandItemsQuery,
);

const demandItems = computed(() => activeItemsQuery.value.demandItems.value);

const itemHasStockAttached = (item: ProcurementDemandItem): boolean => {
  const draft = props.drafts[itemRowKey(item)];
  if (draft?.stockPicks?.length) return true;
  if (item.stock_picks?.length) return true;
  const delivered = draft?.deliveredQuantity ?? item.delivered_quantity ?? 0;
  return delivered > 0;
};

const visibleDemandItems = computed(() => {
  let items = demandItems.value;
  if (props.onlyLinesWithStockPicks) {
    items = items.filter((item) => itemHasStockAttached(item));
  }
  return items;
});

const packedCloseEmptyLabel = computed(() => {
  const action = props.packedCloseActionFilter;
  if (!action) {
    return 'No open close lines for this document.';
  }
  const label =
    action === 'take' ? 'Take' : action === 'condition' ? 'Condition' : 'Return';
  return `No open ${label} lines.`;
});

const hasMoreItems = computed(() => activeItemsQuery.value.hasMoreItems.value);
const fetchNextPage = (...args: Parameters<typeof demandItemsQuery.fetchNextPage>) =>
  activeItemsQuery.value.fetchNextPage(...args);
const isFetchingNextPage = computed(() => activeItemsQuery.value.isFetchingNextPage.value);
const isLoading = computed(() => activeItemsQuery.value.isLoading.value);

watch(
  demandItems,
  (items) => {
    emit('sync-items', items);
  },
  { immediate: true },
);

const demandTableScrollRef = inject(PROCUREMENT_DEMAND_TABLE_SCROLL_KEY, ref(null));
const scrollSentinelRef = ref<HTMLElement | null>(null);
let scrollObserver: IntersectionObserver | null = null;

const disconnectScrollObserver = () => {
  scrollObserver?.disconnect();
  scrollObserver = null;
};

const setupScrollObserver = () => {
  disconnectScrollObserver();
  const root = demandTableScrollRef.value;
  const target = scrollSentinelRef.value;
  if (!props.enabled || !root || !target) return;

  scrollObserver = new IntersectionObserver(
    (entries) => {
      if (!entries[0]?.isIntersecting) return;
      if (!hasMoreItems.value || isFetchingNextPage.value) return;
      void fetchNextPage();
    },
    { root, rootMargin: '120px 0px', threshold: 0 },
  );
  scrollObserver.observe(target);
};

watch(
  [demandTableScrollRef, scrollSentinelRef, listEnabled, hasMoreItems],
  () => setupScrollObserver(),
  { flush: 'post' },
);

watch(isFetchingNextPage, (fetching, wasFetching) => {
  if (!wasFetching || fetching || !hasMoreItems.value) return;
  requestAnimationFrame(() => {
    if (!hasMoreItems.value || isFetchingNextPage.value) return;
    const root = demandTableScrollRef.value;
    const target = scrollSentinelRef.value;
    if (!root || !target) return;
    const rootRect = root.getBoundingClientRect();
    const targetRect = target.getBoundingClientRect();
    if (targetRect.top <= rootRect.bottom + 120) {
      void fetchNextPage();
    }
  });
});

onUnmounted(() => {
  disconnectScrollObserver();
});

const groupKey = () => `${props.group.document_type}-${props.group.document_id}`;

const itemRowKey = (item: ProcurementDemandItem) =>
  `${groupKey()}-${item.source_type}-${item.source_id}`;

const getDraft = (item: ProcurementDemandItem): DemandItemDraft => {
  const key = itemRowKey(item);
  return (
    props.drafts[key] ?? {
      vendorId: item.vendor_id ?? null,
      quantity: item.placed_quantity && item.placed_quantity > 0 ? item.placed_quantity : null,
      deliveredQuantity:
        item.delivered_quantity && item.delivered_quantity > 0 ? item.delivered_quantity : null,
      stockPicks: [],
    }
  );
};

const packagedFromStockQty = (item: ProcurementDemandItem) => {
  const draft = getDraft(item);
  if (draft.stockPicks.length) return sumWarehousePackagedPickQty(draft.stockPicks);
  const apiPicks = item.stock_picks ?? [];
  if (apiPicks.length) return sumWarehousePackagedPickQty(apiPicks);
  return getItemDeliveredQuantity(item);
};

const displayLineQuantity = (item: ProcurementDemandItem) =>
  props.isFulfillMode ? packagedFromStockQty(item) : item.quantity;

const copyDemandText = (text: string | null | undefined, label: string) => {
  const value = text?.trim();
  if (!value) return;
  void copyToClipboard(value).then(() => {
    showSuccessNotification(`Copied ${label}`);
  });
};

const copyProductCode = (item: ProcurementDemandItem) =>
  copyDemandText(item.product_code, 'SKU');

const copyBarcode = (item: ProcurementDemandItem) =>
  copyDemandText(item.barcode, 'barcode');

const isRowSaving = (item: ProcurementDemandItem) =>
  props.savingRowKeys.has(itemRowKey(item));

const isRowDirty = (item: ProcurementDemandItem) =>
  props.dirtyRowKeys.has(itemRowKey(item));

const onFilterVendors = (val: string, update: (fn: () => void) => void) => {
  emit('filter-vendors', val, update);
};

const onPlacedQuantityInput = (item: ProcurementDemandItem, value: string | number | null) => {
  emit('placed-quantity-input', item, value);
};

const onVendorChange = (item: ProcurementDemandItem, value: number | null) => {
  emit('vendor-change', item, value);
};

const flushProcuringSave = (item: ProcurementDemandItem) => {
  emit('flush-save', item);
};

const lineStatusStyle = (item: ProcurementDemandItem) => {
  const need = item.quantity;
  const allocated = getDraft(item).deliveredQuantity ?? getItemDeliveredQuantity(item);
  if (props.isFulfillMode) {
    if (need > 0 && allocated >= need) {
      return { boxShadow: 'inset 3px 0 0 #22c55e' };
    }
    return {
      boxShadow: 'inset 3px 0 0 var(--tf-warning, #b45309)',
      backgroundColor: 'color-mix(in srgb, var(--tf-warning, #f59e0b) 12%, transparent)',
    };
  }
  if (need > 0 && allocated >= need) {
    return { boxShadow: 'inset 3px 0 0 #22c55e' };
  }
  if (allocated > 0) {
    return { boxShadow: 'inset 3px 0 0 #f59e0b' };
  }
  const left = getItemRemainingQuantity(item);
  const placed = getItemPlacedQuantity(item);
  if (left <= 0 && placed > 0) {
    return { boxShadow: 'inset 3px 0 0 #22c55e' };
  }
  if (placed > 0) {
    return { boxShadow: 'inset 3px 0 0 #f59e0b' };
  }
  return { boxShadow: 'inset 3px 0 0 #94a3b8' };
};
</script>

<style scoped lang="scss">
.demand-packed-pick-controls {
  min-width: 0;
}

.demand-packed-pick-controls .demand-close-select {
  min-width: 0;
}

.demand-packed-pick-controls .demand-field--qty {
  flex: 0 0 56px;
  max-width: 56px;
}

.demand-split-btn {
  border-radius: 8px;
  flex-shrink: 0;
}
</style>
