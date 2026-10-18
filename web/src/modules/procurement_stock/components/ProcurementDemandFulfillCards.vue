<template>
  <div class="demand-buy-cards" :class="{ 'demand-buy-cards--nested': nested }">
    <div
      v-if="isLoading && visibleItems.length === 0"
      class="row justify-center q-py-lg"
      :class="{ 'col-12': nested }"
    >
      <q-spinner-dots size="28px" color="primary" />
    </div>
    <div
      v-else-if="!isLoading && visibleItems.length === 0 && isPackedCloseMode"
      class="demand-fulfill-empty text-center text-grey-7 q-py-lg"
      :class="{ 'col-12': nested }"
    >
      <q-icon name="ph ph-clipboard-text" size="36px" class="q-mb-sm text-grey-5" />
      <div class="text-body2 text-grey-8">{{ packedCloseEmptyLabel }}</div>
    </div>
    <div v-else class="demand-buy-card-grid" :class="{ 'demand-buy-card-grid--nested': nested }">
      <article
        v-for="item in visibleItems"
        :key="itemRowKey(item)"
        class="demand-buy-card"
        :class="{
          'demand-buy-card--pick-pending': isPickPending(item),
          'demand-buy-card--pick-complete': isPickComplete(item),
        }"
        data-test="demand-fulfill-card"
      >
        <div class="demand-buy-card__media">
          <SmartImage
            :src="item.image_url"
            :alt="item.name"
            img-class="demand-buy-card__image"
            fallback-class="demand-buy-card__image-fallback"
            :enable-edit="false"
          />
        </div>
        <div class="demand-buy-card__body">
          <ProcurementDemandLineCardHeader
            :item="item"
            :group="group"
            :group-source-chip="groupSourceChip"
            :group-doc-chip="groupDocChip"
            @copy-sku="copyProductCode(item)"
            @copy-barcode="copyBarcode(item)"
          />
          <div
            class="demand-buy-card__editors"
            :class="{
              'demand-buy-card__editors--packed': isPackedCloseMode,
              'demand-buy-card__editors--fulfill-row': !isPackedCloseMode,
            }"
          >
            <template v-if="isPackedCloseMode">
              <div class="demand-fulfill-packed col min-width-0">
                <ul
                  v-if="pickLotsForItem(item).length"
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
                        outlined
                        hide-bottom-space
                        input-class="font-mono text-center"
                        class="demand-fulfill-packed-qty"
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
                        outlined
                        hide-bottom-space
                        class="demand-fulfill-packed-action col"
                        :disable="isRowSaving(item)"
                        :loading="isRowSaving(item)"
                        @update:model-value="(v) => emitCloseAction(item, pick.clientKey, v)"
                      />
                      <TfBtn
                        v-if="pick.isCloseSplit"
                        variant="icon"
                        color="negative"
                        icon="ph ph-trash"
                        aria-label="Remove split"
                        :disable="isRowSaving(item)"
                        @click="emit('delete-close-pick', item, pick.clientKey)"
                      />
                    </div>
                    <div class="row items-center q-gutter-xs">
                      <TfBtn
                        variant="secondary"
                        size="sm"
                        label="Split"
                        :disable="isRowSaving(item)"
                        @click="emit('add-close-split', item, lot.globalStockId)"
                      />
                    </div>
                  </li>
                </ul>
                <TfBtn
                  v-if="isRowDirty(item)"
                  variant="primary"
                  size="sm"
                  label="Save"
                  class="q-mt-xs"
                  :loading="isRowSaving(item)"
                  :disable="isRowSaving(item)"
                  @click="emit('save-packed-picks', item)"
                />
                <span v-else-if="!pickLotsForItem(item).length" class="text-caption text-grey-6">No stock picks</span>
              </div>
            </template>
            <template v-else>
              <div class="demand-buy-card__editors-fulfill">
                <div class="demand-buy-card__metric-row">
                  <div class="demand-buy-card__need">
                    <div class="demand-buy-card__need-label">Need</div>
                    <div class="demand-buy-card__need-value font-mono">{{ item.quantity }}</div>
                  </div>
                  <div class="demand-buy-card__need">
                    <div class="demand-buy-card__need-label">{{ allocatedLabel }}</div>
                    <div
                      class="demand-buy-card__need-value font-mono"
                      :class="{ 'demand-buy-card__need-value--settled': isPickComplete(item) }"
                    >
                      {{ packagedQty(item) }}
                    </div>
                  </div>
                  <div class="demand-fulfill-pick">
                    <TfBtn
                      class="demand-pick-cta"
                      :class="isPickComplete(item) ? 'demand-pick-cta--complete' : 'demand-pick-cta--pending'"
                      :variant="isPickComplete(item) ? 'success' : 'primary'"
                      size="sm"
                      :label="pickStockButtonLabel(item)"
                      :disable="!canPickStock || !item.product_id || isRowSaving(item)"
                      :loading="isRowSaving(item)"
                      @click="emit('pick-stock', item)"
                    />
                  </div>
                </div>
                <div
                  v-if="getDraft(item).stockPicks.length"
                  class="demand-pick-confirm-list"
                >
                  <q-badge
                    v-for="pick in getDraft(item).stockPicks"
                    :key="pick.clientKey || `${pick.globalStockId}-${pick.quantity}`"
                    outline
                    color="grey-7"
                    class="demand-pick-confirm-badge font-mono"
                  >
                    {{ pick.shipmentName || pick.globalStockId }} · {{ pick.quantity }}
                  </q-badge>
                </div>
              </div>
            </template>
          </div>
        </div>
      </article>
    </div>
    <div ref="scrollSentinelRef" class="demand-scroll-sentinel" aria-hidden="true" />
    <div v-if="isFetchingNextPage" class="row justify-center q-py-sm">
      <q-spinner-dots size="20px" color="primary" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, inject, onUnmounted, ref, watch } from 'vue';
import { copyToClipboard } from 'quasar';
import { showSuccessNotification } from 'src/utils/appFeedback';
import { PROCUREMENT_DEMAND_TABLE_SCROLL_KEY } from '../shared/procurementDemandScroll';
import TfBtn from 'src/components/ui/TfBtn.vue';
import SmartImage from 'src/components/SmartImage.vue';
import ProcurementDemandLineCardHeader from './ProcurementDemandLineCardHeader.vue';
import { useProcurementFulfillGroupItemsInfiniteQuery } from '../composables/useProcurementFulfillGroupItemsInfiniteQuery';
import {
  getItemDeliveredQuantity,
  type ProcurementDemandGroup,
  type ProcurementDemandItem,
} from '../repositories/procurementDemandRepository';
import {
  closeActionSelectOptionsForPick,
  demandPickVisibleInPackedCloseList,
} from '../utils/demandClosePickFilter';
import { sumWarehousePackagedPickQty } from '../utils/demandStockPickQty';
import type {
  DemandCloseAction,
  DemandStockPickSelection,
} from './ProcurementDemandStockPickDialog.vue';
import type { DemandItemDraft } from './ProcurementDemandGroupItemRows.vue';

type PackedPickLot = {
  globalStockId: number;
  shipmentName: string;
  locationName: string;
  rows: DemandStockPickSelection[];
};

const props = defineProps<{
  group: ProcurementDemandGroup;
  tenantId: number;
  search: string | null;
  enabled: boolean;
  canPickStock: boolean;
  isPackedCloseMode: boolean;
  onlyLinesWithStockPicks: boolean;
  packedCloseActionFilter: DemandCloseAction | null;
  closeActionOptions: Array<{ label: string; value: DemandCloseAction }>;
  allocatedLabel: string;
  drafts: Record<string, DemandItemDraft>;
  savingRowKeys: Set<string>;
  dirtyRowKeys: Set<string>;
  nested?: boolean;
}>();

const emit = defineEmits<{
  'sync-items': [items: ProcurementDemandItem[]];
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
  'open-source': [];
  'fill-oldest-stock': [];
}>();

const fulfillItemsQuery = useProcurementFulfillGroupItemsInfiniteQuery({
  tenantId: computed(() => props.tenantId),
  documentType: computed(() => props.group.document_type),
  documentId: computed(() => props.group.document_id),
  search: computed(() => props.search),
  enabled: computed(() => props.enabled),
});

const demandItems = computed(() => fulfillItemsQuery.demandItems.value);
const hasMoreItems = computed(() => fulfillItemsQuery.hasMoreItems.value);
const isFetchingNextPage = computed(() => fulfillItemsQuery.isFetchingNextPage.value);
const isLoading = computed(() => fulfillItemsQuery.isLoading.value);

watch(
  demandItems,
  (items) => {
    emit('sync-items', items);
  },
  { immediate: true },
);

const groupSourceChip = computed(() =>
  props.group.document_type === 'shop_order' ? 'Shop order' : 'Costing file',
);

const groupDocChip = computed(() => {
  const orderNo = props.group.shop_order_no?.trim();
  const name = props.group.document_name?.trim();
  return orderNo || name || `#${props.group.document_id}`;
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

const itemHasStockAttached = (item: ProcurementDemandItem): boolean => {
  const draft = props.drafts[itemRowKey(item)];
  if (draft?.stockPicks?.length) return true;
  if (item.stock_picks?.length) return true;
  const delivered = draft?.deliveredQuantity ?? item.delivered_quantity ?? 0;
  return delivered > 0;
};

const visibleItems = computed(() => {
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

const packagedQty = (item: ProcurementDemandItem) => {
  const draft = getDraft(item);
  if (draft.stockPicks.length) return sumWarehousePackagedPickQty(draft.stockPicks);
  const apiPicks = item.stock_picks ?? [];
  if (apiPicks.length) return sumWarehousePackagedPickQty(apiPicks);
  return getItemDeliveredQuantity(item);
};

const pickNeedQty = (item: ProcurementDemandItem) =>
  Math.max(0, Math.trunc(Number(item.quantity) || 0));

const pickAllocatedQty = (item: ProcurementDemandItem) =>
  Math.max(0, Math.trunc(packagedQty(item)));

const isPickComplete = (item: ProcurementDemandItem): boolean => {
  const need = pickNeedQty(item);
  const picked = pickAllocatedQty(item);
  return need > 0 && picked >= need;
};

const isPickPending = (item: ProcurementDemandItem): boolean =>
  !props.isPackedCloseMode && !isPickComplete(item);

const pickStockButtonLabel = (item: ProcurementDemandItem): string => {
  const need = pickNeedQty(item);
  const picked = pickAllocatedQty(item);
  if (picked <= 0) return 'Pick stock';
  if (isPickComplete(item)) return `Picked ${picked}`;
  if (need > 0) return `Pick stock · ${picked}/${need}`;
  return `Edit picks · ${picked}`;
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

const isRowSaving = (item: ProcurementDemandItem) =>
  props.savingRowKeys.has(itemRowKey(item));

const isRowDirty = (item: ProcurementDemandItem) =>
  props.dirtyRowKeys.has(itemRowKey(item));

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
      void fulfillItemsQuery.fetchNextPage();
    },
    { root, rootMargin: '120px 0px', threshold: 0 },
  );
  scrollObserver.observe(target);
};

watch(
  [() => props.enabled, demandTableScrollRef, scrollSentinelRef, hasMoreItems],
  () => setupScrollObserver(),
  { flush: 'post' },
);

onUnmounted(() => disconnectScrollObserver());
</script>

<style scoped lang="scss">
@import './ProcurementDemandLineCards.scss';
</style>
