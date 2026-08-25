<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden">
      <q-card flat class="floating-surface shadow-1 q-pa-xs flex-shrink-0">
        <div class="row items-center justify-between q-col-gutter-xs">
          <div class="col-12 col-md-auto">
            <div class="row items-center q-gutter-x-xs quick-filter-toggle">
              <q-btn
                v-for="tab in statusTabs"
                :key="tab.value"
                dense
                unelevated
                no-caps
                :color="procurementStatus === tab.value ? 'primary' : 'transparent'"
                :text-color="procurementStatus === tab.value ? 'white' : 'grey-8'"
                class="quick-filter-btn text-xs"
                @click="setProcurementStatus(tab.value)"
              >
                {{ tab.label }}
              </q-btn>
            </div>
          </div>

          <div class="col-12 col-md-grow row items-center justify-end q-gutter-x-xs">
            <q-input
              v-model="searchText"
              outlined
              rounded
              dense
              clearable
              style="min-width: 220px"
              class="col-grow col-sm-auto dense-search-input"
              placeholder="Search product or document..."
              @keyup.enter="applySearch"
              @clear="applySearch"
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
        <q-card-section v-if="meta?.sources_included?.length" class="q-py-xs q-px-sm flex-shrink-0">
          <div class="text-caption text-grey-7">
            Sources:
            <q-chip
              v-for="source in meta.sources_included"
              :key="source"
              dense
              square
              size="sm"
              class="q-ml-xs"
            >
              {{ sourceLabel(source) }}
            </q-chip>
          </div>
        </q-card-section>

        <div class="col treasury-table-wrap q-px-sm q-pb-sm">
          <div v-if="isLoading" class="row justify-center q-pa-xl">
            <q-spinner color="primary" size="32px" />
          </div>

          <div v-else-if="isError" class="text-negative q-pa-md">
            {{ errorMessage }}
          </div>

          <div v-else-if="!groups.length" class="text-grey-7 q-pa-lg text-center">
            No procurement demand for this status.
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
                <th class="text-center demand-qty-col">Need</th>
                <th class="text-center demand-qty-col">Placed</th>
                <th class="text-center demand-qty-col">Left</th>
                <th class="text-left demand-vendor-col">Vendor</th>
                <th class="text-center demand-input-col">Qty</th>
                <th class="text-left demand-note-col">Note</th>
                <th class="text-center demand-status-col">Status</th>
                <th class="text-center demand-action-col" />
              </tr>
            </thead>
            <tbody>
              <template v-for="group in groups" :key="groupKey(group)">
                <tr
                  class="demand-group-row cursor-pointer"
                  @click="toggleGroup(groupKey(group))"
                >
                  <td colspan="10">
                    <div class="row items-center q-gutter-x-xs no-wrap">
                      <q-icon
                        :name="isGroupExpanded(groupKey(group)) ? 'ph ph-caret-down' : 'ph ph-caret-right'"
                        size="16px"
                        color="grey-7"
                      />
                      <q-icon :name="groupIcon(group.document_type)" size="16px" color="primary" />
                      <span class="text-weight-bold text-grey-9">{{ groupTitle(group) }}</span>
                      <span class="text-caption text-grey-7">· {{ group.document_status }}</span>
                      <span v-if="group.vendor?.name || group.vendor?.code" class="text-caption text-grey-7">
                        · {{ group.vendor?.name || group.vendor?.code }}
                      </span>
                      <q-space />
                      <q-badge color="grey-3" text-color="grey-9" :label="`${group.items.length} items`" />
                    </div>
                  </td>
                </tr>

                <template v-if="isGroupExpanded(groupKey(group))">
                <template v-for="item in group.items" :key="`${item.source_type}-${item.source_id}`">
                  <tr
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
                      <div
                        v-if="(item.placements?.length ?? 0) > 1"
                        class="text-caption text-grey-6 q-mt-xs placement-summary"
                      >
                        {{ placementsSummary(item) }}
                      </div>
                    </td>
                    <td class="text-center demand-qty-col text-weight-medium">{{ needQty(item) }}</td>
                    <td class="text-center demand-qty-col text-primary text-weight-medium">
                      {{ placedQty(item) }}
                    </td>
                    <td class="text-center demand-qty-col text-weight-medium">
                      {{ remainingQty(item) }}
                    </td>
                    <td class="demand-vendor-col">
                      <q-select
                        v-if="showRowInputs(item)"
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
                        placeholder="Vendor (optional)"
                        class="demand-field"
                        data-test="placement-vendor-select"
                        @filter="filterVendors"
                        @update:model-value="(v) => setDraftVendor(group, item, v)"
                      />
                      <div v-else-if="latestPlacement(item)" class="demand-readonly-cell">
                        {{ placementVendorLabel(latestPlacement(item)!) }}
                      </div>
                      <span v-else class="text-grey-6">—</span>
                    </td>
                    <td class="text-center demand-input-col">
                      <q-input
                        v-if="showRowInputs(item)"
                        :model-value="getDraft(group, item).quantity"
                        type="number"
                        min="1"
                        dense
                        outlined
                        hide-bottom-space
                        class="demand-field demand-field--qty"
                        data-test="placement-quantity"
                        @update:model-value="(v) => setDraftQuantity(group, item, v)"
                      />
                      <div v-else-if="latestPlacement(item)" class="demand-readonly-cell text-center">
                        {{ latestPlacement(item)!.quantity }}
                      </div>
                      <span v-else class="text-grey-6">—</span>
                    </td>
                    <td class="demand-note-col">
                      <q-input
                        v-if="showRowInputs(item)"
                        :model-value="getDraft(group, item).notes"
                        dense
                        outlined
                        hide-bottom-space
                        placeholder="Notes (optional)"
                        class="demand-field"
                        data-test="placement-notes"
                        @update:model-value="(v) => setDraftNotes(group, item, v)"
                      />
                      <div v-else-if="latestPlacement(item)" class="demand-readonly-cell">
                        {{ latestPlacement(item)!.notes || '—' }}
                      </div>
                      <span v-else class="text-grey-6">—</span>
                    </td>
                    <td class="text-center demand-status-col">
                      <q-select
                        v-if="canManagePlacements && latestPlacement(item) && !latestPlacement(item)!.global_shipment_item_id"
                        :model-value="'active'"
                        :options="placementStatusOptions"
                        dense
                        outlined
                        hide-bottom-space
                        emit-value
                        map-options
                        class="demand-field demand-field--status"
                        :loading="cancellingPlacementId === latestPlacement(item)!.id"
                        @update:model-value="(v) => onPlacementStatusChange(latestPlacement(item)!.id, v)"
                      />
                      <q-chip
                        v-else
                        dense
                        square
                        size="sm"
                        :color="lineStatusChip(item).color"
                        :text-color="lineStatusChip(item).textColor"
                        class="text-weight-bold"
                      >
                        {{
                          latestPlacement(item)?.global_shipment_item_id
                            ? 'On shipment'
                            : lineStatusChip(item).label
                        }}
                      </q-chip>
                    </td>
                    <td class="text-center demand-action-col">
                      <q-btn
                        v-if="showRowInputs(item)"
                        flat
                        round
                        dense
                        icon="ph ph-floppy-disk"
                        color="primary"
                        :loading="savingItemKey === itemRowKey(item)"
                        :disable="!canSaveDraft(group, item)"
                        data-test="record-placement-btn"
                        @click="saveDraft(group, item)"
                      >
                        <q-tooltip>Save placement</q-tooltip>
                      </q-btn>
                    </td>
                  </tr>
                </template>
                </template>
              </template>
            </tbody>
          </q-markup-table>
        </div>
      </q-card>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, reactive, ref } from 'vue';
import { useQuery } from '@tanstack/vue-query';
import SmartImage from 'src/components/SmartImage.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { vendorRepository } from 'src/modules/vendor/repositories/vendorRepository';
import type { Vendor } from 'src/modules/vendor/types';
import { useProcurementDemandGroupsQuery } from '../composables/useProcurementDemandGroupsQuery';
import {
  useCancelProcurementPlacementMutation,
  useRecordProcurementPlacementMutation,
} from '../composables/useProcurementPlacementMutations';
import {
  getItemNeedQuantity,
  getItemPlacedQuantity,
  getItemRemainingQuantity,
  type ProcurementDemandDocumentType,
  type ProcurementDemandGroup,
  type ProcurementDemandItem,
  type ProcurementDemandStatus,
  type ProcurementPlacement,
} from '../repositories/procurementDemandRepository';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

type ItemDraft = {
  vendorId: number | null;
  quantity: number;
  notes: string;
};

const authStore = useAuthStore();

const procurementStatus = ref<ProcurementDemandStatus>('procuring');
const searchText = ref('');
const appliedSearch = ref<string | null>(null);
const pageSize = 50;
const vendorFilter = ref('');
const savingItemKey = ref<string | null>(null);
const cancellingPlacementId = ref<number | null>(null);
const collapsedGroupKeys = ref<Set<string>>(new Set());
const drafts = reactive<Record<string, ItemDraft>>({});

const placementStatusOptions = [
  { label: 'Active', value: 'active' },
  { label: 'Cancelled', value: 'cancelled' },
];

const tenantId = computed(() => authStore.tenantId ?? null);
const canManagePlacements = computed(
  () => procurementStatus.value === 'procuring' || procurementStatus.value === 'ready_for_shipment',
);

const statusTabs: Array<{ value: ProcurementDemandStatus; label: string }> = [
  { value: 'procuring', label: 'Procuring' },
  { value: 'ready_for_shipment', label: 'Ready for shipment' },
  { value: 'delivered', label: 'Delivered' },
];

const { data, isLoading, isFetching, isError, error, refetch } = useProcurementDemandGroupsQuery({
  tenantId,
  procurementStatus,
  search: appliedSearch,
  limit: pageSize,
});

const { data: vendors = [] } = useQuery({
  queryKey: computed(() => ['vendors', 'procurementDemand', tenantId.value]),
  queryFn: () => vendorRepository.listVendors(tenantId.value),
  enabled: computed(() => tenantId.value !== null),
  staleTime: 60_000,
});

const recordPlacementMutation = useRecordProcurementPlacementMutation({
  tenantId,
  procurementStatus,
  search: appliedSearch,
  limit: pageSize,
});

const cancelPlacementMutation = useCancelProcurementPlacementMutation({
  tenantId,
  procurementStatus,
  search: appliedSearch,
  limit: pageSize,
});

const meta = computed(() => data.value?.meta ?? null);
const groups = computed(() => data.value?.groups ?? []);

const vendorOptions = computed(() => {
  const needle = vendorFilter.value.trim().toLowerCase();
  return (vendors.value as Vendor[])
    .filter((v) => {
      if (!needle) return true;
      return v.name.toLowerCase().includes(needle) || v.code.toLowerCase().includes(needle);
    })
    .map((v) => ({ id: v.id, label: `${v.name} (${v.code})`, code: v.code }));
});

const errorMessage = computed(() => {
  if (!isError.value) return '';
  const err = error.value;
  return err instanceof Error ? err.message : 'Failed to load procurement demand';
});

const itemRowKey = (item: ProcurementDemandItem) => `${item.source_type}-${item.source_id}`;

const groupKey = (group: ProcurementDemandGroup) =>
  `${group.document_type}-${group.document_id}`;

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

const needQty = (item: ProcurementDemandItem) => getItemNeedQuantity(item);
const placedQty = (item: ProcurementDemandItem) => getItemPlacedQuantity(item);
const remainingQty = (item: ProcurementDemandItem) => getItemRemainingQuantity(item);

const placementVendorLabel = (placement: ProcurementPlacement) =>
  placement.vendor_name || placement.vendor_code || '—';

const latestPlacement = (item: ProcurementDemandItem): ProcurementPlacement | null => {
  const list = item.placements ?? [];
  return list.length ? list[list.length - 1]! : null;
};

const showRowInputs = (item: ProcurementDemandItem) =>
  canManagePlacements.value && remainingQty(item) > 0;

const placementsSummary = (item: ProcurementDemandItem) =>
  (item.placements ?? [])
    .map((p) => `${placementVendorLabel(p)} ×${p.quantity}`)
    .join(' · ');

const getDraft = (group: ProcurementDemandGroup, item: ProcurementDemandItem): ItemDraft => {
  const key = itemRowKey(item);
  if (!drafts[key]) {
    const latest = latestPlacement(item);
    drafts[key] = {
      vendorId: latest?.vendor_id ?? group.vendor?.id ?? null,
      quantity: remainingQty(item) > 0 ? remainingQty(item) : (latest?.quantity ?? 1),
      notes: latest?.notes ?? '',
    };
  }
  return drafts[key];
};

const setDraftVendor = (group: ProcurementDemandGroup, item: ProcurementDemandItem, value: number | null) => {
  getDraft(group, item).vendorId = value;
};

const setDraftQuantity = (group: ProcurementDemandGroup, item: ProcurementDemandItem, value: string | number | null) => {
  const parsed = Number(value);
  getDraft(group, item).quantity = Number.isFinite(parsed) && parsed > 0 ? parsed : 1;
};

const setDraftNotes = (group: ProcurementDemandGroup, item: ProcurementDemandItem, value: string | number | null) => {
  getDraft(group, item).notes = String(value ?? '');
};

const canSaveDraft = (group: ProcurementDemandGroup, item: ProcurementDemandItem) => {
  const draft = getDraft(group, item);
  const qty = Number(draft.quantity);
  return Number.isFinite(qty) && qty > 0 && qty <= remainingQty(item);
};

const filterVendors = (val: string, update: (fn: () => void) => void) => {
  update(() => {
    vendorFilter.value = val;
  });
};

const lineStatusChip = (item: ProcurementDemandItem) => {
  const left = remainingQty(item);
  const placed = placedQty(item);
  if (left <= 0 && placed > 0) {
    return { label: 'Complete', color: 'green-1', textColor: 'positive' };
  }
  if (placed > 0) {
    return { label: 'Partial', color: 'orange-1', textColor: 'orange-9' };
  }
  return { label: 'Open', color: 'grey-2', textColor: 'grey-9' };
};

const lineStatusStyle = (item: ProcurementDemandItem) => {
  const chip = lineStatusChip(item);
  if (chip.label === 'Complete') {
    return { boxShadow: 'inset 3px 0 0 #22c55e' };
  }
  if (chip.label === 'Partial') {
    return { boxShadow: 'inset 3px 0 0 #f59e0b' };
  }
  return { boxShadow: 'inset 3px 0 0 #94a3b8' };
};

const setProcurementStatus = (status: ProcurementDemandStatus) => {
  procurementStatus.value = status;
};

const applySearch = () => {
  const trimmed = searchText.value.trim();
  appliedSearch.value = trimmed.length ? trimmed : null;
};

const sourceLabel = (source: string) => {
  if (source === 'shop_order') return 'Shop orders';
  if (source === 'pbc_costing') return 'Costing files';
  return source;
};

const groupIcon = (documentType: ProcurementDemandDocumentType) =>
  documentType === 'shop_order' ? 'ph ph-receipt' : 'ph ph-file-text';

const groupTitle = (group: ProcurementDemandGroup) => {
  if (group.document_type === 'shop_order') {
    return `Shop order #${group.document_id}`;
  }
  return `Costing file #${group.document_id}`;
};

const saveDraft = async (group: ProcurementDemandGroup, item: ProcurementDemandItem) => {
  if (!tenantId.value || !canSaveDraft(group, item)) return;

  const draft = getDraft(group, item);
  const key = itemRowKey(item);
  savingItemKey.value = key;

  try {
    const vendor = (vendors.value as Vendor[]).find((v) => v.id === draft.vendorId);
    await recordPlacementMutation.mutateAsync({
      sourceType: item.source_type,
      sourceId: item.source_id,
      quantity: Number(draft.quantity),
      vendorId: draft.vendorId,
      vendorCode: vendor?.code ?? null,
      notes: draft.notes.trim() || null,
    });
    showSuccessNotification('Vendor order recorded');
    delete drafts[key];
    await refetch();
  } catch (err) {
    showErrorNotification(err instanceof Error ? err.message : 'Failed to record placement');
  } finally {
    savingItemKey.value = null;
  }
};

const onPlacementStatusChange = async (placementId: number, status: string) => {
  if (status !== 'cancelled' || !tenantId.value) return;
  cancellingPlacementId.value = placementId;
  try {
    await cancelPlacementMutation.mutateAsync(placementId);
    showSuccessNotification('Placement cancelled');
  } catch (err) {
    showErrorNotification(err instanceof Error ? err.message : 'Failed to cancel placement');
  } finally {
    cancellingPlacementId.value = null;
  }
};
</script>

<style scoped lang="scss">
.treasury-table-wrap {
  flex: 1 1 0%;
  min-height: 0;
  overflow: auto;
}

.demand-table {
  min-width: 980px;
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

.demand-readonly-cell {
  min-height: 30px;
  padding: 4px 8px;
  font-size: 12px;
  line-height: 1.35;
  color: #334155;
  word-break: break-word;
}

body.body--dark .demand-readonly-cell {
  color: #ededed;
}

.placement-summary {
  line-height: 1.3;
  word-break: break-word;
}

.demand-image-col {
  width: 1.2in;
  min-width: 1.2in;
  max-width: 1.2in;
}

.demand-product-col {
  min-width: 160px;
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
  width: 52px;
  min-width: 52px;
}

.demand-vendor-col {
  min-width: 140px;
  max-width: 180px;
}

.demand-input-col {
  width: 100px;
  min-width: 100px;
}

.demand-note-col {
  min-width: 120px;
}

.demand-status-col {
  width: 100px;
  min-width: 100px;
}

.demand-action-col {
  width: 40px;
  min-width: 40px;
}

.demand-field :deep(.q-field__control) {
  min-height: 30px;
}

.demand-field :deep(.q-field__native),
.demand-field :deep(.q-field__input) {
  font-size: 12px;
}

.demand-field--qty {
  min-width: 92px;
  max-width: 100px;
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

.demand-field--status {
  max-width: 100px;
}
</style>
