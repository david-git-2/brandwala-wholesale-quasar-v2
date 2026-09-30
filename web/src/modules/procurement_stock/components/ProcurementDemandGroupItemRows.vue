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
      <div class="text-weight-bold text-grey-9">{{ item.name }}</div>
      <div class="text-caption text-grey-7">
        {{ item.product_code || item.barcode || '—' }}
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
          :disable="!canEditProcuring || !item.product_id || isRowSaving(item)"
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
    </td>
  </tr>
  <tr v-if="hasMoreItems" class="demand-item-row">
    <td :colspan="tableColCount" class="text-center q-py-sm">
      <q-btn
        flat
        dense
        no-caps
        color="primary"
        label="Load more"
        :loading="isFetchingNextPage"
        @click="fetchNextPage()"
      />
    </td>
  </tr>
</template>

<script setup lang="ts">
import { computed, watch } from 'vue';
import SmartImage from 'src/components/SmartImage.vue';
import type { DemandStockPickSelection } from './ProcurementDemandStockPickDialog.vue';
import { useProcurementDemandGroupItemsInfiniteQuery } from '../composables/useProcurementDemandGroupItemsInfiniteQuery';
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
}>();

const documentType = computed(() => props.group.document_type);
const documentId = computed(() => props.group.document_id);
const listEnabled = computed(() => props.enabled);

const {
  demandItems,
  hasMoreItems,
  fetchNextPage,
  isFetchingNextPage,
  isLoading,
} = useProcurementDemandGroupItemsInfiniteQuery({
  tenantId: computed(() => props.tenantId),
  documentType,
  documentId,
  search: computed(() => props.search),
  enabled: listEnabled,
});

watch(
  demandItems,
  (items) => {
    emit('sync-items', items);
  },
  { immediate: true },
);

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

const lineStatusStyle = (item: ProcurementDemandItem) => {
  const need = item.quantity;
  const allocated = getItemDeliveredQuantity(item);
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
