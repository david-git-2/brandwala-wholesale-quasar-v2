<template>
  <div class="demand-buy-cards" :class="{ 'demand-buy-cards--nested': nested }">
    <div
      v-if="isLoading && demandItems.length === 0"
      class="row justify-center q-py-lg"
      :class="{ 'col-12': nested }"
    >
      <q-spinner-dots size="28px" color="primary" />
    </div>
    <div v-else class="demand-buy-card-grid" :class="{ 'demand-buy-card-grid--nested': nested }">
      <article
        v-for="item in demandItems"
        :key="itemRowKey(item)"
        class="demand-buy-card"
        data-test="demand-buy-card"
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
          <div class="demand-buy-card__editors demand-buy-card__editors--buy row no-wrap q-gutter-sm items-center">
            <div class="demand-buy-card__need">
              <div class="demand-buy-card__need-label">Need</div>
              <div class="demand-buy-card__need-value font-mono">{{ item.quantity }}</div>
            </div>
            <div class="demand-buy-card__qty">
              <q-input
                :model-value="getDraft(item).quantity"
                type="number"
                min="0"
                outlined
                hide-bottom-space
                label="Placed qty"
                input-class="font-mono text-weight-bold demand-buy-card__qty-input"
                :disable="!canEditProcuring || isRowSaving(item)"
                :loading="isRowSaving(item)"
                @update:model-value="(v) => emit('placed-quantity-input', item, v)"
                @blur="() => emit('flush-save', item)"
                @keydown.enter="(e: Event) => (e.target as HTMLInputElement).blur()"
              />
            </div>
            <div class="demand-buy-card__vendor">
              <q-select
                :model-value="getDraft(item).vendorId"
                :options="vendorOptions"
                option-value="id"
                option-label="label"
                emit-value
                map-options
                outlined
                hide-bottom-space
                clearable
                use-input
                input-debounce="200"
                label="Vendor"
                :disable="!canEditProcuring || isRowSaving(item)"
                :loading="vendorsLoading || isRowSaving(item)"
                @filter="onFilterVendors"
                @update:model-value="(v) => emit('vendor-change', item, v)"
                @blur="() => emit('flush-save', item)"
              />
            </div>
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
import SmartImage from 'src/components/SmartImage.vue';
import ProcurementDemandLineCardHeader from './ProcurementDemandLineCardHeader.vue';
import { useProcurementDemandGroupItemsInfiniteQuery } from '../composables/useProcurementDemandGroupItemsInfiniteQuery';
import type {
  ProcurementDemandGroup,
  ProcurementDemandItem,
} from '../repositories/procurementDemandRepository';
import type { DemandItemDraft } from './ProcurementDemandGroupItemRows.vue';

const props = defineProps<{
  group: ProcurementDemandGroup;
  tenantId: number;
  search: string | null;
  enabled: boolean;
  canEditProcuring: boolean;
  vendorOptions: Array<{ id: number; label: string }>;
  vendorsLoading: boolean;
  drafts: Record<string, DemandItemDraft>;
  savingRowKeys: Set<string>;
  nested?: boolean;
}>();

const emit = defineEmits<{
  'sync-items': [items: ProcurementDemandItem[]];
  'filter-vendors': [val: string, update: (fn: () => void) => void];
  'placed-quantity-input': [item: ProcurementDemandItem, value: string | number | null];
  'vendor-change': [item: ProcurementDemandItem, value: number | null];
  'flush-save': [item: ProcurementDemandItem];
  'open-source': [];
  'fill-place-qty': [];
  'set-vendor': [];
}>();

const demandItemsQuery = useProcurementDemandGroupItemsInfiniteQuery({
  tenantId: computed(() => props.tenantId),
  documentType: computed(() => props.group.document_type),
  documentId: computed(() => props.group.document_id),
  search: computed(() => props.search),
  enabled: computed(() => props.enabled),
});

const demandItems = computed(() => demandItemsQuery.demandItems.value);
const hasMoreItems = computed(() => demandItemsQuery.hasMoreItems.value);
const isFetchingNextPage = computed(() => demandItemsQuery.isFetchingNextPage.value);
const isLoading = computed(() => demandItemsQuery.isLoading.value);

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

const isRowSaving = (item: ProcurementDemandItem) =>
  props.savingRowKeys.has(itemRowKey(item));

const onFilterVendors = (val: string, update: (fn: () => void) => void) => {
  emit('filter-vendors', val, update);
};

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
      void demandItemsQuery.fetchNextPage();
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
