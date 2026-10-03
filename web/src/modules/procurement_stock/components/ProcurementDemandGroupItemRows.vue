<template>
  <tr v-if="isLoading && demandItems.length === 0" class="demand-item-row">
    <td :colspan="tableColCount" class="text-center text-grey-7 q-py-md">
      <q-spinner-dots size="24px" color="primary" />
    </td>
  </tr>
  <tr
    v-for="item in demandItems"
    :key="itemRowKey(item)"
    class="demand-item-row"
    :style="lineStatusStyle(item)"
  >
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
        <div class="demand-code-chips">
          <button
            v-if="item.barcode"
            type="button"
            class="demand-code-chip"
            aria-label="Copy barcode"
            @click.stop="copyCode(item.barcode, 'Barcode')"
          >
            <span class="demand-code-k">BAR</span>
            <span class="demand-code-v">{{ item.barcode }}</span>
            <q-icon name="ph ph-copy" size="12px" class="demand-code-copy" />
            <q-tooltip>Copy barcode</q-tooltip>
          </button>
          <button
            v-if="item.product_code"
            type="button"
            class="demand-code-chip demand-code-chip--primary"
            aria-label="Copy product code"
            @click.stop="copyCode(item.product_code, 'Product code')"
          >
            <span class="demand-code-k">CODE</span>
            <span class="demand-code-v">{{ item.product_code }}</span>
            <q-icon name="ph ph-copy" size="12px" class="demand-code-copy" />
            <q-tooltip>Copy product code</q-tooltip>
          </button>
          <button
            v-if="item.vendor_code"
            type="button"
            class="demand-code-chip"
            aria-label="Copy vendor code"
            @click.stop="copyCode(item.vendor_code, 'Vendor code')"
          >
            <span class="demand-code-k">VEN</span>
            <span class="demand-code-v">{{ item.vendor_code }}</span>
            <q-icon name="ph ph-copy" size="12px" class="demand-code-copy" />
            <q-tooltip>Copy vendor code</q-tooltip>
          </button>
          <button
            v-if="item.market_code"
            type="button"
            class="demand-code-chip"
            aria-label="Copy market code"
            @click.stop="copyCode(item.market_code, 'Market code')"
          >
            <span class="demand-code-k">MKT</span>
            <span class="demand-code-v">{{ item.market_code }}</span>
            <q-icon name="ph ph-copy" size="12px" class="demand-code-copy" />
            <q-tooltip>Copy market</q-tooltip>
          </button>
        </div>
        <div
          v-if="item.available_units != null || item.languages || item.country_of_origin"
          class="demand-product-facts"
        >
          <span
            v-if="item.available_units != null"
            class="demand-fact"
            :class="item.available_units > 0 ? 'demand-fact--ok' : 'demand-fact--muted'"
          >
            {{ item.available_units }} avail
          </span>
          <span v-if="item.languages" class="demand-fact">{{ item.languages }}</span>
          <span v-if="item.country_of_origin" class="demand-fact">{{ item.country_of_origin }}</span>
        </div>
      </div>
    </td>
    <td class="text-center demand-qty-col text-weight-medium">
      {{ item.quantity }}
    </td>
    <td class="text-center demand-place-col">
      <q-input
        v-if="isBuyMode"
        :model-value="getDraft(item).quantity"
        type="number"
        min="0"
        dense
        outlined
        hide-bottom-space
        :disable="!canEditProcuring || isRowSaving(item)"
        class="demand-field demand-field--qty"
        @update:model-value="(v) => onPlacedQuantityInput(item, v)"
        @blur="() => flushProcuringSave(item)"
      />
      <span v-else class="text-weight-medium">
        {{ getItemPlacedQuantity(item) || '—' }}
      </span>
    </td>
    <td class="demand-vendor-col">
      <q-select
        v-if="isBuyMode"
        :model-value="getDraft(item).vendorId"
        :options="vendorOptions"
        option-value="id"
        option-label="label"
        emit-value
        map-options
        dense
        outlined
        hide-bottom-space
        clearable
        use-input
        input-debounce="200"
        placeholder="Vendor"
        :disable="!canEditProcuring || isRowSaving(item)"
        :loading="vendorsLoading"
        class="demand-field"
        @filter="onFilterVendors"
        @update:model-value="(v) => onVendorChange(item, v)"
        @blur="() => flushProcuringSave(item)"
      />
      <span v-else class="text-grey-9">
        {{ vendorLabel(getDraft(item).vendorId) }}
      </span>
    </td>
    <td v-if="isFulfillMode" class="text-center demand-delivered-col">
      <template v-if="isPackedCloseMode">
        <div class="text-weight-medium q-mb-xs">
          {{ (getDraft(item).deliveredQuantity ?? getItemDeliveredQuantity(item)) || 0 }} going
        </div>
        <ul
          v-if="getDraft(item).stockPicks.length"
          class="demand-pick-list q-ma-none q-pa-none"
        >
          <li
            v-for="pick in getDraft(item).stockPicks"
            :key="pick.globalStockId"
            class="demand-packed-pick-row column q-gutter-y-xs q-mb-sm"
          >
            <span class="text-caption text-grey-8 text-left">
              {{ pick.shipmentName || pick.globalStockId }}
              <span v-if="pick.locationName"> · {{ pick.locationName }}</span>
              · {{ pick.quantity }}
            </span>
            <q-select
              :model-value="pick.closeAction ?? null"
              :options="closeActionOptions"
              emit-value
              map-options
              dense
              outlined
              hide-bottom-space
              clearable
              placeholder="Customer close"
              class="demand-field demand-close-select"
              :disable="isRowSaving(item)"
              :loading="isRowSaving(item)"
              @update:model-value="(v) => emitCloseAction(item, pick.globalStockId, v)"
            />
          </li>
        </ul>
        <span v-else class="text-caption text-grey-6">No stock picks</span>
      </template>
      <template v-else>
        <div class="row items-center justify-center no-wrap demand-delivered-cell">
          <q-input
            :model-value="getDraft(item).deliveredQuantity"
            type="number"
            dense
            outlined
            readonly
            hide-bottom-space
            class="demand-field demand-field--qty"
          />
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
            :key="pick.globalStockId"
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
import { PROCUREMENT_DEMAND_TABLE_SCROLL_KEY } from '../shared/procurementDemandScroll';
import SmartImage from 'src/components/SmartImage.vue';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
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
  closeActionOptions: Array<{ label: string; value: DemandCloseAction }>;
  tableColCount: number;
  vendorOptions: Array<{ id: number; label: string }>;
  vendorsLoading: boolean;
  drafts: Record<string, DemandItemDraft>;
  savingRowKeys: Set<string>;
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
    globalStockId: number,
    action: DemandCloseAction | null,
  ];
}>();

const emitCloseAction = (
  item: ProcurementDemandItem,
  globalStockId: number,
  action: DemandCloseAction | null,
) => {
  emit('close-action-change', item, globalStockId, action);
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

const isRowSaving = (item: ProcurementDemandItem) =>
  props.savingRowKeys.has(itemRowKey(item));

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

const copyCode = (value: string, label: string) => {
  void copyToClipboard(value)
    .then(() => {
      showSuccessNotification(`${label} copied`);
    })
    .catch(() => {
      showErrorNotification(`Could not copy ${label.toLowerCase()}`);
    });
};

const lineStatusStyle = (item: ProcurementDemandItem) => {
  const need = item.quantity;
  const allocated = getDraft(item).deliveredQuantity ?? getItemDeliveredQuantity(item);
  if (props.isFulfillMode) {
    if (need > 0 && allocated >= need) {
      return { boxShadow: 'inset 3px 0 0 #22c55e' };
    }
    return {
      boxShadow: 'inset 3px 0 0 var(--bw-warning, #b45309)',
      backgroundColor: 'color-mix(in srgb, var(--bw-warning, #f59e0b) 12%, transparent)',
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
