<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden">
      <q-card flat class="floating-surface shadow-1 q-pa-xs flex-shrink-0">
        <div class="row items-center justify-end q-col-gutter-xs">
          <div class="col-12 col-md-grow row items-center justify-end q-gutter-x-xs">
            <q-input
              v-model="searchText"
              outlined
              rounded
              dense
              clearable
              style="min-width: 220px"
              class="col-grow col-sm-auto dense-search-input"
              placeholder="Search product or customer..."
            >
              <template #prepend>
                <q-icon name="ph ph-magnifying-glass" size="16px" />
              </template>
            </q-input>
            <q-btn flat round dense icon="ph ph-arrow-clockwise" :loading="isFetching" @click="refetch">
              <q-tooltip>Refresh</q-tooltip>
            </q-btn>
          </div>
        </div>
      </q-card>

      <q-card flat bordered class="col column no-wrap overflow-hidden floating-surface shadow-1">
        <q-inner-loading :showing="isLoading">
          <q-spinner-dots size="40px" color="primary" />
        </q-inner-loading>

        <div class="col treasury-table-wrap q-px-sm q-pb-sm">
          <div
            v-if="!isLoading && groups.length === 0"
            class="column items-center justify-center full-height text-grey-7 q-pa-lg"
          >
            <q-icon name="ph ph-clipboard-text" size="40px" class="q-mb-sm" />
            <div class="text-body2">No demand lines.</div>
          </div>

          <q-markup-table
            v-else
            flat
            class="demand-table shipment-details-table full-height"
          >
            <thead>
              <tr>
                <th class="text-center demand-image-col">Image</th>
                <th class="text-left demand-product-col">Product</th>
                <th class="text-center demand-qty-col">Quantity</th>
                <th class="text-center demand-place-col">Place order</th>
                <th class="text-left demand-vendor-col">Vendor</th>
                <th class="text-center demand-delivered-col">Delivered qty</th>
              </tr>
            </thead>
            <tbody>
              <template v-for="group in groups" :key="groupKey(group)">
                <tr class="demand-group-row cursor-pointer" @click="toggleGroup(groupKey(group))">
                  <td colspan="6">
                    <div class="row items-center q-gutter-x-xs no-wrap">
                      <q-icon
                        :name="isGroupExpanded(groupKey(group)) ? 'ph ph-caret-down' : 'ph ph-caret-right'"
                        size="16px"
                        color="grey-7"
                      />
                      <q-icon :name="groupIcon(group.document_type)" size="16px" color="primary" />
                      <span class="text-weight-bold text-grey-9">{{ groupTitle(group) }}</span>
                      <span class="text-caption text-grey-7">
                        · {{ group.customer_group_name || '—' }}
                      </span>
                      <q-space />
                      <q-badge
                        :color="groupStatusColor(group.document_status)"
                        text-color="white"
                        class="text-weight-medium"
                        :label="groupStatusLabel(group)"
                      />
                      <q-badge color="grey-3" text-color="grey-9" :label="`${group.items.length} items`" />
                    </div>
                  </td>
                </tr>

                <template v-if="isGroupExpanded(groupKey(group))">
                  <tr
                    v-for="item in group.items"
                    :key="itemRowKey(group, item)"
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
                        :model-value="getDraft(group, item).quantity"
                        type="number"
                        min="0"
                        dense
                        outlined
                        hide-bottom-space
                        :disable="isRowSaving(group, item)"
                        class="demand-field demand-field--qty"
                        @update:model-value="(v) => onPlacedQuantityInput(group, item, v)"
                        @blur="() => flushProcuringSave(group, item)"
                      />
                    </td>
                    <td class="demand-vendor-col">
                      <q-select
                        :model-value="getDraft(group, item).vendorId"
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
                        :disable="isRowSaving(group, item)"
                        :loading="vendorsLoading"
                        class="demand-field"
                        @filter="filterVendors"
                        @update:model-value="(v) => onVendorChange(group, item, v)"
                        @blur="() => flushProcuringSave(group, item)"
                      />
                    </td>
                    <td class="text-center demand-delivered-col">
                      <div class="row items-center justify-center no-wrap demand-delivered-cell">
                        <q-input
                          :model-value="getDraft(group, item).deliveredQuantity"
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
                          :disable="!item.product_id || isRowSaving(group, item)"
                          :loading="isRowSaving(group, item)"
                          @click="openStockPickDialog(group, item)"
                        >
                          <q-tooltip>Pick stock</q-tooltip>
                        </q-btn>
                      </div>
                      <ul
                        v-if="getDraft(group, item).stockPicks.length"
                        class="demand-pick-list q-mt-xs q-pl-md q-ma-none"
                      >
                        <li
                          v-for="pick in getDraft(group, item).stockPicks"
                          :key="pick.globalStockId"
                          class="text-caption text-grey-7"
                        >
                          {{ pick.shipmentName || pick.globalStockId }} · {{ pick.quantity }}
                        </li>
                      </ul>
                    </td>
                  </tr>
                </template>
              </template>
            </tbody>
          </q-markup-table>
        </div>
      </q-card>
    </div>

    <ProcurementDemandStockPickDialog
      v-model="stockPickDialogOpen"
      :tenant-id="tenantId"
      :product-id="stockPickTarget?.productId ?? null"
      :product-name="stockPickTarget?.productName ?? ''"
      :need-quantity="stockPickTarget?.needQuantity ?? 0"
      :initial-picks="stockPickTarget?.initialPicks"
      @apply="onStockPickApply"
    />
  </q-page>
</template>

<script setup lang="ts">
import { useQuery } from '@tanstack/vue-query';
import { computed, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import SmartImage from 'src/components/SmartImage.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { vendorRepository } from 'src/modules/vendor/repositories/vendorRepository';
import type { Vendor } from 'src/modules/vendor/types';
import { getStaffCatalogStatusLabel } from 'src/modules/shop_order/utils/catalogOrderStatus';
import { getCustomerOrderStatusColor } from 'src/modules/shop_order/utils/customerOrderStatusUi';
import {
  parseSupabaseError,
  showErrorNotification,
  showSuccessNotification,
} from 'src/utils/appFeedback';
import ProcurementDemandStockPickDialog, {
  type DemandStockPickSelection,
} from '../components/ProcurementDemandStockPickDialog.vue';
import { useProcurementDemandGroupsQuery } from '../composables/useProcurementDemandGroupsQuery';
import { useUpsertPreorderDemandMutation } from '../composables/useProcurementPlacementMutations';
import {
  getItemPlacedQuantity,
  getItemRemainingQuantity,
  type PreorderDemandStockPick,
  type ProcurementDemandDocumentType,
  type ProcurementDemandGroup,
  type ProcurementDemandItem,
  type ProcurementDemandStatus,
} from '../repositories/procurementDemandRepository';

type ItemDraft = {
  vendorId: number | null;
  quantity: number | null;
  deliveredQuantity: number | null;
  stockPicks: DemandStockPickSelection[];
};

const normalizeDraftQuantity = (value?: number | null): number | null => {
  if (value == null || value <= 0) return null;
  return value;
};

const resolvePlacedQuantityForSave = (
  draft: ItemDraft,
  item: ProcurementDemandItem,
): number | null => {
  if (draft.quantity !== null) return draft.quantity;
  if ((item.placed_quantity ?? 0) > 0) return 0;
  return null;
};

type StockPickTarget = {
  group: ProcurementDemandGroup;
  item: ProcurementDemandItem;
  productId: number | null;
  productName: string;
  needQuantity: number;
  initialPicks: DemandStockPickSelection[];
};

const authStore = useAuthStore();
const { t, te } = useI18n();

const searchText = ref('');
const debouncedSearch = ref('');
const collapsedGroupKeys = ref<Set<string>>(new Set());
const drafts = reactive<Record<string, ItemDraft>>({});
const stockPickDialogOpen = ref(false);
const stockPickTarget = ref<StockPickTarget | null>(null);
const savingRowKeys = ref<Set<string>>(new Set());
const vendorFilter = ref('');

const tenantId = computed(
  () => authStore.selectedTenant?.parent_id ?? authStore.tenantId ?? null,
);

let searchTimer: ReturnType<typeof setTimeout> | undefined;
watch(searchText, (value) => {
  if (searchTimer) clearTimeout(searchTimer);
  searchTimer = setTimeout(() => {
    debouncedSearch.value = value;
  }, 300);
});

const procurementStatus = ref<ProcurementDemandStatus>('procuring');

const {
  data: demandData,
  isLoading,
  isFetching,
  refetch,
} = useProcurementDemandGroupsQuery({
  tenantId,
  procurementStatus,
  search: debouncedSearch,
});

const groups = computed(() => demandData.value?.groups ?? []);

const upsertMutation = useUpsertPreorderDemandMutation({
  tenantId,
  procurementStatus,
  search: debouncedSearch,
});

const { data: vendors = [], isLoading: vendorsLoading } = useQuery({
  queryKey: computed(() => ['vendors', 'forDemand', tenantId.value]),
  queryFn: () => vendorRepository.listVendors(tenantId.value),
  enabled: computed(() => tenantId.value !== null),
  staleTime: 60_000,
});

const vendorOptions = computed(() => {
  const needle = vendorFilter.value.trim().toLowerCase();
  return (vendors.value as Vendor[])
    .filter((vendor) => {
      if (!needle) return true;
      return (
        vendor.name.toLowerCase().includes(needle) ||
        vendor.code.toLowerCase().includes(needle)
      );
    })
    .map((vendor) => ({
      id: vendor.id,
      label: `${vendor.name} (${vendor.code})`,
    }));
});

const filterVendors = (val: string, update: (fn: () => void) => void) => {
  update(() => {
    vendorFilter.value = val;
  });
};

const mapStockPicksFromApi = (picks?: PreorderDemandStockPick[]): DemandStockPickSelection[] =>
  (picks ?? []).map((pick) => ({
    globalStockId: pick.global_stock_id,
    shipmentName: pick.shipment_name ?? '',
    locationName: pick.location_name ?? '',
    quantity: pick.quantity,
  }));

const mapStockPicksToApi = (picks: DemandStockPickSelection[]): PreorderDemandStockPick[] =>
  picks.map((pick) => ({
    global_stock_id: pick.globalStockId,
    quantity: pick.quantity,
    shipment_name: pick.shipmentName || null,
    location_name: pick.locationName || null,
  }));

const syncDraftsFromGroups = (nextGroups: ProcurementDemandGroup[]) => {
  for (const group of nextGroups) {
    for (const item of group.items) {
      const key = itemRowKey(group, item);
      if (savingRowKeys.value.has(key)) continue;
      drafts[key] = {
        vendorId: item.vendor_id ?? null,
        quantity: normalizeDraftQuantity(item.placed_quantity),
        deliveredQuantity: normalizeDraftQuantity(item.delivered_quantity),
        stockPicks: mapStockPicksFromApi(item.stock_picks),
      };
    }
  }
};

watch(groups, (nextGroups) => syncDraftsFromGroups(nextGroups), { immediate: true });

const groupKey = (group: ProcurementDemandGroup) =>
  `${group.document_type}-${group.document_id}`;

const itemRowKey = (group: ProcurementDemandGroup, item: ProcurementDemandItem) =>
  `${groupKey(group)}-${item.source_type}-${item.source_id}`;

const isRowSaving = (group: ProcurementDemandGroup, item: ProcurementDemandItem) =>
  savingRowKeys.value.has(itemRowKey(group, item));

const isGroupExpanded = (key: string) => !collapsedGroupKeys.value.has(key);

const toggleGroup = (key: string) => {
  const next = new Set(collapsedGroupKeys.value);
  if (next.has(key)) {
    next.delete(key);
  } else {
    next.add(key);
  }
  collapsedGroupKeys.value = next;
};

const groupIcon = (documentType: ProcurementDemandDocumentType) =>
  documentType === 'shop_order' ? 'ph ph-receipt' : 'ph ph-file-text';

const groupTitle = (group: ProcurementDemandGroup) => {
  if (group.document_type === 'shop_order') {
    return `Order #${group.document_id}`;
  }
  return `Costing file #${group.document_id}`;
};

const getDraft = (group: ProcurementDemandGroup, item: ProcurementDemandItem): ItemDraft => {
  const key = itemRowKey(group, item);
  if (!drafts[key]) {
    drafts[key] = {
      vendorId: item.vendor_id ?? null,
      quantity: normalizeDraftQuantity(item.placed_quantity),
      deliveredQuantity: normalizeDraftQuantity(item.delivered_quantity),
      stockPicks: mapStockPicksFromApi(item.stock_picks),
    };
  }
  return drafts[key];
};

const isProcuringDraftDirty = (
  group: ProcurementDemandGroup,
  item: ProcurementDemandItem,
) => {
  const draft = getDraft(group, item);
  return (
    draft.vendorId !== (item.vendor_id ?? null) ||
    draft.quantity !== normalizeDraftQuantity(item.placed_quantity)
  );
};

const flushProcuringSave = (group: ProcurementDemandGroup, item: ProcurementDemandItem) => {
  if (!isProcuringDraftDirty(group, item)) return;
  void saveProcuringLine(group, item);
};

const saveProcuringLine = async (group: ProcurementDemandGroup, item: ProcurementDemandItem) => {
  const key = itemRowKey(group, item);
  const draft = getDraft(group, item);
  savingRowKeys.value = new Set(savingRowKeys.value).add(key);
  try {
    await upsertMutation.mutateAsync({
      sourceType: item.source_type,
      sourceId: item.source_id,
      vendorId: draft.vendorId,
      placedQuantity: resolvePlacedQuantityForSave(draft, item),
    });
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to save demand line'));
  } finally {
    const next = new Set(savingRowKeys.value);
    next.delete(key);
    savingRowKeys.value = next;
  }
};

const onVendorChange = (
  group: ProcurementDemandGroup,
  item: ProcurementDemandItem,
  value: number | null,
) => {
  getDraft(group, item).vendorId = value;
};

const onPlacedQuantityInput = (
  group: ProcurementDemandGroup,
  item: ProcurementDemandItem,
  value: string | number | null,
) => {
  if (value === '' || value === null) {
    getDraft(group, item).quantity = null;
    return;
  }
  const parsed = Number(value);
  getDraft(group, item).quantity =
    Number.isFinite(parsed) && parsed > 0 ? Math.trunc(parsed) : null;
};

const openStockPickDialog = (group: ProcurementDemandGroup, item: ProcurementDemandItem) => {
  const draft = getDraft(group, item);
  stockPickTarget.value = {
    group,
    item,
    productId: item.product_id,
    productName: item.name,
    needQuantity: getItemPlacedQuantity(item) || getItemRemainingQuantity(item) || item.quantity,
    initialPicks: [...draft.stockPicks],
  };
  stockPickDialogOpen.value = true;
};

const onStockPickApply = async (payload: {
  picks: DemandStockPickSelection[];
  totalQuantity: number;
}) => {
  const target = stockPickTarget.value;
  if (!target) return;

  const key = itemRowKey(target.group, target.item);
  const draft = getDraft(target.group, target.item);
  draft.stockPicks = payload.picks;
  draft.deliveredQuantity = normalizeDraftQuantity(payload.totalQuantity);

  savingRowKeys.value = new Set(savingRowKeys.value).add(key);
  try {
    await upsertMutation.mutateAsync({
      sourceType: target.item.source_type,
      sourceId: target.item.source_id,
      stockPicks: mapStockPicksToApi(payload.picks),
    });
    showSuccessNotification('Stock picks saved.');
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to save stock picks'));
  } finally {
    const next = new Set(savingRowKeys.value);
    next.delete(key);
    savingRowKeys.value = next;
  }
};

const groupStatusLabel = (group: ProcurementDemandGroup) => {
  if (group.document_type === 'shop_order') {
    return getStaffCatalogStatusLabel(group.document_status);
  }
  const key = `product_based_costing.status_${group.document_status}`;
  return te(key) ? t(key) : group.document_status.replaceAll('_', ' ');
};

const groupStatusColor = (status: string) => getCustomerOrderStatusColor(status);

const lineStatusStyle = (item: ProcurementDemandItem) => {
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
.treasury-table-wrap {
  flex: 1 1 0%;
  min-height: 0;
  overflow: auto;
}

.demand-table {
  min-width: 820px;
}

.demand-table :deep(thead tr th) {
  position: sticky;
  top: 0;
  z-index: 2;
  font-weight: 700;
  color: #0f172a;
  background: #f8fafc;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  padding: 6px 8px;
  border-bottom: 1px solid #e2e8f0;
}

body.body--dark .demand-table :deep(thead tr th) {
  background: #1c1c1c;
  color: #a1a1aa;
  border-bottom: 1px solid #2e2e2e;
}

.demand-table :deep(tbody td) {
  padding: 6px 8px;
  border-bottom: 1px solid #f1f5f9;
  font-size: 12.5px;
  vertical-align: middle;
}

body.body--dark .demand-table :deep(tbody td) {
  border-bottom: 1px solid #262626;
}

.demand-group-row td {
  background: #f8fafc;
  padding: 4px 8px !important;
  border-bottom: 1px solid #e2e8f0;
}

.demand-group-row:hover td {
  background: #f1f5f9;
}

body.body--dark .demand-group-row td {
  background: #242424;
  border-bottom-color: #2e2e2e;
}

.demand-image-col {
  width: 1.2in;
  min-width: 1.2in;
  max-width: 1.2in;
}

.demand-product-col {
  min-width: 140px;
  max-width: 220px;
}

.shipment-item-name-cell {
  white-space: normal;
  word-break: break-word;
  line-height: 1.25;
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

.demand-table :deep(.shipment-item-image-box .smart-image-wrapper) {
  width: 100% !important;
  height: 100% !important;
  display: block !important;
}

.demand-table :deep(.shipment-item-image-box .smart-image__img) {
  width: 100%;
  height: 100%;
  object-fit: contain;
}

.demand-table :deep(.shipment-item-image-fallback),
.demand-table :deep(.shipment-item-image-box .smart-image__fallback) {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.demand-qty-col {
  width: 64px;
  min-width: 64px;
}

.demand-place-col {
  width: 100px;
  min-width: 100px;
}

.demand-delivered-col {
  width: 130px;
  min-width: 130px;
}

.demand-delivered-cell {
  gap: 2px;
}

.demand-pick-stock-btn {
  flex-shrink: 0;
}

.demand-pick-list {
  line-height: 1.25;
  max-width: 150px;
  margin-inline: auto;
  text-align: left;
}

.demand-vendor-col {
  min-width: 150px;
  max-width: 220px;
}

.demand-field :deep(.q-field__control) {
  min-height: 30px;
}

.demand-field :deep(.q-field__native),
.demand-field :deep(.q-field__input) {
  font-size: 12px;
}

.demand-field--qty {
  min-width: 88px;
  max-width: 96px;
}

.demand-field--qty :deep(input[type='number']::-webkit-outer-spin-button),
.demand-field--qty :deep(input[type='number']::-webkit-inner-spin-button) {
  -webkit-appearance: none;
  margin: 0;
}

.demand-field--qty :deep(input[type='number']) {
  -moz-appearance: textfield;
  text-align: center;
}

.demand-group-invoice-btn {
  border-radius: 6px;
  font-size: 11px;
  min-height: 28px;
  padding: 0 10px;
}
</style>
