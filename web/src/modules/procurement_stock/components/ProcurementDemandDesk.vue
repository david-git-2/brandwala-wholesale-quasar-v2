<template>
  <q-page class="q-px-xs q-py-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="column no-wrap full-height q-gutter-y-xs overflow-hidden">
      <q-card flat class="floating-surface shadow-1 demand-desk-toolbar flex-shrink-0">
        <div class="demand-desk-toolbar__inner column no-wrap">
          <div
            v-if="isFixedGroupPage"
            class="row items-center no-wrap q-gutter-x-xs"
          >
            <q-btn
              flat
              round
              dense
              icon="ph ph-arrow-left"
              color="grey-8"
              class="col-shrink"
              @click="goBackFromFixedGroup"
            >
              <q-tooltip>Back to delivery paper</q-tooltip>
            </q-btn>
            <div
              v-if="fixedGroupTitle"
              class="text-subtitle2 text-weight-bold text-grey-9 ellipsis text-left col min-width-0"
            >
              {{ fixedGroupTitle }}
            </div>
          </div>

          <div
            v-else
            class="demand-desk-toolbar__head row items-start justify-between q-col-gutter-sm no-wrap"
          >
            <header class="demand-desk-intro col min-width-0">
              <h1 class="demand-desk-intro__title">{{ deskPageTitle }}</h1>
              <p class="demand-desk-intro__subtitle">{{ deskPageSubtitle }}</p>
            </header>
            <div
              v-if="isFulfillMode"
              class="demand-desk-toolbar__status col-shrink"
            >
              <div class="demand-filter-segment" role="group" aria-label="Fulfillment status">
                <q-btn-toggle
                  v-model="fulfillProcurementStatus"
                  no-caps
                  unelevated
                  toggle-color="primary"
                  color="grey-3"
                  text-color="grey-9"
                  class="demand-status-tabs"
                  :options="fulfillStatusTabOptions"
                />
              </div>
            </div>
          </div>

          <div
            v-if="showDemandProfileBar || showPackedCloseToolbar"
            class="demand-desk-toolbar__controls column q-gutter-y-sm"
          >
            <div v-if="showDemandProfileBar" class="demand-desk-toolbar__filters column q-gutter-y-xs">
              <div
                class="demand-filter-segment demand-profile-toggle-wrap"
                role="group"
                aria-label="Customer profile"
              >
                <q-btn-toggle
                  v-model="demandProfileFilterKey"
                  no-caps
                  unelevated
                  toggle-color="primary"
                  color="grey-3"
                  text-color="grey-9"
                  class="demand-profile-toggle demand-status-tabs"
                  :options="demandProfileToggleOptions"
                />
              </div>
              <div
                v-if="showProfileToolbarActions"
                class="demand-desk-toolbar__profile-actions row items-center no-wrap q-gutter-xs"
              >
                <q-btn
                  v-if="showProfileFillOldestStockButton"
                  flat
                  no-caps
                  color="primary"
                  icon="ph ph-stack"
                  label="Fill oldest stock"
                  class="demand-profile-action-btn"
                  :loading="profileFillOldestStockLoading"
                  :disable="!canProfileFillOldestStock || profileFillOldestStockLoading"
                  @click="onProfileBulkFillOldestStock"
                />
                <q-btn
                  v-if="showProfileChangeStatusButton"
                  unelevated
                  no-caps
                  color="primary"
                  icon="ph ph-arrows-clockwise"
                  label="Change status"
                  class="demand-profile-action-btn"
                  :loading="profileChangeStatusLoading"
                  :disable="!canProfileChangeStatus || profileChangeStatusLoading"
                  @click="onProfileBulkChangeStatus"
                />
              </div>
            </div>
            <div
              v-if="showPackedCloseToolbar"
              class="row items-center q-gutter-x-sm wrap packed-close-toolbar"
            >
              <div class="row items-center q-gutter-x-xs col-shrink">
                <div class="demand-filter-segment" role="group" aria-label="Close action">
                  <q-btn-toggle
                    v-model="packedCloseActionFilter"
                    no-caps
                    unelevated
                    toggle-color="primary"
                    color="grey-3"
                    text-color="grey-9"
                    class="demand-status-tabs"
                    :options="closeActionFilterOptions"
                  />
                </div>
                <q-btn
                  v-if="packedCloseExistingInvoiceId"
                  flat
                  no-caps
                  color="grey-8"
                  icon="ph ph-receipt"
                  label="View bill"
                  @click="openPackedCloseInvoice"
                />
                <q-btn
                  v-if="canShowPackedCloseInvoiceButton"
                  unelevated
                  no-caps
                  color="primary"
                  :label="packedClosePrimaryLabel"
                  :loading="closeDocumentMutation.isPending.value"
                  :disable="!canRunPackedClose || closeDocumentMutation.isPending.value"
                  @click="onPackedClosePrimary"
                />
                <q-btn
                  v-if="canShowPackedReturnButton"
                  unelevated
                  no-caps
                  color="primary"
                  label="Return to warehouse"
                  :loading="closeDocumentMutation.isPending.value"
                  :disable="!canRunPackedReturn || closeDocumentMutation.isPending.value"
                  @click="onPackedReturnToWarehouse"
                />
              </div>
              <div
                class="row items-center q-gutter-x-md text-caption text-grey-8 packed-close-qty-summary"
                title="Open units not yet invoiced"
              >
                <span>
                  Take
                  <span class="text-weight-bold text-grey-9 font-mono q-ml-xs">
                    {{ packedCloseQtyByAction.take }}
                  </span>
                </span>
                <span>
                  Condition
                  <span class="text-weight-bold text-grey-9 font-mono q-ml-xs">
                    {{ packedCloseQtyByAction.condition }}
                  </span>
                </span>
                <span>
                  Return
                  <span class="text-weight-bold text-grey-9 font-mono q-ml-xs">
                    {{ packedCloseQtyByAction.return }}
                  </span>
                </span>
              </div>
            </div>
          </div>
        </div>
      </q-card>

      <q-card flat bordered class="col column no-wrap overflow-hidden floating-surface shadow-1 demand-desk-body">
        <q-inner-loading :showing="isLoading">
          <q-spinner-dots size="40px" color="primary" />
        </q-inner-loading>

        <div ref="demandTableScrollRef" class="col treasury-table-wrap q-px-sm q-pb-sm">
          <div
            v-if="!isLoading && visibleGroups.length === 0"
            class="column items-center justify-center full-height text-grey-7 q-pa-lg"
          >
            <q-icon name="ph ph-clipboard-text" size="40px" class="q-mb-sm" />
            <div class="text-body2">{{ emptyMessage }}</div>
          </div>

          <div v-else-if="useFulfillLineCards && listTenantId" class="demand-buy-card-grid">
            <ProcurementDemandFulfillCards
              v-for="group in visibleGroups"
              :key="groupKey(group)"
              nested
              :group="group"
              :tenant-id="listTenantId"
              :search="debouncedSearch"
              :enabled="Boolean(listTenantId)"
              :can-pick-stock="canPickStockForGroup(group)"
              :is-packed-close-mode="isPackedCloseMode(group)"
              :only-lines-with-stock-picks="packedCloseListQueueMode"
              :packed-close-action-filter="packedCloseListFilter"
              :close-action-options="closeActionOptions"
              :allocated-label="allocatedColumnLabel"
              :drafts="drafts"
              :saving-row-keys="savingRowKeys"
              :dirty-row-keys="dirtyPackedRowKeys"
              @sync-items="(items) => syncDraftsFromGroupItems(group, items)"
              @pick-stock="(item) => openStockPickDialog(group, item)"
              @close-action-change="(item, clientKey, action) =>
                onPickCloseActionChange(group, item, clientKey, action)"
              @pick-quantity-input="(item, clientKey, value) =>
                onPickQuantityInput(group, item, clientKey, value)"
              @add-close-split="(item, globalStockId) =>
                onAddCloseSplit(group, item, globalStockId)"
              @delete-close-pick="(item, clientKey) =>
                onDeletePackedPick(group, item, clientKey)"
              @save-packed-picks="(item) => onSavePackedPicks(group, item)"
              @open-source="openGroupSource(group)"
              @fill-oldest-stock="onFillOldestStockForGroup(group)"
            />
          </div>

          <div v-else-if="isBuyMode && listTenantId" class="demand-buy-card-grid">
            <ProcurementDemandBuyCards
              v-for="group in visibleGroups"
              :key="groupKey(group)"
              nested
              :group="group"
              :tenant-id="listTenantId"
              :search="debouncedSearch"
              :enabled="Boolean(listTenantId)"
              :can-edit-procuring="isProcuringGroup(group)"
              :vendor-options="vendorOptions"
              :vendors-loading="vendorsLoading"
              :drafts="drafts"
              :saving-row-keys="savingRowKeys"
              @sync-items="(items) => syncDraftsFromGroupItems(group, items)"
              @filter-vendors="filterVendors"
              @placed-quantity-input="(item, v) => onPlacedQuantityInput(group, item, v)"
              @vendor-change="(item, v) => onVendorChange(group, item, v)"
              @flush-save="(item) => flushProcuringSave(group, item)"
              @open-source="openGroupSource(group)"
              @fill-place-qty="onFillPlaceQtyForGroup(group)"
              @set-vendor="openBulkVendorDialog(group)"
            />
          </div>

          <div v-else class="demand-groups-stack column no-wrap">
            <article
              v-for="group in visibleGroups"
              :key="groupKey(group)"
              class="demand-group-block"
            >
              <section
                v-if="!isFixedGroupPage"
                class="demand-group-hero"
                :class="{
                  'demand-group-hero--expanded': showGroupItemRows(group),
                  'demand-group-hero--queue': navigatePackedGroupToPage,
                }"
              >
                <div
                  class="demand-group-hero__head row no-wrap items-center q-gutter-sm cursor-pointer"
                  role="button"
                  tabindex="0"
                  :aria-expanded="isGroupExpanded(groupKey(group))"
                  @click="onGroupRowClick(group)"
                  @keydown.enter="onGroupRowClick(group)"
                  @keydown.space.prevent="onGroupRowClick(group)"
                >
                  <q-btn
                    v-if="!isBuyMode && !navigatePackedGroupToPage"
                    flat
                    round
                    dense
                    size="sm"
                    :icon="groupRowCaretIcon(group)"
                    color="grey-8"
                    class="demand-group-hero__caret"
                    aria-label="Expand or collapse lines"
                    @click.stop="onGroupRowClick(group)"
                  />
                  <div
                    class="demand-group-hero__icon flex flex-center"
                    :class="
                      group.document_type === 'shop_order'
                        ? 'demand-group-hero__icon--shop'
                        : 'demand-group-hero__icon--costing'
                    "
                  >
                    <q-icon
                      :name="
                        group.document_type === 'shop_order'
                          ? 'ph ph-receipt'
                          : 'ph ph-file-text'
                      "
                      size="18px"
                    />
                  </div>
                  <div class="col min-width-0">
                    <div class="demand-group-hero__title ellipsis">
                      {{ groupPrimaryLabel(group) }}
                    </div>
                    <div
                      class="demand-group-hero__subtitle row items-center wrap q-gutter-x-xs q-gutter-y-xs"
                    >
                      <span class="demand-group-hero__type-pill">
                        {{ groupSourceTypeLabel(group) }}
                      </span>
                      <span class="demand-group-hero__doc-ref ellipsis">
                        {{ groupDocumentHeadline(group) }}
                      </span>
                      <span
                        v-if="group.profile_name && navigatePackedGroupToPage"
                        class="demand-group-hero__profile ellipsis"
                      >
                        {{ group.profile_name }}
                      </span>
                    </div>
                  </div>
                  <div class="demand-group-hero__meta row items-center no-wrap q-gutter-x-sm flex-shrink-0">
                    <div class="column items-end q-gutter-y-xs">
                      <q-badge
                        :color="groupStatusColor(group.document_status)"
                        text-color="white"
                        :rounded="false"
                        class="text-weight-medium demand-group-hero__status"
                        :label="groupStatusLabel(group)"
                      />
                      <span class="demand-group-hero__item-count text-caption text-grey-7">
                        {{ group.item_count }}
                        {{ group.item_count === 1 ? 'line' : 'lines' }}
                      </span>
                    </div>
                    <q-icon
                      v-if="navigatePackedGroupToPage"
                      name="ph ph-caret-right"
                      size="20px"
                      class="demand-group-hero__go text-grey-6"
                      aria-hidden="true"
                    />
                  </div>
                </div>
              </section>

              <div
                v-if="showGroupItemRows(group) && listTenantId"
                class="demand-group-lines"
                :class="{ 'demand-group-lines--under-hero': !isFixedGroupPage }"
              >
                <ProcurementDemandGroupLinesTable
                  :is-buy-mode="isBuyMode"
                  :is-fulfill-mode="isFulfillMode"
                  :allocated-column-label="allocatedColumnLabel"
                >
                  <ProcurementDemandGroupItemRows
                    :group="group"
                    :tenant-id="listTenantId"
                    :search="debouncedSearch"
                    :enabled="showGroupItemRows(group)"
                    :is-buy-mode="isBuyMode"
                    :is-fulfill-mode="isFulfillMode"
                    :can-edit-procuring="isProcuringGroup(group)"
                    :can-pick-stock="canPickStockForGroup(group)"
                    :is-packed-close-mode="isPackedCloseMode(group)"
                    :only-lines-with-stock-picks="packedCloseListQueueMode"
                    :packed-close-action-filter="packedCloseListFilter"
                    :close-action-options="closeActionOptions"
                    :table-col-count="tableColCount"
                    :vendor-options="vendorOptions"
                    :vendors-loading="vendorsLoading"
                    :drafts="drafts"
                    :saving-row-keys="savingRowKeys"
                    :dirty-row-keys="dirtyPackedRowKeys"
                    :vendor-label="vendorLabel"
                    @sync-items="(items) => syncDraftsFromGroupItems(group, items)"
                    @filter-vendors="filterVendors"
                    @placed-quantity-input="(item, v) => onPlacedQuantityInput(group, item, v)"
                    @vendor-change="(item, v) => onVendorChange(group, item, v)"
                    @flush-save="(item) => flushProcuringSave(group, item)"
                    @pick-stock="(item) => openStockPickDialog(group, item)"
                    @close-action-change="(item, clientKey, action) =>
                      onPickCloseActionChange(group, item, clientKey, action)"
                    @pick-quantity-input="(item, clientKey, value) =>
                      onPickQuantityInput(group, item, clientKey, value)"
                    @add-close-split="(item, globalStockId) =>
                      onAddCloseSplit(group, item, globalStockId)"
                    @delete-close-pick="(item, clientKey) =>
                      onDeletePackedPick(group, item, clientKey)"
                    @save-packed-picks="(item) => onSavePackedPicks(group, item)"
                  />
                </ProcurementDemandGroupLinesTable>
              </div>
            </article>
          </div>
        </div>
      </q-card>
    </div>

    <q-dialog v-model="packedCloseConfirmOpen" persistent>
      <q-card class="demand-packed-close-confirm-card">
        <q-card-section>
          <div class="text-subtitle1 text-weight-bold text-grey-9">{{ packedCloseConfirmTitle }}</div>
          <div class="text-body2 text-grey-8 q-mt-sm">{{ packedCloseConfirmMessage }}</div>
          <ul
            v-if="packedCloseConfirmDocuments.length"
            class="demand-packed-close-doc-list q-mt-sm q-mb-none q-pl-md text-body2 text-grey-9"
          >
            <li v-for="(name, idx) in packedCloseConfirmDocuments" :key="idx">{{ name }}</li>
          </ul>
          <div class="text-caption text-grey-7 q-mt-sm">{{ packedCloseConfirmSkipHint }}</div>
        </q-card-section>
        <q-card-actions align="right" class="q-px-md q-pb-md">
          <q-btn
            v-close-popup
            flat
            no-caps
            label="Cancel"
            color="grey-7"
            :disable="closeDocumentMutation.isPending.value"
          />
          <q-btn
            unelevated
            no-caps
            color="primary"
            :label="packedCloseConfirmOkLabel"
            :loading="closeDocumentMutation.isPending.value"
            :disable="closeDocumentMutation.isPending.value"
            @click="executePackedClose"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <q-dialog v-if="isBuyMode" v-model="bulkVendorDialogOpen" persistent>
      <q-card class="demand-bulk-vendor-card">
        <q-card-section>
          <div class="text-subtitle1 text-weight-bold text-grey-9">Set vendor for all lines</div>
          <div class="text-caption text-grey-7 q-mt-xs">
            Applies to every line in this group. You can edit individual rows afterward.
          </div>
        </q-card-section>
        <q-card-section>
          <q-select
            v-model="bulkVendorId"
            :options="vendorOptions"
            option-value="id"
            option-label="label"
            emit-value
            map-options
            dense
            outlined
            use-input
            input-debounce="200"
            label="Vendor"
            :loading="vendorsLoading"
            @filter="filterVendors"
          />
        </q-card-section>
        <q-card-actions align="right" class="q-px-md q-pb-md">
          <q-btn v-close-popup flat no-caps label="Cancel" color="grey-7" :disable="bulkVendorApplying" />
          <q-btn
            unelevated
            no-caps
            color="primary"
            label="Apply"
            :loading="bulkVendorApplying"
            :disable="bulkVendorApplying || bulkVendorId == null"
            @click="onApplyBulkVendor"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <ProcurementDemandStockPickDialog
      v-if="isFulfillMode"
      v-model="stockPickDialogOpen"
      :tenant-id="warehouseTenantId"
      :product-id="stockPickTarget?.productId ?? null"
      :product-name="stockPickTarget?.productName ?? ''"
      :need-quantity="stockPickTarget?.needQuantity ?? 0"
      :initial-picks="stockPickTarget?.initialPicks"
      @apply="onStockPickApply"
    />
  </q-page>
</template>

<script setup lang="ts">
import { useQuery, useQueryClient } from '@tanstack/vue-query';
import { computed, provide, reactive, ref, watch } from 'vue';
import { PROCUREMENT_DEMAND_TABLE_SCROLL_KEY } from '../shared/procurementDemandScroll';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import ProcurementDemandBuyCards from './ProcurementDemandBuyCards.vue';
import ProcurementDemandFulfillCards from './ProcurementDemandFulfillCards.vue';
import ProcurementDemandGroupItemRows from './ProcurementDemandGroupItemRows.vue';
import ProcurementDemandGroupLinesTable from './ProcurementDemandGroupLinesTable.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { vendorRepository } from 'src/modules/vendor/repositories/vendorRepository';
import type { Vendor } from 'src/modules/vendor/types';
import { getStaffCatalogStatusLabel } from 'src/modules/shop_order/utils/catalogOrderStatus';
import { getCustomerOrderStatusColor } from 'src/modules/shop_order/utils/customerOrderStatusUi';
import {
  parseSupabaseError,
  requestConfirmation,
  showErrorNotification,
  showSuccessNotification,
} from 'src/utils/appFeedback';
import { createDemandPickClientKey } from '../utils/demandStockPickClientKey';
import {
  applyCloseSplitQuantityToLot,
  restoreBaseQtyAfterRemovingSplit,
  sumWarehousePackagedPickQty,
} from '../utils/demandStockPickQty';
import ProcurementDemandStockPickDialog, {
  type DemandStockPickSelection,
} from './ProcurementDemandStockPickDialog.vue';
import { useClosePreorderDemandDocumentMutation } from '../composables/useClosePreorderDemandDocumentMutation';
import { useMarkDemandGroupReadyMutation } from '../composables/useMarkDemandGroupReadyMutation';
import {
  demandPickMatchesCloseFilter,
  resolveInvoiceIdForCloseAction,
  sumOpenClosePickQuantitiesByAction,
} from '../utils/demandClosePickFilter';
import { useProcurementDemandGroupsQuery } from '../composables/useProcurementDemandGroupsQuery';
import { useProcurementFulfillGroupsQuery } from '../composables/useProcurementFulfillGroupsQuery';
import {
  useFillPreorderDemandOldestStockMutation,
  useFillPreorderDemandPlacedQuantitiesMutation,
  useSetPreorderDemandVendorMutation,
  useUpsertPreorderDemandMutation,
} from '../composables/useProcurementPlacementMutations';
import {
  getItemDeliveredQuantity,
  type PreorderDemandCloseAction,
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

export type ProcurementDemandFixedDocument = {
  documentType: ProcurementDemandDocumentType;
  documentId: number;
  documentName?: string | null;
};

const props = defineProps<{
  mode: 'buy' | 'fulfill';
  /** Fulfill packed tab: one document's lines on a dedicated page. */
  fixedDocument?: ProcurementDemandFixedDocument | null;
}>();

const authStore = useAuthStore();
const queryClient = useQueryClient();
const route = useRoute();
const router = useRouter();
const demandTableScrollRef = ref<HTMLElement | null>(null);

provide(PROCUREMENT_DEMAND_TABLE_SCROLL_KEY, demandTableScrollRef);
const { t, te } = useI18n();

const isBuyMode = computed(() => props.mode === 'buy');
const isFulfillMode = computed(() => props.mode === 'fulfill');
const isFixedGroupPage = computed(() => props.fixedDocument != null);

const isChildWorkspace = computed(() => authStore.selectedTenant?.parent_id != null);
const tableColCount = computed(() => (isBuyMode.value ? 7 : 6));
const emptyMessage = computed(() =>
  isBuyMode.value ? 'No demand lines.' : 'No delivery paper lines.',
);

const debouncedSearch = ref('');
const demandProfileFilterKey = ref<'all' | number>('all');
const demandProfileFilterId = computed<number | null>(() =>
  demandProfileFilterKey.value === 'all' ? null : demandProfileFilterKey.value,
);
const expandedGroupKeys = ref<Set<string>>(new Set());
const drafts = reactive<Record<string, ItemDraft>>({});
const stockPickDialogOpen = ref(false);
const stockPickTarget = ref<StockPickTarget | null>(null);
const savingRowKeys = ref<Set<string>>(new Set());
const dirtyPackedRowKeys = ref<Set<string>>(new Set());

const markPackedDirty = (key: string) => {
  dirtyPackedRowKeys.value = new Set(dirtyPackedRowKeys.value).add(key);
};

const clearPackedDirty = (key: string) => {
  const next = new Set(dirtyPackedRowKeys.value);
  next.delete(key);
  dirtyPackedRowKeys.value = next;
};
const savingGroupKeys = ref<Set<string>>(new Set());
const vendorFilter = ref('');
const bulkVendorDialogOpen = ref(false);
const bulkVendorApplying = ref(false);
const bulkVendorId = ref<number | null>(null);
const bulkVendorTargetGroup = ref<ProcurementDemandGroup | null>(null);

const parentTenantId = computed(
  () => authStore.selectedTenant?.parent_id ?? authStore.tenantId ?? null,
);

const listTenantId = computed(() => {
  if (isBuyMode.value) return parentTenantId.value;
  if (isChildWorkspace.value) return authStore.tenantId ?? null;
  return parentTenantId.value;
});

const warehouseTenantId = computed(() => parentTenantId.value);

const mutationTenantId = computed(() => {
  if (isFulfillMode.value && isChildWorkspace.value) {
    return authStore.tenantId ?? null;
  }
  return parentTenantId.value;
});

const listChildTenantId = computed(() => null);

const demandProcurementStatus = ref<ProcurementDemandStatus>('procuring');
const fulfillProcurementStatus = ref<ProcurementDemandStatus>('procuring');

const fulfillStatusTabOptions = [
  { label: 'Procuring', value: 'procuring' as ProcurementDemandStatus },
  { label: 'Packed', value: 'packed' as ProcurementDemandStatus },
];

const procurementStatus = computed<ProcurementDemandStatus>(() =>
  isFulfillMode.value ? fulfillProcurementStatus.value : demandProcurementStatus.value,
);

const deskPageTitle = computed(() => {
  if (isBuyMode.value) return 'Demand paper';
  if (fulfillProcurementStatus.value === 'packed') return 'Delivery paper — packed';
  return 'Delivery paper';
});

const deskPageSubtitle = computed(() => {
  if (isBuyMode.value) {
    return 'Open each customer document below. Enter placed qty (what you ordered) and choose a vendor on every line.';
  }
  if (fulfillProcurementStatus.value === 'packed') {
    return 'Review stock picks and close lines (take or condition) when ready.';
  }
  return 'Assign warehouse stock to each line. Expand a document to pick lots.';
});

const isProcuringGroup = (group: ProcurementDemandGroup) =>
  group.document_status === 'procuring';

const canPickStockForGroup = (group: ProcurementDemandGroup) =>
  isFulfillMode.value && group.document_status === 'procuring';

const onlyPackedTabLinesWithStock = computed(
  () => isFulfillMode.value && fulfillProcurementStatus.value === 'packed',
);

const hasDemandProfileFilter = computed(() => demandProfileFilterId.value != null);

/** Packed close on one document page or when a profile filter groups the queue inline. */
const packedCloseInlineMode = computed(
  () =>
    onlyPackedTabLinesWithStock.value &&
    (isFixedGroupPage.value || hasDemandProfileFilter.value),
);

const packedCloseListQueueMode = computed(
  () => onlyPackedTabLinesWithStock.value && !packedCloseInlineMode.value,
);

const navigatePackedGroupToPage = computed(
  () => packedCloseListQueueMode.value,
);

const useFulfillLineCards = computed(
  () =>
    isFulfillMode.value &&
    (isFixedGroupPage.value ||
      fulfillProcurementStatus.value === 'procuring' ||
      packedCloseInlineMode.value),
);

const isPackedCloseMode = (group: ProcurementDemandGroup) =>
  onlyPackedTabLinesWithStock.value && group.document_status === 'packed';

const closeActionOptions = [
  { label: 'Take', value: 'take' as const },
  { label: 'Condition', value: 'condition' as const },
];

type PackedCloseFilterTab = 'all' | PreorderDemandCloseAction;

const closeActionFilterOptions: Array<{ label: string; value: PackedCloseFilterTab }> = [
  { label: 'All', value: 'all' },
  { label: 'Take', value: 'take' },
  { label: 'Condition', value: 'condition' },
  { label: 'Return', value: 'return' },
];

const showPackedCloseToolbar = computed(() => packedCloseInlineMode.value);

const packedCloseActionFilter = ref<PackedCloseFilterTab>('all');

const packedCloseListFilter = computed<PreorderDemandCloseAction | null>(() =>
  packedCloseActionFilter.value === 'all' ? null : packedCloseActionFilter.value,
);

const packedGroupsForClose = computed(() =>
  visibleGroups.value.filter((g) => isPackedCloseMode(g)),
);

const packedCloseExistingInvoiceId = computed(() => {
  const action = packedCloseListFilter.value;
  if (!action || action === 'return') return null;
  const invoiceIds = new Set<number>();
  for (const group of packedGroupsForClose.value) {
    const prefix = `${group.document_type}-${group.document_id}-`;
    const id = resolveInvoiceIdForCloseAction(group, action, drafts, prefix);
    if (id != null) invoiceIds.add(id);
  }
  if (invoiceIds.size === 1) return [...invoiceIds][0] ?? null;
  return null;
});

const packedCloseQtyByAction = computed(() => {
  const totals: Record<PreorderDemandCloseAction, number> = {
    take: 0,
    condition: 0,
    return: 0,
  };
  for (const group of packedGroupsForClose.value) {
    const prefix = `${group.document_type}-${group.document_id}-`;
    const part = sumOpenClosePickQuantitiesByAction(drafts, prefix);
    totals.take += part.take;
    totals.condition += part.condition;
    totals.return += part.return;
  }
  return totals;
});

const openPackedCloseInvoice = () => {
  const billId = packedCloseExistingInvoiceId.value;
  if (!billId) return;
  const tenantSlug = authStore.tenantSlug || undefined;
  void router.push({
    name: 'app-bill-compose-page',
    params: tenantSlug ? { tenantSlug } : {},
    query: { id: String(billId) },
  });
};

const packedClosePrimaryLabel = computed(() => 'Create invoice');
const packedCloseIsReturnClose = computed(
  () => packedClosePendingActions.value.length === 1 && packedClosePendingActions.value[0] === 'return',
);
const packedCloseConfirmSkipHint = computed(() =>
  packedCloseIsReturnClose.value
    ? 'Lines already returned or invoiced are skipped.'
    : 'Lines already invoiced are skipped.',
);

const closeDocumentMutation = useClosePreorderDemandDocumentMutation();

const packedCloseConfirmOpen = ref(false);
const packedCloseConfirmTitle = ref('');
const packedCloseConfirmMessage = ref('');
const packedCloseConfirmDocuments = ref<string[]>([]);
const packedClosePendingAction = ref<PreorderDemandCloseAction | null>(null);
const packedClosePendingActions = ref<PreorderDemandCloseAction[]>([]);

const packedCloseConfirmOkLabel = computed(() =>
  packedCloseIsReturnClose.value ? 'Return to warehouse' : 'Create invoice',
);

const countOpenClosePicksForFilter = (
  action: PreorderDemandCloseAction,
): { documentCount: number; unitCount: number } => {
  let documentCount = 0;
  let unitCount = 0;
  const packedGroups = visibleGroups.value.filter((g) => isPackedCloseMode(g));
  for (const group of packedGroups) {
    const prefix = `${groupKey(group)}-`;
    let groupUnits = 0;
    for (const [key, draft] of Object.entries(drafts)) {
      if (!key.startsWith(prefix)) continue;
      for (const pick of draft.stockPicks) {
        if (demandPickMatchesCloseFilter(pick, action)) {
          groupUnits += pick.quantity;
        }
      }
    }
    if (groupUnits > 0) {
      documentCount += 1;
      unitCount += groupUnits;
    }
  }
  return { documentCount, unitCount };
};

const packedCloseInvoiceActions = (
  action: PreorderDemandCloseAction | 'all' | null,
): PreorderDemandCloseAction[] => {
  if (action === 'condition' || action === 'take') return [action];
  if (action === 'all' || action == null) return ['take', 'condition'];
  return [];
};

const canShowPackedCloseInvoiceButton = computed(() => {
  const action = packedCloseActionFilter.value;
  return action === 'all' || action === 'take' || action === 'condition';
});

const canShowPackedReturnButton = computed(() => packedCloseActionFilter.value === 'return');

const canRunPackedClose = computed(() => {
  const action = packedCloseActionFilter.value;
  if (action === 'return' || !mutationTenantId.value) return false;
  const actions = packedCloseInvoiceActions(action);
  return actions.some((closeAction) => countOpenClosePicksForFilter(closeAction).unitCount > 0);
});

const canRunPackedReturn = computed(() => {
  if (!mutationTenantId.value) return false;
  return countOpenClosePicksForFilter('return').unitCount > 0;
});

const onPackedClosePrimary = () => {
  const action = packedCloseActionFilter.value;
  if (action === 'return' || !mutationTenantId.value) return;

  const packedGroups = visibleGroups.value.filter((g) => isPackedCloseMode(g));
  if (!packedGroups.length) return;

  const actions = packedCloseInvoiceActions(action);
  const preview = actions.reduce(
    (acc, closeAction) => {
      const part = countOpenClosePicksForFilter(closeAction);
      acc.documentCount = Math.max(acc.documentCount, part.documentCount);
      acc.unitCount += part.unitCount;
      return acc;
    },
    { documentCount: 0, unitCount: 0 },
  );

  const actionLabel =
    action === 'all' ? 'take and condition' : (closeActionOptions.find((o) => o.value === action)?.label ?? action);

  packedClosePendingAction.value = action === 'all' ? 'take' : action;
  packedClosePendingActions.value = actions;
  packedCloseConfirmTitle.value =
    action === 'condition' ? 'Create condition bill?' : `Create ${actionLabel} invoice?`;
  packedCloseConfirmMessage.value =
    `This will create ${actionLabel} bill(s) for ${preview.unitCount} unit(s) on ${preview.documentCount} order(s)/file(s).`;
  packedCloseConfirmDocuments.value = packedGroups.map((g) => groupTitle(g));
  packedCloseConfirmOpen.value = true;
};

const onPackedReturnToWarehouse = () => {
  if (!mutationTenantId.value) return;

  const packedGroups = visibleGroups.value.filter((g) => isPackedCloseMode(g));
  if (!packedGroups.length) return;

  const preview = countOpenClosePicksForFilter('return');
  packedClosePendingAction.value = 'return';
  packedClosePendingActions.value = ['return'];
  packedCloseConfirmTitle.value = 'Return stock to warehouse?';
  packedCloseConfirmMessage.value =
    `This will put ${preview.unitCount} unit(s) back as sellable warehouse stock on ${preview.documentCount} order(s)/file(s).`;
  packedCloseConfirmDocuments.value = packedGroups.map((g) => groupTitle(g));
  packedCloseConfirmOpen.value = true;
};

const executePackedClose = async () => {
  const actions =
    packedClosePendingActions.value.length > 0
      ? packedClosePendingActions.value
      : packedCloseInvoiceActions(packedClosePendingAction.value);
  const tenantId = mutationTenantId.value;
  if (!actions.length || !tenantId) return;

  const packedGroups = visibleGroups.value.filter((g) => isPackedCloseMode(g));
  if (!packedGroups.length) {
    packedCloseConfirmOpen.value = false;
    return;
  }

  let createdDocs = 0;
  let createdUnits = 0;
  try {
    for (const group of packedGroups) {
      let groupCreated = false;
      for (const closeAction of actions) {
        const result = await closeDocumentMutation.mutateAsync({
          tenantId,
          documentType: group.document_type,
          documentId: group.document_id,
          closeAction,
        });
        if (result.created) {
          groupCreated = true;
          createdUnits += result.unit_count ?? 0;
        }
      }
      if (groupCreated) createdDocs += 1;
    }
    packedCloseConfirmOpen.value = false;
    packedClosePendingActions.value = [];
    if (createdDocs === 0) {
      showSuccessNotification('Nothing left to close for this filter.');
    } else if (actions.length === 1 && actions[0] === 'return') {
      showSuccessNotification(`Returned ${createdUnits} unit(s) to warehouse on ${createdDocs} document(s).`);
    } else {
      showSuccessNotification(`Created bill(s) for ${createdUnits} unit(s) across ${createdDocs} document(s).`);
    }
    await refreshDemandDesk();
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to close delivery paper picks'));
  }
};

watch(onlyPackedTabLinesWithStock, (packed) => {
  if (!packed) packedCloseActionFilter.value = 'all';
});

watch(
  () =>
    [isFixedGroupPage.value, onlyPackedTabLinesWithStock.value, hasDemandProfileFilter.value] as const,
  ([fixed, packed, profile]) => {
    if (packed && (fixed || profile) && packedCloseActionFilter.value == null) {
      packedCloseActionFilter.value = 'all';
    }
  },
  { immediate: true },
);

const allocatedColumnLabel = computed(() => {
  if (isFulfillMode.value && fulfillProcurementStatus.value === 'packed') {
    return 'Going out / close';
  }
  return 'Allocated';
});

const {
  data: demandData,
  isLoading: isDemandLoading,
  isFetching: isDemandFetching,
  refetch: refetchDemandGroups,
} = useProcurementDemandGroupsQuery({
  tenantId: listTenantId,
  procurementStatus: demandProcurementStatus,
  search: debouncedSearch,
  childTenantId: listChildTenantId,
  enabled: isBuyMode,
});

const {
  data: fulfillData,
  isLoading: isFulfillLoading,
  isFetching: isFulfillFetching,
  refetch: refetchFulfillGroups,
} = useProcurementFulfillGroupsQuery({
  tenantId: listTenantId,
  procurementStatus: fulfillProcurementStatus,
  search: debouncedSearch,
  enabled: isFulfillMode,
});

const isLoading = computed(() =>
  isFulfillMode.value ? isFulfillLoading.value : isDemandLoading.value,
);
const isFetching = computed(() =>
  isFulfillMode.value ? isFulfillFetching.value : isDemandFetching.value,
);

const groups = computed(() => {
  if (isFulfillMode.value) return fulfillData.value?.groups ?? [];
  return demandData.value?.groups ?? [];
});

const demandProfileFacets = computed(() => {
  const byId = new Map<number, string>();
  for (const group of groups.value) {
    const id = group.profile_id;
    if (id == null) continue;
    const name = group.profile_name?.trim() || `Profile #${id}`;
    byId.set(id, name);
  }
  return [...byId.entries()]
    .map(([id, name]) => ({ id, name }))
    .sort((a, b) => a.name.localeCompare(b.name));
});

const demandProfileToggleOptions = computed(() => {
  const options: Array<{ label: string; value: 'all' | number }> = [{ label: 'All', value: 'all' }];
  for (const facet of demandProfileFacets.value) {
    options.push({ label: facet.name, value: facet.id });
  }
  return options;
});

const showDemandProfileBar = computed(
  () =>
    (isBuyMode.value || isFulfillMode.value) &&
    !isFixedGroupPage.value &&
    demandProfileFacets.value.length > 0 &&
    !(isFulfillMode.value && fulfillProcurementStatus.value === 'packed'),
);

watch(demandProfileFacets, (facets) => {
  const key = demandProfileFilterKey.value;
  if (key === 'all') return;
  if (!facets.some((facet) => facet.id === key)) {
    demandProfileFilterKey.value = 'all';
  }
});

watch(fulfillProcurementStatus, () => {
  demandProfileFilterKey.value = 'all';
});

const stubFixedGroup = (): ProcurementDemandGroup | null => {
  const fixed = props.fixedDocument;
  if (!fixed) return null;
  const name = fixed.documentName?.trim();
  return {
    document_type: fixed.documentType,
    document_id: fixed.documentId,
    document_name: name || null,
    document_status: 'packed',
    customer_group_name: null,
    profile_id: null,
    profile_name: null,
    vendor: null,
    item_count: 0,
    unallocated_item_count: 0,
  };
};

const visibleGroups = computed(() => {
  const fixed = props.fixedDocument;
  if (fixed) {
    const match = groups.value.find(
      (g) => g.document_type === fixed.documentType && g.document_id === fixed.documentId,
    );
    const stub = stubFixedGroup();
    return match ? [match] : stub ? [stub] : [];
  }
  const profileId = demandProfileFilterId.value;
  if (profileId == null) return groups.value;
  return groups.value.filter((group) => group.profile_id === profileId);
});

const fixedGroupTitle = computed(() => {
  const group = visibleGroups.value[0];
  return group ? groupTitle(group) : '';
});

const upsertMutation = useUpsertPreorderDemandMutation({
  tenantId: mutationTenantId,
  procurementStatus,
  search: debouncedSearch,
  childTenantId: listChildTenantId,
  profileId: demandProfileFilterId,
});

const fillOldestStockMutation = useFillPreorderDemandOldestStockMutation({
  tenantId: mutationTenantId,
});

const fillPlacedQtyMutation = useFillPreorderDemandPlacedQuantitiesMutation({
  tenantId: mutationTenantId,
  procurementStatus,
  search: debouncedSearch,
  childTenantId: listChildTenantId,
  profileId: demandProfileFilterId,
});

const setVendorMutation = useSetPreorderDemandVendorMutation({
  tenantId: mutationTenantId,
  procurementStatus,
  search: debouncedSearch,
  childTenantId: listChildTenantId,
  profileId: demandProfileFilterId,
});

const markReadyMutation = useMarkDemandGroupReadyMutation();

const refreshDemandDesk = async () => {
  if (isFulfillMode.value) {
    await refetchFulfillGroups();
    void queryClient.invalidateQueries({ queryKey: ['procurementStock', 'fulfillGroupItems'] });
  } else {
    await refetchDemandGroups();
    void queryClient.invalidateQueries({ queryKey: ['procurementStock', 'demandGroupItems'] });
  }
};

const { data: vendors = [], isLoading: vendorsLoading } = useQuery({
  queryKey: computed(() => ['vendors', 'forDemand', parentTenantId.value]),
  queryFn: () => vendorRepository.listVendors(parentTenantId.value!),
  enabled: computed(() => parentTenantId.value !== null),
  staleTime: 60_000,
});

const vendorOptions = computed(() => {
  const needle = vendorFilter.value.trim().toLowerCase();
  const list = (vendors.value ?? []) as Vendor[];
  return list
    .filter((vendor) => {
      if (!needle) return true;
      return (
        vendor.name.toLowerCase().includes(needle) ||
        vendor.code.toLowerCase().includes(needle)
      );
    })
    .map((vendor) => ({
      id: vendor.id,
      label: vendor.code?.trim() || vendor.name,
    }));
});

const filterVendors = (val: string, update: (fn: () => void) => void) => {
  update(() => {
    vendorFilter.value = val;
  });
};

const vendorLabel = (vendorId: number | null) => {
  if (!vendorId) return '—';
  const match = ((vendors.value ?? []) as Vendor[]).find((vendor) => vendor.id === vendorId);
  return match ? match.code?.trim() || match.name : String(vendorId);
};

const mapStockPicksFromApi = (picks?: PreorderDemandStockPick[]): DemandStockPickSelection[] => {
  const seenStockIds = new Set<number>();
  return (picks ?? []).map((pick) => {
    const globalStockId = Number(pick.global_stock_id);
    const isCloseSplit = pick.close_split === true || seenStockIds.has(globalStockId);
    seenStockIds.add(globalStockId);
    const initialQuantity = isCloseSplit
      ? undefined
      : (pick.initial_quantity ?? pick.quantity);
    return {
      clientKey: createDemandPickClientKey(),
      globalStockId,
      shipmentName: pick.shipment_name ?? '',
      locationName: pick.location_name ?? '',
      quantity: pick.quantity,
      initialQuantity,
      closeAction: pick.close_action ?? 'take',
      isCloseSplit,
      invoiceId: pick.invoice_id ?? null,
      returnedAt: pick.returned_at ?? null,
    };
  });
};

const mapStockPicksToApi = (picks: DemandStockPickSelection[]): PreorderDemandStockPick[] =>
  picks.map((pick) => ({
    global_stock_id: pick.globalStockId,
    quantity: pick.quantity,
    shipment_name: pick.shipmentName || null,
    location_name: pick.locationName || null,
    close_action: pick.closeAction ?? 'take',
    ...(pick.isCloseSplit ? { close_split: true } : {}),
    ...(!pick.isCloseSplit && pick.initialQuantity != null
      ? { initial_quantity: pick.initialQuantity }
      : {}),
    ...(pick.invoiceId != null ? { invoice_id: pick.invoiceId } : {}),
    ...(pick.returnedAt ? { returned_at: pick.returnedAt } : {}),
  }));

/** Server still rejects qty 0 on some DBs; keep empty splits in the local draft only. */
const stockPicksForApi = (picks: DemandStockPickSelection[]) =>
  mapStockPicksToApi(picks.filter((pick) => !pick.isCloseSplit || pick.quantity > 0));

const mergeLocalUnsavedSplits = (
  incoming: DemandStockPickSelection[],
  local: DemandStockPickSelection[] | undefined,
): DemandStockPickSelection[] => {
  if (!local?.length) return incoming;
  const unsaved = local.filter((pick) => pick.isCloseSplit && pick.quantity < 1);
  if (!unsaved.length) return incoming;
  const incomingKeys = new Set(incoming.map((pick) => pick.clientKey));
  return [...incoming, ...unsaved.filter((pick) => !incomingKeys.has(pick.clientKey))];
};

const stockPicksFromItem = (item: ProcurementDemandItem) =>
  mapStockPicksFromApi(item.stock_picks);

const packagedQtyFromPicks = (picks: DemandStockPickSelection[]) => {
  const qty = sumWarehousePackagedPickQty(picks);
  return qty > 0 ? qty : null;
};

const syncDraftsFromGroupItems = (
  group: ProcurementDemandGroup,
  items: ProcurementDemandItem[],
) => {
  for (const item of items) {
    const key = itemRowKey(group, item);
    if (savingRowKeys.value.has(key) || dirtyPackedRowKeys.value.has(key)) continue;
    const incoming = stockPicksFromItem(item);
    const stockPicks = mergeLocalUnsavedSplits(incoming, drafts[key]?.stockPicks);
    drafts[key] = {
      vendorId: item.vendor_id ?? null,
      quantity: normalizeDraftQuantity(item.placed_quantity),
      deliveredQuantity: packagedQtyFromPicks(stockPicks),
      stockPicks,
    };
  }
};

const groupKey = (group: ProcurementDemandGroup) =>
  `${group.document_type}-${group.document_id}`;

const itemRowKey = (group: ProcurementDemandGroup, item: ProcurementDemandItem) =>
  `${groupKey(group)}-${item.source_type}-${item.source_id}`;

const isRowSaving = (group: ProcurementDemandGroup, item: ProcurementDemandItem) =>
  savingRowKeys.value.has(itemRowKey(group, item));

const isGroupExpanded = (key: string) => expandedGroupKeys.value.has(key);

const showGroupItemRows = (group: ProcurementDemandGroup) => {
  if (isFixedGroupPage.value) return true;
  if (navigatePackedGroupToPage.value) return false;
  if (isBuyMode.value) return true;
  return isGroupExpanded(groupKey(group));
};

const groupRowCaretIcon = (group: ProcurementDemandGroup) => {
  if (navigatePackedGroupToPage.value) return 'ph ph-arrow-right';
  return isGroupExpanded(groupKey(group)) ? 'ph ph-caret-down' : 'ph ph-caret-right';
};

const onGroupRowClick = (group: ProcurementDemandGroup) => {
  if (isFixedGroupPage.value) return;
  if (navigatePackedGroupToPage.value) {
    openFulfillGroupPage(group);
    return;
  }
  toggleGroup(groupKey(group));
};

const toggleGroup = (key: string) => {
  const next = new Set(expandedGroupKeys.value);
  if (next.has(key)) {
    next.delete(key);
  } else {
    next.add(key);
  }
  expandedGroupKeys.value = next;
};

const groupPrimaryLabel = (group: ProcurementDemandGroup) =>
  group.customer_group_name?.trim() || '—';

const groupSourceTypeLabel = (group: ProcurementDemandGroup) =>
  group.document_type === 'shop_order' ? 'Shop order' : 'Costing file';

const groupShopOrderRef = (group: ProcurementDemandGroup) => {
  const no = group.shop_order_no?.trim() || group.document_name?.trim();
  if (no) return no;
  return `#${group.document_id}`;
};

const groupCostingFileRef = (group: ProcurementDemandGroup) => {
  const name = group.document_name?.trim();
  if (name) return `${name} (#${group.document_id})`;
  return `File #${group.document_id}`;
};

/** Document identity under the customer-group hero title. */
const groupDocumentHeadline = (group: ProcurementDemandGroup) => {
  if (group.document_type === 'shop_order') {
    return groupShopOrderRef(group);
  }
  const name = group.document_name?.trim();
  if (name) return `${name} · #${group.document_id}`;
  return `Costing file #${group.document_id}`;
};

const groupHeaderTooltip = (group: ProcurementDemandGroup) => {
  const parts = [groupPrimaryLabel(group), groupSourceTypeLabel(group)];
  if (group.document_type === 'shop_order') {
    parts.push(groupShopOrderRef(group));
  } else {
    parts.push(groupCostingFileRef(group));
  }
  return parts.join(' · ');
};

/** Confirmations and toasts: customer group + document reference. */
const groupTitle = (group: ProcurementDemandGroup) => groupHeaderTooltip(group);

const getDraft = (group: ProcurementDemandGroup, item: ProcurementDemandItem): ItemDraft => {
  const key = itemRowKey(group, item);
  if (!drafts[key]) {
    const stockPicks = stockPicksFromItem(item);
    drafts[key] = {
      vendorId: item.vendor_id ?? null,
      quantity: normalizeDraftQuantity(item.placed_quantity),
      deliveredQuantity: packagedQtyFromPicks(stockPicks),
      stockPicks,
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
  if (!isProcuringGroup(group) || !isProcuringDraftDirty(group, item)) return;
  void saveProcuringLine(group, item);
};

const saveProcuringLine = async (
  group: ProcurementDemandGroup,
  item: ProcurementDemandItem,
): Promise<boolean> => {
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
    return true;
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to save demand line'));
    return false;
  } finally {
    const next = new Set(savingRowKeys.value);
    next.delete(key);
    savingRowKeys.value = next;
  }
};

const fillOldestStockForGroup = async (group: ProcurementDemandGroup) => {
  const gk = groupKey(group);
  savingGroupKeys.value = new Set(savingGroupKeys.value).add(gk);
  try {
    return await fillOldestStockMutation.mutateAsync({
      documentType: group.document_type,
      documentId: group.document_id,
    });
  } finally {
    const next = new Set(savingGroupKeys.value);
    next.delete(gk);
    savingGroupKeys.value = next;
  }
};

const onFillOldestStockForGroup = async (group: ProcurementDemandGroup) => {
  const ok = await requestConfirmation(
    `Fill oldest stock for all lines in ${groupTitle(group)}? Lines without enough stock are left empty. Lines that already have picks are skipped.`,
    'Fill oldest stock',
    'Fill stock',
  );
  if (!ok) return;
  try {
    const result = await fillOldestStockForGroup(group);
    showSuccessNotification(
      `Stock picks saved for ${result.updated_count} line(s). ${result.skipped_count} line(s) skipped.`,
    );
    await refreshDemandDesk();
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to fill oldest stock'));
  }
};

const onProfileBulkFillOldestStock = async () => {
  const groups = profileFillOldestStockGroups.value;
  if (!groups.length) return;

  const message =
    groups.length === 1
      ? `Fill oldest stock for all lines in ${groupTitle(groups[0])}? Lines without enough stock are left empty. Lines that already have picks are skipped.`
      : `Fill oldest stock for all lines in ${groups.length} order(s)/file(s) for this profile? Lines without enough stock are left empty. Lines that already have picks are skipped.`;

  const ok = await requestConfirmation(message, 'Fill oldest stock', 'Fill stock');
  if (!ok) return;

  profileBulkFillOldestRunning.value = true;
  let updatedTotal = 0;
  let skippedTotal = 0;
  try {
    for (const group of groups) {
      const result = await fillOldestStockForGroup(group);
      updatedTotal += result.updated_count;
      skippedTotal += result.skipped_count;
    }
    showSuccessNotification(
      `Stock picks saved for ${updatedTotal} line(s). ${skippedTotal} line(s) skipped.`,
    );
    await refreshDemandDesk();
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to fill oldest stock'));
  } finally {
    profileBulkFillOldestRunning.value = false;
  }
};

const onFillPlaceQtyForGroup = async (group: ProcurementDemandGroup) => {
  if (!isProcuringGroup(group)) return;
  const ok = await requestConfirmation(
    `Set placed qty from customer need on all ${group.item_count} line(s) in ${groupTitle(group)}? Existing placed qty values will be overwritten.`,
    'Fill placed qty',
    'Fill placed qty',
  );
  if (!ok) return;
  const gk = groupKey(group);
  savingGroupKeys.value = new Set(savingGroupKeys.value).add(gk);
  try {
    const result = await fillPlacedQtyMutation.mutateAsync({
      documentType: group.document_type,
      documentId: group.document_id,
    });
    showSuccessNotification(
      `Placed quantities updated for ${result.updated_count} line(s).`,
    );
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to fill placed quantities'));
  } finally {
    const next = new Set(savingGroupKeys.value);
    next.delete(gk);
    savingGroupKeys.value = next;
  }
};

const openBulkVendorDialog = (group: ProcurementDemandGroup) => {
  bulkVendorTargetGroup.value = group;
  const defaultVendor = ((vendors.value ?? []) as Vendor[]).find((vendor) => vendor.is_default);
  bulkVendorId.value = defaultVendor?.id ?? null;
  bulkVendorDialogOpen.value = true;
};

const onApplyBulkVendor = async () => {
  const group = bulkVendorTargetGroup.value;
  if (!group || bulkVendorId.value == null) {
    showErrorNotification('Select a vendor.');
    return;
  }
  const gk = groupKey(group);
  bulkVendorApplying.value = true;
  savingGroupKeys.value = new Set(savingGroupKeys.value).add(gk);
  try {
    const result = await setVendorMutation.mutateAsync({
      documentType: group.document_type,
      documentId: group.document_id,
      vendorId: bulkVendorId.value,
    });
    showSuccessNotification(`Vendor applied to ${result.updated_count} line(s).`);
    bulkVendorDialogOpen.value = false;
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to set vendor on demand lines'));
  } finally {
    bulkVendorApplying.value = false;
    const next = new Set(savingGroupKeys.value);
    next.delete(gk);
    savingGroupKeys.value = next;
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
    needQuantity: item.quantity,
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
  draft.stockPicks = payload.picks.map((pick) => ({
    ...pick,
    isCloseSplit: false,
    initialQuantity: pick.initialQuantity ?? pick.quantity,
  }));
  draft.deliveredQuantity = packagedQtyFromPicks(draft.stockPicks);

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

const isGroupSaving = (group: ProcurementDemandGroup) =>
  savingGroupKeys.value.has(groupKey(group));

const canChangeFulfillStatus = (group: ProcurementDemandGroup) =>
  isFulfillMode.value &&
  procurementStatus.value === 'procuring' &&
  isProcuringGroup(group);

const showProfileToolbarActions = computed(
  () =>
    isFulfillMode.value &&
    !isFixedGroupPage.value &&
    hasDemandProfileFilter.value &&
    fulfillProcurementStatus.value === 'procuring',
);

const showProfileChangeStatusButton = computed(() => showProfileToolbarActions.value);

const showProfileFillOldestStockButton = computed(() => showProfileToolbarActions.value);

const profileFillOldestStockGroups = computed(() =>
  visibleGroups.value.filter((group) => canPickStockForGroup(group)),
);

const canProfileFillOldestStock = computed(() => profileFillOldestStockGroups.value.length > 0);

const profileBulkFillOldestRunning = ref(false);

const profileFillOldestStockLoading = computed(
  () => fillOldestStockMutation.isPending.value || profileBulkFillOldestRunning.value,
);

const profileChangeStatusGroups = computed(() =>
  visibleGroups.value.filter((group) => canChangeFulfillStatus(group)),
);

const canProfileChangeStatus = computed(() => profileChangeStatusGroups.value.length > 0);

const profileBulkStatusRunning = ref(false);

const profileChangeStatusLoading = computed(
  () => markReadyMutation.isPending.value || profileBulkStatusRunning.value,
);

const markGroupPacked = async (group: ProcurementDemandGroup) => {
  const key = groupKey(group);
  savingGroupKeys.value = new Set(savingGroupKeys.value).add(key);
  try {
    await markReadyMutation.mutateAsync(group);
  } finally {
    const next = new Set(savingGroupKeys.value);
    next.delete(key);
    savingGroupKeys.value = next;
  }
};

const onChangeGroupStatus = async (group: ProcurementDemandGroup) => {
  if (!isProcuringGroup(group)) return;

  const ok = await requestConfirmation(
    `Mark ${groupTitle(group)} as packed?`,
    'Mark packed',
    'Mark packed',
  );
  if (!ok) return;

  try {
    await markGroupPacked(group);
    showSuccessNotification('Marked packed.');
    fulfillProcurementStatus.value = 'packed';
    await refreshDemandDesk();
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to mark packed'));
  }
};

const onProfileBulkChangeStatus = async () => {
  const groups = profileChangeStatusGroups.value;
  if (!groups.length) return;

  const message =
    groups.length === 1
      ? `Mark ${groupTitle(groups[0])} as packed?`
      : `Mark ${groups.length} order(s)/file(s) for this profile as packed?`;

  const ok = await requestConfirmation(message, 'Mark packed', 'Mark packed');
  if (!ok) return;

  profileBulkStatusRunning.value = true;
  try {
    for (const group of groups) {
      await markGroupPacked(group);
    }
    showSuccessNotification(
      groups.length === 1 ? 'Marked packed.' : `Marked ${groups.length} document(s) packed.`,
    );
    fulfillProcurementStatus.value = 'packed';
    await refreshDemandDesk();
  } catch (err) {
    showErrorNotification(parseSupabaseError(err, 'Failed to mark packed'));
  } finally {
    profileBulkStatusRunning.value = false;
  }
};

const openFulfillGroupPage = (group: ProcurementDemandGroup) => {
  void router.push({
    name: 'app-procurement-fulfill-group',
    params: {
      tenantSlug: authStore.tenantSlug || '',
      documentType: group.document_type,
      documentId: String(group.document_id),
    },
    query: {
      status: 'packed',
      documentName: group.document_name?.trim() || undefined,
    },
  });
};

const goBackFromFixedGroup = () => {
  void router.push({
    name: 'app-procurement-fulfill',
    params: { tenantSlug: authStore.tenantSlug || '' },
    query: { status: 'packed' },
  });
};

const persistPackedPicks = async (
  group: ProcurementDemandGroup,
  item: ProcurementDemandItem,
  nextPicks: DemandStockPickSelection[],
  successMessage: string,
) => {
  const key = itemRowKey(group, item);
  const draft = getDraft(group, item);
  const previousPicks = draft.stockPicks;
  const packagedQty = sumWarehousePackagedPickQty(nextPicks);
  drafts[key] = {
    ...draft,
    stockPicks: nextPicks,
    deliveredQuantity: packagedQty > 0 ? packagedQty : null,
  };
  savingRowKeys.value = new Set(savingRowKeys.value).add(key);
  try {
    await upsertMutation.mutateAsync({
      sourceType: item.source_type,
      sourceId: item.source_id,
      stockPicks: stockPicksForApi(nextPicks),
    });
    clearPackedDirty(key);
    showSuccessNotification(successMessage);
  } catch (err) {
    drafts[key] = {
      ...drafts[key],
      stockPicks: previousPicks,
      deliveredQuantity: packagedQtyFromPicks(previousPicks),
    };
    showErrorNotification(parseSupabaseError(err, 'Failed to save close choice'));
  } finally {
    const next = new Set(savingRowKeys.value);
    next.delete(key);
    savingRowKeys.value = next;
  }
};

const onPickCloseActionChange = (
  group: ProcurementDemandGroup,
  item: ProcurementDemandItem,
  clientKey: string,
  closeAction: 'take' | 'condition' | 'return' | null,
) => {
  const key = itemRowKey(group, item);
  const draft = getDraft(group, item);
  drafts[key] = {
    ...draft,
    stockPicks: draft.stockPicks.map((pick) =>
      pick.clientKey === clientKey ? { ...pick, closeAction } : pick,
    ),
  };
  markPackedDirty(key);
};

const onPickQuantityInput = (
  group: ProcurementDemandGroup,
  item: ProcurementDemandItem,
  clientKey: string,
  value: string | number | null,
) => {
  if (value === '' || value === null) return;
  const qty = Math.trunc(Number(value));
  if (!Number.isFinite(qty) || qty < 0) return;
  const key = itemRowKey(group, item);
  const draft = getDraft(group, item);
  const nextPicks = applyCloseSplitQuantityToLot(draft.stockPicks, clientKey, qty);
  drafts[key] = {
    ...draft,
    stockPicks: nextPicks,
    deliveredQuantity: packagedQtyFromPicks(nextPicks),
  };
  markPackedDirty(key);
};

const onAddCloseSplit = (
  group: ProcurementDemandGroup,
  item: ProcurementDemandItem,
  globalStockId: number,
) => {
  const draft = getDraft(group, item);
  const source =
    draft.stockPicks.find((pick) => pick.globalStockId === globalStockId && !pick.isCloseSplit) ??
    draft.stockPicks.find((pick) => pick.globalStockId === globalStockId) ??
    stockPicksFromItem(item).find((pick) => pick.globalStockId === globalStockId);
  if (!source) {
    showErrorNotification('No stock pick found to split.');
    return;
  }
  const key = itemRowKey(group, item);
  drafts[key] = {
    ...draft,
    stockPicks: [
      ...draft.stockPicks,
      {
        clientKey: createDemandPickClientKey(),
        globalStockId: source.globalStockId,
        shipmentName: source.shipmentName,
        locationName: source.locationName,
        quantity: 0,
        closeAction: 'condition',
        isCloseSplit: true,
        initialQuantity: undefined,
      },
    ],
  };
  markPackedDirty(key);
};

const onDeletePackedPick = (
  group: ProcurementDemandGroup,
  item: ProcurementDemandItem,
  clientKey: string,
) => {
  const draft = getDraft(group, item);
  const target = draft.stockPicks.find((pick) => pick.clientKey === clientKey);
  if (!target?.isCloseSplit) {
    showErrorNotification('Only added split rows can be removed.');
    return;
  }
  const key = itemRowKey(group, item);
  const nextPicks = restoreBaseQtyAfterRemovingSplit(
    draft.stockPicks.filter((pick) => pick.clientKey !== clientKey),
    target,
  );
  drafts[key] = {
    ...draft,
    stockPicks: nextPicks,
    deliveredQuantity: packagedQtyFromPicks(nextPicks),
  };
  markPackedDirty(key);
};

const onSavePackedPicks = async (
  group: ProcurementDemandGroup,
  item: ProcurementDemandItem,
) => {
  const draft = getDraft(group, item);
  await persistPackedPicks(group, item, draft.stockPicks, 'Close picks saved.');
};

const syncFulfillTabFromRoute = () => {
  if (!isFulfillMode.value) return;
  if (isFixedGroupPage.value) {
    fulfillProcurementStatus.value = 'packed';
    return;
  }
  const status = route.query.status;
  if (status === 'packed' || status === 'procuring') {
    fulfillProcurementStatus.value = status;
  }
};

watch(() => route.query.status, syncFulfillTabFromRoute, { immediate: true });
watch(isFixedGroupPage, syncFulfillTabFromRoute, { immediate: true });

const openGroupSource = (group: ProcurementDemandGroup) => {
  const tenantSlug = authStore.tenantSlug || '';
  if (group.document_type === 'shop_order') {
    void router.push({
      name: 'app-shop-order-detail-page',
      params: { tenantSlug, id: String(group.document_id) },
    });
    return;
  }
  void router.push({
    name: 'product-based-costing-file-details-page',
    params: { tenantSlug, id: String(group.document_id) },
  });
};
</script>

<style scoped lang="scss">
.treasury-table-wrap {
  flex: 1 1 0%;
  min-height: 0;
  overflow: auto;
}

.demand-buy-card-grid {
  display: flex;
  flex-direction: column;
  gap: 8px;
  width: 100%;
  padding: 8px 0 16px;
}

.demand-table {
  min-width: 820px;
}

.demand-table :deep(.demand-scroll-sentinel) {
  height: 1px;
  width: 100%;
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

.demand-group-chip {
  font-size: 10px;
  padding: 1px 6px;
  flex-shrink: 0;
}

.demand-groups-stack {
  width: 100%;
  min-width: 0;
  gap: 8px;
  padding: 4px 2px 8px;
}

.demand-group-block {
  min-width: 0;
}

.demand-group-lines {
  min-width: 0;
}

.demand-group-lines--under-hero {
  padding: 0 2px 2px;
}

.demand-group-lines--under-hero :deep(.demand-group-lines-table) {
  border: 1px solid #eef1f5;
  border-top: none;
  border-radius: 0 0 8px 8px;
  overflow: hidden;
  background: var(--tf-theme-surface, #ffffff);
}

.demand-group-lines:not(.demand-group-lines--under-hero) :deep(.demand-group-lines-table) {
  border: 1px solid #eef1f5;
  border-radius: 8px;
  overflow: hidden;
  background: var(--tf-theme-surface, #ffffff);
}

.demand-group-lines :deep(.demand-group-lines-table thead tr th) {
  position: static;
  top: auto;
}

.demand-group-hero {
  margin: 0 2px;
  border-radius: 8px;
  border: 1px solid var(--tf-theme-border, #e2e8f0);
  background: color-mix(
    in srgb,
    var(--tf-theme-primary-soft, #ecfdf5) 22%,
    var(--tf-theme-surface, #ffffff) 78%
  );
  box-shadow: 0 1px 1px color-mix(in srgb, var(--tf-theme-ink, #0f172a) 4%, transparent);
  overflow: hidden;
}

.demand-group-hero--queue {
  margin: 0;
  border-radius: var(--tf-radius-sm, 8px);
  background: var(--tf-theme-surface, #ffffff);
  border-color: var(--tf-theme-border, #e7e1d8);
  box-shadow: 0 1px 2px rgb(15 23 42 / 0.05);
  transition:
    border-color 0.15s ease,
    box-shadow 0.15s ease;
}

.demand-group-hero--queue:hover {
  border-color: color-mix(in srgb, var(--q-primary) 28%, var(--tf-theme-border, #e7e1d8));
  box-shadow: 0 2px 8px rgb(15 23 42 / 0.07);
}

.demand-group-hero--queue .demand-group-hero__head {
  padding: 12px 14px;
}

.demand-group-hero--queue .demand-group-hero__head:hover {
  background: var(--tf-neutral-canvas, #fbfaf7);
}

.demand-group-hero--expanded {
  border-bottom-left-radius: 0;
  border-bottom-right-radius: 0;
  border-bottom: none;
}

.demand-group-hero__head {
  padding: 8px 10px 6px;
  min-width: 0;
}

.demand-group-hero__head:hover {
  background: color-mix(in srgb, var(--tf-theme-primary-soft, #ecfdf5) 14%, transparent);
}

.demand-group-hero__caret {
  flex-shrink: 0;
}

.demand-group-hero__icon {
  width: 34px;
  height: 34px;
  border-radius: 6px;
  flex-shrink: 0;
  color: var(--tf-theme-primary, #059669);
  background: color-mix(in srgb, var(--tf-theme-surface, #fff) 75%, var(--tf-theme-primary-soft, #ecfdf5) 25%);
  border: 1px solid var(--tf-theme-border, #e2e8f0);
}

.demand-group-hero__icon--costing {
  color: color-mix(in srgb, var(--tf-theme-primary, #059669) 40%, #4f46e5 60%);
}

.demand-group-hero__title {
  font-size: 0.95rem;
  font-weight: 700;
  line-height: 1.25;
  color: var(--tf-theme-ink, #0f172a);
  letter-spacing: -0.01em;
}

.demand-group-hero__subtitle {
  margin-top: 2px;
  min-width: 0;
}

.demand-group-hero__type-pill {
  flex-shrink: 0;
  font-size: 10px;
  font-weight: 600;
  line-height: 1.2;
  padding: 3px 7px;
  border-radius: 6px;
  color: var(--tf-theme-primary, #059669);
  background: var(--tf-theme-primary-soft, #ecfdf5);
  border: 1px solid color-mix(in srgb, var(--tf-theme-primary, #059669) 18%, transparent);
}

.demand-group-hero__doc-ref {
  font-size: 12px;
  font-weight: 500;
  color: var(--tf-theme-muted, #64748b);
  min-width: 0;
}

.demand-group-hero__profile {
  font-size: 11px;
  font-weight: 600;
  color: var(--tf-neutral-ink, #334155);
  min-width: 0;
  max-width: 10rem;
}

.demand-group-hero__go {
  flex-shrink: 0;
  opacity: 0.75;
}

.demand-group-hero__meta {
  text-align: right;
}

.demand-group-hero__status {
  font-size: 11px;
  font-weight: 600;
  line-height: 1.35;
  min-height: 24px;
  padding: 4px 10px;
  border-radius: 6px !important;
}

.demand-group-hero__item-count {
  white-space: nowrap;
  font-size: 11px;
  line-height: 1.2;
}

body.body--dark .demand-group-hero {
  background: color-mix(in srgb, var(--tf-theme-surface, #1c1c1c) 90%, var(--tf-theme-primary-soft, #064e3b) 10%);
  box-shadow: none;
}

body.body--dark .demand-group-hero__head:hover {
  background: color-mix(in srgb, var(--tf-theme-primary-soft, #064e3b) 18%, transparent);
}

body.body--dark .demand-group-hero__title {
  color: var(--tf-theme-ink, #fafafa);
}

body.body--dark .demand-group-hero--queue {
  background: var(--tf-theme-surface, #1c1c1c);
}

body.body--dark .demand-group-hero--queue .demand-group-hero__head:hover {
  background: color-mix(in srgb, var(--tf-theme-surface, #1c1c1c) 88%, #fff 12%);
}

.demand-table :deep(.demand-image-col) {
  width: 1.2in;
  min-width: 1.2in;
  max-width: 1.2in;
}

.demand-table :deep(.demand-product-col) {
  min-width: 220px;
  max-width: 360px;
  white-space: normal !important;
  word-break: break-word;
  overflow-wrap: anywhere;
  line-height: 1.25;
}

.demand-table :deep(.demand-product-identity) {
  display: flex;
  flex-direction: column;
  gap: 6px;
  min-width: 0;
}

.demand-table :deep(.demand-product-name) {
  font-weight: 650;
  color: var(--tf-theme-ink, #0f172a);
  font-size: 13px;
  letter-spacing: -0.01em;
  line-height: 1.3;
}

.demand-table :deep(.demand-product-brand) {
  display: inline-flex;
  align-self: flex-start;
  padding: 1px 7px;
  border-radius: var(--tf-radius-sm, 8px);
  background: var(--tf-theme-primary-soft, #ecfdf5);
  color: var(--tf-theme-primary, #047857);
  font-size: 10px;
  font-weight: 650;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

body.body--dark .demand-table :deep(.demand-product-name) {
  color: #f4f4f5;
}

.demand-table :deep(.shipment-item-image-box) {
  width: 1in;
  height: 1in;
  max-width: 1in;
  max-height: 1in;
  flex-shrink: 0;
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
  max-width: 100%;
  max-height: 100%;
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
  width: 280px;
  min-width: 280px;
}

.demand-delivered-cell {
  gap: 2px;
}

.demand-split-btn {
  border-radius: 8px;
}

.demand-pick-list {
  line-height: 1.25;
  max-width: 280px;
  margin-inline: auto;
  text-align: left;
}

.demand-bulk-vendor-card {
  min-width: 320px;
  max-width: 420px;
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

.demand-desk-toolbar {
  padding: 8px 10px;
}

.demand-desk-toolbar__inner {
  gap: 10px;
}

.demand-desk-toolbar__head {
  gap: 12px;
}

.demand-desk-toolbar__status {
  padding-top: 2px;
}

.demand-desk-toolbar__controls {
  padding-top: 2px;
  border-top: 1px solid color-mix(in srgb, var(--tf-theme-border, #e7e1d8) 65%, transparent);
}

.demand-desk-toolbar__filters {
  max-width: 100%;
}

.demand-profile-toggle-wrap {
  display: block;
  max-width: 100%;
  overflow-x: auto;
  overflow-y: hidden;
  -webkit-overflow-scrolling: touch;
}

.demand-profile-toggle {
  flex-wrap: nowrap;
}

.demand-profile-toggle :deep(.q-btn) {
  max-width: 11rem;
}

.demand-profile-toggle :deep(.q-btn .q-btn__content) {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.demand-desk-toolbar__profile-actions {
  flex-shrink: 0;
}

.demand-profile-action-btn {
  flex-shrink: 0;
}

@media (max-width: 599px) {
  .demand-desk-toolbar__head {
    flex-wrap: wrap;
  }

  .demand-desk-toolbar__status {
    width: 100%;
  }

  .demand-desk-toolbar__filters {
    flex-wrap: wrap;
  }

  .demand-desk-toolbar__profile-actions {
    flex: 1 1 100%;
    flex-wrap: wrap;
  }

  .demand-profile-action-btn {
    flex: 1 1 auto;
  }
}

.demand-desk-intro {
  min-width: 0;
}

.demand-desk-intro__title {
  margin: 0;
  font-size: 1.05rem;
  font-weight: 700;
  line-height: 1.3;
  color: var(--tf-theme-ink, #0f172a);
  letter-spacing: -0.01em;
}

.demand-desk-intro__subtitle {
  margin: 4px 0 0;
  font-size: 12px;
  line-height: 1.4;
  color: var(--tf-theme-muted, #64748b);
  max-width: 36rem;
}

.demand-desk-body :deep(.treasury-table-wrap) {
  padding-left: 4px !important;
  padding-right: 4px !important;
}

.demand-filter-segment {
  display: inline-flex;
  padding: 3px;
  border-radius: var(--tf-radius-sm, 8px);
  border: 1px solid var(--tf-theme-border, #e7e1d8);
  background: var(--tf-neutral-canvas, #fbfaf7);
}

.demand-status-tabs {
  min-height: 30px;
}

.demand-desk-toolbar :deep(.q-btn:not(.q-btn--round)) {
  min-height: 28px;
  padding: 0 10px;
  font-size: 12px;
}

.demand-desk-body :deep(.tf-btn) {
  min-height: 26px !important;
  padding: 0 8px !important;
  font-size: 11px;
  width: auto;
}

.demand-status-tabs :deep(.q-btn) {
  border-radius: 6px;
}

.demand-packed-close-confirm-card {
  min-width: min(100vw - 32px, 420px);
}

.demand-packed-close-doc-list {
  max-height: 160px;
  overflow-y: auto;
}

</style>
