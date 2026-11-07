<template>
  <div class="demand-buy-lines column no-wrap">
    <q-table
      flat
      bordered
      dense
      :rows="tableRows"
      :columns="columns"
      row-key="rowKey"
      hide-pagination
      :pagination="{ rowsPerPage: 0 }"
      class="demand-buy-lines__table"
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
          <q-td key="product" :props="bp" class="demand-buy-lines__product">
            <div class="row no-wrap items-center q-gutter-x-sm">
              <SmartImage
                :src="bp.row.image_url"
                :alt="bp.row.name"
                img-class="demand-buy-lines__thumb"
                fallback-class="demand-buy-lines__thumb-fallback"
                :enable-edit="false"
              />
              <div class="min-width-0">
                <div class="text-weight-medium ellipsis">{{ bp.row.name }}</div>
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
          <q-td key="need" :props="bp" class="text-right tf-num font-mono">
            {{ needQty(bp.row) }}
          </q-td>
          <q-td key="placed" :props="bp" class="text-right tf-num font-mono">
            {{ sumPlacementDraftQty(getDraft(bp.row).placements) }}
          </q-td>
          <q-td key="remaining" :props="bp" class="text-right tf-num font-mono">
            {{ Math.max(needQty(bp.row) - sumPlacementDraftQty(getDraft(bp.row).placements), 0) }}
          </q-td>
          <q-td key="vendors" :props="bp" class="demand-buy-lines__vendors">
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
                  outlined
                  dense
                  hide-bottom-space
                  placeholder="Qty"
                  class="demand-buy-lines__qty"
                  input-class="tf-num font-mono text-center"
                  @update:model-value="(v) => onQtyChange(bp.row, idx, v)"
                />
                <q-select
                  :model-value="pl.vendorCode || null"
                  :options="vendorCodeOptions"
                  option-value="code"
                  option-label="label"
                  emit-value
                  map-options
                  outlined
                  dense
                  options-dense
                  hide-bottom-space
                  clearable
                  use-input
                  input-debounce="200"
                  class="demand-buy-lines__vendor-select"
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
import type { ProcurementDemandItem } from '../repositories/procurementDemandRepository';
import {
  type DemandBuyLineDraft,
  itemDraftKey,
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
  { name: 'product', label: 'Product', field: 'name', align: 'left' as const },
  { name: 'need', label: 'Need', field: 'quantity', align: 'right' as const },
  { name: 'placed', label: 'Placed', align: 'right' as const },
  { name: 'remaining', label: 'Left', align: 'right' as const },
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
  props.lineDrafts[itemDraftKey(item)] ?? { placements: [{ vendorCode: '', quantity: null }] };

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
  const placements = draft.placements.map((p, i) =>
    i === idx ? { ...p, quantity: qty } : p,
  );
  patchDraft(item, { placements });
};

const addPlacementRow = (item: ProcurementDemandItem) => {
  const draft = getDraft(item);
  patchDraft(item, {
    placements: [...draft.placements, { vendorCode: '', quantity: null }],
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
  padding-left: 4px;
  padding-right: 4px;
}
.demand-buy-lines__product {
  min-width: 160px;
  max-width: 240px;
}
.demand-buy-lines__placement-stack {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 4px;
}
.demand-buy-lines__placement-row {
  display: flex;
  flex-wrap: nowrap;
  align-items: center;
  gap: 6px;
  max-width: 100%;
}
.demand-buy-lines__vendor-select {
  width: 148px;
  max-width: min(148px, 42vw);
  flex: 0 0 auto;
  :deep(.q-field__control) {
    min-height: 32px;
  }
  :deep(.q-field__native) {
    font-size: 12px;
  }
}
.demand-buy-lines__qty {
  width: 64px;
  flex: 0 0 auto;
  :deep(.q-field__control) {
    min-height: 32px;
  }
  :deep(.q-field__native) {
    font-size: 12px;
  }
}
.demand-buy-lines__remove-vendor {
  flex: 0 0 auto;
}
.demand-buy-lines__add-vendor {
  margin-top: 2px;
}
.demand-buy-lines__vendors {
  width: 1%;
  white-space: nowrap;
}
</style>
