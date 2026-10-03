<template>
  <q-page
    class="shipment-items-v2-page column no-wrap"
    style="height: calc(100vh - var(--workspace-header-offset, 44px)); overflow: hidden"
  >
    <!-- Full Page Initial Skeleton Loader -->
    <div
      v-if="pageInitialLoading"
      class="column no-wrap full-height full-width overflow-hidden bg-white"
    >
      <!-- Top Sticky Header Skeleton -->
      <div class="shipment-items-top-section border-bottom q-px-lg q-py-md shrink-0 bg-white shadow-xs">
        <div class="row items-center justify-between q-gutter-y-sm">
          <!-- Left: Name Skeleton + Status Stepper Skeleton -->
          <div class="row items-center q-gutter-md">
            <q-skeleton type="text" width="180px" height="26px" class="rounded-borders" />
            <div class="row items-center q-gutter-x-xs">
              <q-skeleton type="rect" width="76px" height="26px" class="rounded-borders" />
              <q-skeleton type="rect" width="76px" height="26px" class="rounded-borders" />
              <q-skeleton type="rect" width="76px" height="26px" class="rounded-borders" />
            </div>
          </div>
          <!-- Right: Buttons Skeleton -->
          <div class="row items-center q-gutter-x-sm">
            <q-skeleton type="rect" width="88px" height="26px" class="rounded-borders" />
            <q-skeleton type="rect" width="76px" height="26px" class="rounded-borders" />
            <q-skeleton type="circle" size="26px" />
          </div>
        </div>
      </div>

      <!-- Table Skeleton Section -->
      <div class="col overflow-hidden bg-white">
        <div class="full-width q-px-md q-pt-md">
          <!-- Table Header Skeleton -->
          <div class="row items-center q-pb-sm border-bottom q-gutter-x-md text-grey-4">
            <q-skeleton type="QCheckbox" size="xs" />
            <q-skeleton type="text" width="20px" height="12px" />
            <q-skeleton type="text" width="60px" height="12px" />
            <q-skeleton type="text" width="140px" height="12px" />
            <q-skeleton type="text" width="80px" height="12px" />
            <q-skeleton type="text" width="60px" height="12px" />
            <q-skeleton type="text" width="60px" height="12px" />
            <q-skeleton type="text" width="50px" height="12px" />
            <q-skeleton type="text" width="60px" height="12px" />
            <q-skeleton type="text" width="60px" height="12px" />
          </div>

          <!-- Table Rows Skeleton -->
          <div
            v-for="n in 9"
            :key="`init-skel-${n}`"
            class="row items-center q-py-sm border-bottom q-gutter-x-md"
          >
            <q-skeleton type="QCheckbox" size="xs" />
            <q-skeleton type="text" width="16px" height="12px" />
            <q-skeleton type="rect" width="1in" height="1in" class="rounded-borders" />
            <div class="col" style="max-width: 180px">
              <q-skeleton type="text" width="85%" height="15px" class="q-mb-2xs" />
              <q-skeleton type="text" width="50%" height="11px" />
            </div>
            <div style="width: 80px">
              <q-skeleton type="text" width="65px" height="12px" class="q-mb-2xs" />
              <q-skeleton type="text" width="45px" height="10px" />
            </div>
            <q-skeleton type="text" width="50px" height="14px" class="q-mx-auto" />
            <q-skeleton type="text" width="50px" height="14px" class="q-mx-auto" />
            <q-skeleton type="text" width="40px" height="14px" class="q-mx-auto" />
            <q-skeleton type="text" width="50px" height="14px" class="q-mx-auto" />
            <q-skeleton type="text" width="50px" height="14px" class="q-mx-auto" />
          </div>
        </div>
      </div>

      <!-- Bottom Sheet Bar Skeleton -->
      <div class="row items-center justify-between q-px-md q-py-xs bg-grey-2 border-top shrink-0" style="height: 38px">
        <div class="row items-center q-gutter-x-xs">
          <q-skeleton type="rect" width="80px" height="24px" class="rounded-borders" />
          <q-skeleton type="rect" width="110px" height="24px" class="rounded-borders" />
          <q-skeleton type="rect" width="100px" height="24px" class="rounded-borders" />
          <q-skeleton type="circle" size="20px" />
        </div>
        <q-skeleton type="rect" width="160px" height="10px" class="rounded-borders" />
      </div>
    </div>

    <!-- Live Content (When Loaded) -->
    <template v-else>
      <!-- Top Sticky Section: Shipment Name, Status Workflow & Actions -->
      <div class="shipment-items-top-section border-bottom q-px-lg q-py-md shrink-0 bg-white">
      <div class="row items-center justify-between q-gutter-y-sm wrap">
        <!-- Left: Name + Status Workflow -->
        <div class="col-grow row items-center q-gutter-md wrap" style="min-width: 0">
          <div class="shipment-name-container">
            <template v-if="isEditingName">
              <input
                ref="nameInputRef"
                v-model="nameEditValue"
                type="text"
                class="shipment-name-input"
                maxlength="120"
                placeholder="Shipment Name..."
                :disabled="savingName"
                @keydown.enter.prevent="saveNameInPlace"
                @keydown.esc.prevent="cancelNameEdit"
                @blur="saveNameInPlace"
              />
            </template>
            <template v-else>
              <button
                type="button"
                class="shipment-name-display-btn"
                @click="startNameEdit"
              >
                <span class="shipment-name-text ellipsis">
                  {{ shipmentStore.currentShipment?.name || 'Untitled Shipment' }}
                </span>
                <q-icon name="ph ph-pencil-simple" size="13px" class="shipment-name-icon" />
                <q-tooltip>Click to edit name</q-tooltip>
              </button>
            </template>
          </div>
          <ShipmentStatusWorkflowBar
            class="shipment-header-workflow"
            :status="shipmentStore.currentShipment?.status ?? 'draft'"
            :updating="updatingStatus"
            :target-status="targetUpdatingStatus"
            @update-status="changeStatus"
          />
          <q-badge
            v-if="isCostsLocked"
            color="grey-3"
            text-color="grey-9"
            outline
            label="Costs locked"
          />
        </div>

        <!-- Right: Header Buttons & Settings -->
        <div class="row items-center q-gutter-x-sm no-wrap">
          <!-- Selection Actions: Exactly 1 Item Selected -> Edit & Delete -->
          <template v-if="selectedItemIds.length === 1 && canEditLineStructure">
            <q-btn
              color="primary"
              icon="ph ph-pencil-simple"
              label="Edit"
              unelevated
              dense
              no-caps
              size="sm"
              class="q-px-sm rounded-sq-btn text-weight-bold"
              style="border-radius: 8px"
              @click="editSingleSelectedItem"
            >
              <q-tooltip>Edit selected item</q-tooltip>
            </q-btn>
            <q-btn
              color="negative"
              icon="ph ph-trash"
              label="Delete"
              outline
              dense
              no-caps
              size="sm"
              class="q-px-sm rounded-sq-btn text-weight-bold"
              style="border-radius: 8px"
              @click="deleteSingleSelectedItem"
            >
              <q-tooltip>Delete selected item</q-tooltip>
            </q-btn>
          </template>

          <!-- Selection Actions: Multiple Items Selected -> Bulk Delete -->
          <template v-else-if="selectedItemIds.length > 1 && canEditLineStructure">
            <q-btn
              color="negative"
              icon="ph ph-trash"
              :label="`Bulk Delete (${selectedItemIds.length})`"
              unelevated
              dense
              no-caps
              size="sm"
              class="q-px-sm rounded-sq-btn text-weight-bold"
              style="border-radius: 8px"
              @click="bulkDeleteSelectedItems"
            >
              <q-tooltip>Delete {{ selectedItemIds.length }} selected items</q-tooltip>
            </q-btn>
          </template>

          <q-btn
            outline
            dense
            no-caps
            color="primary"
            class="rounded-sq-btn text-weight-bold q-px-sm"
            icon="ph ph-clipboard-text"
            label="Bulk Paste"
            size="sm"
            :disable="!canEditLineCostFields && !canEditLineStructure"
            @click="openBulkPasteDialog('purchase_price')"
          >
            <q-tooltip>Paste barcode, product code, and one column from Excel</q-tooltip>
          </q-btn>

          <!-- Add Items Button (Disabled on 'All Items' tab) -->
          <q-btn
            outline
            dense
            no-caps
            color="primary"
            class="rounded-sq-btn text-weight-bold q-px-sm"
            icon="ph ph-plus"
            label="Add Items"
            size="sm"
            :disable="activeSheetId === 'sheet_all' || !canEditLineStructure"
            @click="triggerAddItems"
          >
            <q-tooltip>
              {{ activeSheetId === 'sheet_all' ? 'Select a specific section tab below to add items' : 'Add Items to current Section' }}
            </q-tooltip>
          </q-btn>

          <q-btn
            v-if="activeSheetId !== 'sheet_all'"
            flat
            round
            dense
            color="grey-8"
            icon="ph ph-file-xls"
            size="sm"
            @click="downloadActiveSheetExcel"
          >
            <q-tooltip>Download Excel for the current tab</q-tooltip>
          </q-btn>

          <q-btn
            v-if="showReceivePostStock"
            color="primary"
            unelevated
            dense
            no-caps
            size="sm"
            class="q-px-sm rounded-sq-btn text-weight-bold"
            style="border-radius: 8px"
            icon="ph ph-package"
            label="Receive & post stock"
            @click="startReceiveFlow()"
          >
            <q-tooltip>Review splits and add sellable qty to the warehouse</q-tooltip>
          </q-btn>

          <!-- Lock costs (after receive, before books freeze) -->
          <q-btn
            v-if="isStockPosted && !isCostsLocked"
            outline
            dense
            no-caps
            color="primary"
            class="rounded-sq-btn text-weight-bold q-px-sm"
            icon="ph ph-lock-key"
            label="Lock costs"
            size="sm"
            @click="confirmLockShipmentCosts"
          >
            <q-tooltip>Freeze cost entries and landed costs for books</q-tooltip>
          </q-btn>

          <q-btn
            :outline="!settingsDrawerOpen"
            :unelevated="settingsDrawerOpen"
            round
            color="primary"
            class="shipment-settings-trigger"
            icon="ph ph-gear-six"
            size="md"
            aria-label="Settings"
            @click="openSettingsDrawer('details')"
          >
            <q-tooltip>Settings</q-tooltip>
          </q-btn>
        </div>
      </div>
    </div>

    <!-- Middle Scrollable Section: product cards -->
    <div
      ref="tableScrollContainerRef"
      class="shipment-items-middle-section col overflow-auto q-pa-md hide-native-scrollbar"
      style="overflow-x: auto; overflow-y: auto"
      @scroll="onTableScroll"
    >
      <div v-if="shipmentStore.loading" class="column q-gutter-sm">
        <q-skeleton v-for="n in 5" :key="`skel-${n}`" type="rect" height="120px" class="rounded-borders" />
      </div>
      <template v-else-if="displayedItems.length > 0">
        <div class="column q-gutter-sm">
          <template v-for="(item, index) in displayedItems" :key="item.id">
            <div
              v-if="isFirstItemOfSection(item, index)"
              class="section-break-card row items-center justify-between q-px-sm q-py-xs"
            >
              <div class="row items-center q-gutter-x-sm">
                <q-icon name="ph ph-folder-open" size="16px" color="primary" />
                <span class="text-subtitle2 text-weight-bolder">{{ getSectionTitle(item.sectionId) }}</span>
                <span class="text-caption text-grey-6 font-mono">• {{ getSectionVendor(item.sectionId) }}</span>
                <q-badge color="grey-3" text-color="grey-8" class="text-weight-bold text-xxs">
                  {{ getSectionItemCount(item.sectionId) }} item<span v-if="getSectionItemCount(item.sectionId) > 1">s</span>
                </q-badge>
              </div>
              <div class="row items-center q-gutter-x-md text-caption text-grey-7 font-mono">
                <span>Units: <b>{{ getSectionTotalQty(item.sectionId) }}</b></span>
                <span>Total: <b>{{ currentPurchaseCurrencySymbol }}{{ getSectionTotalPurchase(item.sectionId).toFixed(2) }}</b></span>
              </div>
            </div>
            <ShipmentLineItemCard
              :item="item"
              :extra-outcomes="extraOutcomesForItem(item.id)"
              :currency-symbol="currentPurchaseCurrencySymbol"
              :can-edit-costs="canEditLineCostFields"
              :can-edit-line-cost-fields="canEditLineCostFields"
              :can-edit-structure="canEditLineStructure"
              :is-received="isShipmentReceived"
              :can-add-split="canAddSplit"
              :can-edit-splits="canEditSplits"
              :can-show-vendor-discount="canShowVendorDiscountForItem(item.id)"
              :show-batch="true"
              :batch-summary="batchSummaryForItem(item)"
              :adding-extra="addingExtraItemId === item.id"
              :get-draft="(field) => getCellDraftValue(item, field)"
              @toggle-select="toggleRowSelection"
              @sl-change="onSlInputChange"
              @preview-image="openImagePreview"
              @cell-input="onCellDirectInput"
              @cell-blur="onCellDirectBlur"
              @open-batch="openBatchCodeDialog"
              @add-extra="addExtraOutcome"
              @open-vendor-discount="openVendorDiscount"
              @update-extra="updateExtraOutcome"
              @delete-extra="deleteExtraOutcome"
            />
          </template>
        </div>
      </template>
      <div v-else class="empty-placeholder-wrapper column items-center justify-center q-py-xl">
        <div class="text-subtitle1 text-weight-bolder text-slate-800 q-mb-2xs">
          No line items in this {{ activeSheetId === 'sheet_all' ? 'shipment' : 'section' }}
        </div>
        <div class="text-caption text-slate-500 q-mb-md" style="max-width: 440px; line-height: 1.4">
          {{ activeSheetId === 'sheet_all' ? 'Select a section tab from the bottom sheet bar or add items to begin.' : 'Add line items to track products, quantities, purchase costs, and weights for this section.' }}
        </div>
        <q-btn
          color="primary"
          icon="ph ph-plus"
          label="Add First Item"
          unelevated
          no-caps
          class="rounded-sq-btn text-weight-bold q-px-md"
          style="border-radius: 8px"
          :disable="activeSheetId === 'sheet_all' || !canEditLineStructure"
          @click="triggerAddItems"
        />
      </div>
    </div>

    <!-- Bottom Sticky Section: Excel-style Bar with Sheet Tabs & Right Horizontal Scrollbar -->
    <ShipmentExcelBottomBar
      ref="excelBottomBarRef"
      :sheets="sheets"
      :active-sheet-id="activeSheetId"
      :scroll-thumb-width="scrollThumbWidth"
      :scroll-thumb-left="scrollThumbLeft"
      @update:active-sheet-id="onSheetTabChange"
      @add-section="openAddSectionDialog"
      @view-section="openViewSectionDialog"
      @edit-section="openEditSectionDialog"
      @remove-sheet="removeSheet"
      @download-sheet="downloadSheetExcel"
      @scroll-step="scrollTableByStep"
      @track-click="onTrackClick"
      @thumb-drag-start="startThumbDrag"
    />

    <ShipmentSettingsDrawer
      v-model="settingsDrawerOpen"
      :shipment-id="shipmentId"
      :calculations="calculations"
      :cargo-options="cargoOptions"
      :vendor-options="vendorOptions"
      :initial-tab="settingsDrawerTab"
      :progress-flow-options="progressFlowOptions"
      :progress-tag-options="progressTagOptions"
      :progress-flow-id="shipmentStore.currentShipment?.progress_flow_id ?? null"
      :progress-tag-id="shipmentStore.currentShipment?.progress_tag_id ?? null"
      :progress-updating="progressUpdating"
      :progress-target-id="progressTargetId"
      @update-flow="changeProgressFlow"
      @update-progress="changeProgress"
    />

    <!-- Add / Edit Section Sheet Dialog -->
    <ShipmentSectionSheetDialog
      v-model="showAddSectionDialog"
      :is-editing="isEditingSection"
      :initial-data="editingSectionData"
      @save="onSaveSectionSheet"
    />

    <!-- View Section Details Modal -->
    <ShipmentSectionViewDialog
      v-model="showViewSectionDialog"
      :section-data="viewingSectionData"
      @edit="switchToEditFromView"
    />

    <!-- Bulk Paste Dialog -->
    <q-dialog v-model="showBulkPasteDialog" persistent>
      <q-card style="width: 640px; max-width: 95vw; border-radius: 12px">
        <q-card-section class="row items-center justify-between q-pb-none">
          <div class="row items-center q-gutter-x-sm">
            <q-avatar color="primary" text-color="white" icon="ph ph-clipboard-text" size="32px" />
            <div>
              <div class="text-subtitle1 text-weight-bold text-grey-9">Bulk Paste {{ bulkPasteFieldLabel }}</div>
              <div class="text-caption text-grey-6">
                Click a cell, then paste. Data fills from that cell, like Excel.
              </div>
            </div>
          </div>
          <q-btn v-close-popup icon="ph ph-x" flat round dense color="grey-6" />
        </q-card-section>

        <q-card-section class="q-pt-sm q-pb-none">
          <q-select
            v-model="bulkPasteField"
            :options="bulkPasteFieldOptions"
            outlined
            dense
            emit-value
            map-options
            label="Column to update"
            class="full-width"
          />
        </q-card-section>

        <q-card-section class="q-py-md">
          <div class="bulk-paste-grid-wrap" @paste.capture="onBulkPasteGridPaste">
            <table class="bulk-paste-grid">
              <thead>
                <tr>
                  <th>Barcode</th>
                  <th>Product code</th>
                  <th>{{ bulkPasteFieldLabel }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(row, rowIdx) in bulkPasteRows" :key="row.rowKey">
                  <td>
                    <input
                      v-model="row.barcode"
                      class="bulk-paste-cell"
                      :data-row="rowIdx"
                      data-col="0"
                      @focus="onBulkPasteCellFocus(rowIdx, 0)"
                    />
                  </td>
                  <td>
                    <input
                      v-model="row.product_code"
                      class="bulk-paste-cell"
                      :data-row="rowIdx"
                      data-col="1"
                      @focus="onBulkPasteCellFocus(rowIdx, 1)"
                    />
                  </td>
                  <td>
                    <input
                      v-model="row.value"
                      class="bulk-paste-cell bulk-paste-cell--value"
                      :data-row="rowIdx"
                      data-col="2"
                      @focus="onBulkPasteCellFocus(rowIdx, 2)"
                    />
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </q-card-section>

        <q-separator />

        <q-card-actions align="right" class="q-pa-md bg-grey-1">
          <q-btn v-close-popup flat label="Cancel" color="grey-7" no-caps :disable="bulkPasteSaving" />
          <q-btn
            unelevated
            color="primary"
            icon="ph ph-check"
            label="Apply Paste"
            no-caps
            class="rounded-borders q-px-md text-weight-bold"
            :loading="bulkPasteSaving"
            :disable="bulkPasteSaving"
            @click="applyBulkPaste"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Image Preview Dialog -->
    <q-dialog v-model="showImagePreviewDialog">
      <q-card style="max-width: 90vw; max-height: 90vh; background: transparent; box-shadow: none" class="overflow-hidden">
        <div class="relative-position">
          <img
            v-if="previewImageUrl"
            :src="previewImageUrl"
            style="max-width: 85vw; max-height: 85vh; object-fit: contain; border-radius: 12px; display: block"
            alt="Product Preview"
          />
          <q-btn
            v-close-popup
            icon="ph ph-x"
            flat
            round
            dense
            color="white"
            class="absolute-top-right q-ma-sm"
            style="background: rgba(0, 0, 0, 0.6)"
          />
        </div>
      </q-card>
    </q-dialog>

    <ShipmentVendorDiscountDialog
      ref="vendorDiscountDialogRef"
      v-model="vendorDiscountDialogOpen"
      :shipment-id="shipmentId"
      :line-label="vendorDiscountLineLabel"
      :currency-symbol="currentPurchaseCurrencySymbol"
      :extras="vendorDiscountExtras"
      :submitting="vendorDiscountSubmitting"
      @submit="onVendorDiscountSubmit"
    />

    <ShipmentLineBatchCodeDialog
      v-model="batchCodeDialogOpen"
      :product-name="batchCodeDialogProductName"
      :rows="batchCodeDialogRows"
      :can-add="batchCodeDialogCanAdd"
      :adding="batchCodeDialogAdding"
      :toggling-item-id="batchCodeDialogTogglingId"
      @add="onAddBatchFromDialog"
      @toggle-arrived="onToggleBatchArrivedFromDialog"
    />
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, computed, watch, onMounted, onUnmounted, nextTick } from 'vue';
import { useQueryClient } from '@tanstack/vue-query';
import { useRoute } from 'vue-router';
import { useQuasar } from 'quasar';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';
import { useVendorStore } from 'src/modules/vendor/stores/vendorStore';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import { useCargoCompaniesQuery } from '../composables/useProcurementStockQuery';
import AddShipmentItemsDrawer from '../components/AddShipmentItemsDrawer.vue';
import ShipmentLineItemCard from '../components/ShipmentLineItemCard.vue';
import ShipmentExcelBottomBar, { type SheetTabItem } from '../components/ShipmentExcelBottomBar.vue';
import ShipmentSettingsDrawer from '../components/ShipmentSettingsDrawer.vue';
import ShipmentSectionSheetDialog from '../components/ShipmentSectionSheetDialog.vue';
import ShipmentSectionViewDialog from '../components/ShipmentSectionViewDialog.vue';
import type { SectionFormData, SectionViewData } from '../types/shipmentSection';
import ShipmentStatusWorkflowBar from '../components/ShipmentStatusWorkflowBar.vue';
import { useInboundShipmentCalculations } from '../composables/useInboundShipmentCalculations';
import { useInboundShipmentActions } from '../composables/useInboundShipmentActions';
import {
  calculateLineLandedCostBdt,
  costingShipmentFromEntries,
} from 'src/shared/shipment-engine';
import {
  globalShipmentRepository,
  type GlobalShipmentItem,
  type ShipmentItemOutcome,
} from '../repositories/globalShipmentRepository';
import { isShipmentCostsLocked } from '../utils/costEntriesCosting';
import { useBatchCodeItemsByShipmentQuery } from '../composables/useBatchCodeQueries';
import { useCreateBatchCodeListMutation } from '../composables/useBatchCodeMutations';
import { batchCodeRepository, type BatchCodeItem } from '../repositories/batchCodeRepository';
import { procurementStockQueryKeys } from '../shared/queryKeys/procurementStockQueryKeys';
import { toIsoDate } from '../utils/batchCodeExpiry';
import ShipmentLineBatchCodeDialog from '../components/ShipmentLineBatchCodeDialog.vue';
import ShipmentVendorDiscountDialog from '../components/ShipmentVendorDiscountDialog.vue';
import {
  batchMatchTableRows,
  buildBatchSummaryMapForLines,
  matchBatchItemsForShipmentLine,
  type BatchCodeLineSummary,
  type BatchCodeMatchTableRow,
} from '../utils/batchCodeShipmentMatch';

const $q = useQuasar();
const route = useRoute();
const shipmentStore = useGlobalShipmentStore();
const shipmentId = Number(route.params.id);

const activeTab = ref<'lines' | 'balance' | 'cost' | 'receive'>('lines');
const pageInitialLoading = computed(
  () => shipmentStore.loading && (!shipmentStore.currentShipment || shipmentStore.currentShipment.id !== shipmentId),
);
const calculations = useInboundShipmentCalculations();
const actions = useInboundShipmentActions({
  shipmentId,
  activeTab,
  calculations,
});

const {
  currentPurchaseCurrencySymbol,
  isStockPosted,
  isCostsLocked,
  canEditLineStructure,
  canEditLineCostFields,
} = calculations;

const isShipmentReceived = computed(
  () => shipmentStore.currentShipment?.status === 'received' || isStockPosted.value,
);

const canAddSplit = computed(() => shipmentStore.currentShipment?.status === 'in_transit');

const canEditSplits = computed(
  () => !isShipmentReceived.value && canEditLineCostFields.value,
);

const {
  openEditItem,
  confirmDeleteItem,
  changeStatus,
  changeProgress,
  changeProgressFlow,
  updatingStatus,
  targetUpdatingStatus,
  progressTargetId,
  progressFlowOptions,
  progressTagOptions,
  progressUpdating,
  confirmLockShipmentCosts,
  downloadExcel,
  startReceiveFlow,
} = actions;

// In-Place Shipment Name Edit State
const isEditingName = ref(false);
const nameEditValue = ref('');
const savingName = ref(false);
const nameInputRef = ref<HTMLInputElement | null>(null);

const startNameEdit = () => {
  nameEditValue.value = shipmentStore.currentShipment?.name || '';
  isEditingName.value = true;
  void nextTick(() => {
    nameInputRef.value?.focus();
    nameInputRef.value?.select();
  });
};

const cancelNameEdit = () => {
  isEditingName.value = false;
  nameEditValue.value = '';
};

const saveNameInPlace = async () => {
  if (!isEditingName.value || savingName.value) return;
  const current = shipmentStore.currentShipment;
  if (!current?.id) {
    isEditingName.value = false;
    return;
  }

  const trimmed = nameEditValue.value.trim();
  if (!trimmed) {
    isEditingName.value = false;
    return;
  }

  if (trimmed === current.name) {
    isEditingName.value = false;
    return;
  }

  savingName.value = true;
  try {
    await shipmentStore.updateShipment(current.id, { name: trimmed });
    $q.notify({
      type: 'positive',
      message: 'Shipment name updated',
      position: 'bottom',
      timeout: 1000,
    });
  } catch (err: unknown) {
    $q.notify({
      type: 'negative',
      message: (err as Error)?.message || 'Failed to update shipment name',
      position: 'bottom',
    });
  } finally {
    savingName.value = false;
    isEditingName.value = false;
  }
};

const settingsDrawerOpen = ref(false);
const settingsDrawerTab = ref('details');

const openSettingsDrawer = (tab = 'details') => {
  if (settingsDrawerOpen.value && settingsDrawerTab.value === tab) {
    settingsDrawerOpen.value = false;
    return;
  }
  settingsDrawerTab.value = tab;
  settingsDrawerOpen.value = true;
};

const showAddSectionDialog = ref(false);
const showViewSectionDialog = ref(false);
const showImagePreviewDialog = ref(false);
const previewImageUrl = ref<string | null>(null);
const isEditingSection = ref(false);
const editingSectionData = ref<SectionFormData | null>(null);
const viewingSectionData = ref<SectionViewData | null>(null);
const excelBottomBarRef = ref<InstanceType<typeof ShipmentExcelBottomBar> | null>(null);

// Bulk Paste Dialog State
const showBulkPasteDialog = ref(false);
const bulkPasteField = ref<'purchase_price' | 'ordered_quantity' | 'product_weight' | 'package_weight'>('purchase_price');
const bulkPasteStartItem = ref<any>(null);
const bulkPasteSaving = ref(false);
type BulkPasteGridRow = {
  rowKey: string;
  itemId: number | null;
  barcode: string;
  product_code: string;
  value: string;
};
const bulkPasteRows = ref<BulkPasteGridRow[]>([]);
const bulkPasteFocus = ref({ row: 0, col: 0 });
const bulkPasteCols = ['barcode', 'product_code', 'value'] as const;

const bulkPasteFieldLabel = computed(() => {
  switch (bulkPasteField.value) {
    case 'purchase_price':
      return 'Price';
    case 'ordered_quantity':
      return 'Quantity';
    case 'product_weight':
      return 'Product Weight';
    case 'package_weight':
      return 'Package Weight';
    default:
      return 'Values';
  }
});

const bulkPasteFieldOptions = computed(() => {
  const options: { label: string; value: typeof bulkPasteField.value }[] = [];
  if (canEditLineCostFields.value) {
    options.push(
      { label: 'Price', value: 'purchase_price' },
      { label: 'Product Weight', value: 'product_weight' },
      { label: 'Package Weight', value: 'package_weight' },
    );
  }
  if (canEditLineStructure.value) {
    options.push({ label: 'Quantity', value: 'ordered_quantity' });
  }
  return options;
});

const emptyBulkPasteRow = (index: number): BulkPasteGridRow => ({
  rowKey: `empty-${index}`,
  itemId: null,
  barcode: '',
  product_code: '',
  value: '',
});

const looksLikePasteHeader = (cols: string[]): boolean => {
  const joined = cols.join(' ').toLowerCase();
  return (
    joined.includes('barcode') ||
    joined.includes('product code') ||
    joined.includes('product_code') ||
    joined.includes('actualweight') ||
    joined.includes('actual weight')
  );
};

const openBulkPasteDialog = (
  field: 'purchase_price' | 'ordered_quantity' | 'product_weight' | 'package_weight' = 'purchase_price',
  startItem?: any,
) => {
  const allowed = bulkPasteFieldOptions.value.map((opt) => opt.value);
  if (allowed.length === 0) return;
  const nextField = allowed.includes(field) ? field : allowed[0];
  bulkPasteField.value = nextField;
  bulkPasteStartItem.value = startItem || null;
  bulkPasteSaving.value = false;
  bulkPasteRows.value = Array.from({ length: 16 }, (_, i) => emptyBulkPasteRow(i));
  bulkPasteFocus.value = { row: 0, col: 0 };
  showBulkPasteDialog.value = true;
  void nextTick(() => {
    const el = document.querySelector(
      `.bulk-paste-cell[data-row="0"][data-col="0"]`,
    ) as HTMLInputElement | null;
    el?.focus();
  });
};

const onBulkPasteCellFocus = (row: number, col: number) => {
  bulkPasteFocus.value = { row, col };
};

const onBulkPasteGridPaste = (event: ClipboardEvent) => {
  const text = event.clipboardData?.getData('text/plain');
  if (!text) return;
  event.preventDefault();

  let pasted = text
    .split(/\r?\n/)
    .map((line) => line.split('\t').map((cell) => cell.trim()))
    .filter((cols) => cols.some((cell) => cell !== ''));
  if (pasted.length === 0) return;
  if (pasted[0] && looksLikePasteHeader(pasted[0])) {
    pasted = pasted.slice(1);
  }
  if (pasted.length === 0) return;

  const startRow = bulkPasteFocus.value.row;
  const startCol = bulkPasteFocus.value.col;
  const rows = [...bulkPasteRows.value];

  pasted.forEach((cols, rOffset) => {
    const rowIdx = startRow + rOffset;
    while (rowIdx >= rows.length) {
      rows.push(emptyBulkPasteRow(rows.length));
    }
    const row = rows[rowIdx];
    if (!row) return;
    cols.forEach((cell, cOffset) => {
      const colIdx = startCol + cOffset;
      const key = bulkPasteCols[colIdx];
      if (!key) return;
      row[key] = cell;
    });
  });

  bulkPasteRows.value = rows;
};

const applyBulkPaste = async () => {
  const items = displayedItems.value;
  const field = bulkPasteField.value;
  const updates: Array<{ id: number; payload: Record<string, any> }> = [];
  let count = 0;
  let skipped = 0;
  const usedIds = new Set<number>();

  const normalizeKey = (value: string | null | undefined) =>
    (value || '').trim().replace(/^['`]+/, '').replace(/\s+/g, '').toLowerCase();

  const normalizePasteNumber = (raw: string): number | null => {
    if (!raw.trim()) return null;
    const val = Number(raw.replace(/[^0-9.-]/g, ''));
    if (Number.isNaN(val)) return null;
    if (field === 'purchase_price') return Number(val.toFixed(2));
    if (field === 'ordered_quantity') return Math.max(1, Math.round(val));
    if (field === 'product_weight' || field === 'package_weight') return Number(val.toFixed(3));
    return val;
  };

  const itemCodes = (it: (typeof items)[number]) => {
    const raw = it.rawItem as { barcode?: string | null; product_code?: string | null } | undefined;
    return {
      barcode: normalizeKey(String(raw?.barcode ?? it.barcode ?? '')),
      product_code: normalizeKey(String(raw?.product_code ?? '')),
    };
  };

  const findMatches = (rowBarcode: string, rowCode: string) => {
    return items.filter((it) => {
      const codes = itemCodes(it);
      if (rowBarcode && rowCode) {
        return codes.barcode === rowBarcode && codes.product_code === rowCode;
      }
      if (rowBarcode) return codes.barcode === rowBarcode;
      if (rowCode) return codes.product_code === rowCode;
      return false;
    });
  };

  const pushUpdate = (targetItem: (typeof items)[number], normalized: number) => {
    if (usedIds.has(targetItem.id)) return false;
    usedIds.add(targetItem.id);
    if (field === 'purchase_price') targetItem.price = normalized;
    if (field === 'ordered_quantity') targetItem.quantity = normalized;
    onCellDirectInput(targetItem, field, normalized);
    if (targetItem.rawItem) {
      targetItem.rawItem[field] = normalized;
    }
    const itemId = targetItem.rawItem?.id || targetItem.id;
    if (itemId) {
      updates.push({
        id: itemId,
        payload: { [field]: normalized },
      });
    }
    count++;
    return true;
  };

  const dataRows = bulkPasteRows.value.filter((row) => normalizePasteNumber(row.value) !== null);
  const pasteHasKeys = dataRows.some(
    (row) => normalizeKey(row.barcode) || normalizeKey(row.product_code),
  );

  if (pasteHasKeys) {
    for (const row of dataRows) {
      const normalized = normalizePasteNumber(row.value);
      if (normalized === null) continue;
      const barcode = normalizeKey(row.barcode);
      const productCode = normalizeKey(row.product_code);
      if (!barcode && !productCode) {
        skipped++;
        continue;
      }
      const hits = findMatches(barcode, productCode).filter((it) => !usedIds.has(it.id));
      if (hits.length !== 1) {
        skipped++;
        continue;
      }
      pushUpdate(hits[0]!, normalized);
    }
  } else {
    let startIndex = 0;
    if (bulkPasteStartItem.value) {
      const foundIdx = items.findIndex((it) => it.id === bulkPasteStartItem.value.id);
      if (foundIdx !== -1) startIndex = foundIdx;
    }
    dataRows.forEach((row, i) => {
      const normalized = normalizePasteNumber(row.value);
      const targetItem = items[startIndex + i];
      if (!targetItem || normalized === null) {
        skipped++;
        return;
      }
      if (!pushUpdate(targetItem, normalized)) skipped++;
    });
  }

  try {
    if (updates.length > 0 && shipmentId && !isNaN(shipmentId)) {
      bulkPasteSaving.value = true;
      try {
        await shipmentStore.updateShipmentItemsBulk(shipmentId, updates);
        $q.notify({
          message: `Successfully pasted and saved ${count} ${bulkPasteFieldLabel.value} value(s)${
            skipped ? ` (${skipped} unmatched)` : ''
          }`,
          color: 'positive',
          icon: 'ph ph-check-circle',
          position: 'bottom',
          timeout: 1500,
        });
      } catch (err: unknown) {
        console.error('Failed to bulk save pasted values to server:', err);
        $q.notify({
          message: `Pasted ${count} value(s) locally. Failed to save to server: ${(err as Error)?.message || 'error'}`,
          color: 'warning',
          icon: 'ph ph-warning-circle',
          position: 'bottom',
          timeout: 2500,
        });
      } finally {
        bulkPasteSaving.value = false;
      }
    } else if (skipped > 0) {
      $q.notify({
        message: `No rows updated (${skipped} unmatched)`,
        color: 'warning',
        icon: 'ph ph-warning-circle',
        position: 'bottom',
        timeout: 2000,
      });
    } else {
      $q.notify({
        message: `Pasted ${count} value(s) into ${bulkPasteFieldLabel.value}`,
        color: 'positive',
        icon: 'ph ph-clipboard-text',
        position: 'bottom',
        timeout: 1500,
      });
    }
  } finally {
    bulkPasteSaving.value = false;
    showBulkPasteDialog.value = false;
  }
};

const triggerAddItems = () => {
  const activeSection = sheets.value.find((s) => s.id === activeSheetId.value);
  const activeSectionDbId = activeSection?.dbId ?? null;

  if (shipmentId && !isNaN(shipmentId)) {
    $q.dialog({
      component: AddShipmentItemsDrawer,
      componentProps: {
        shipmentId,
        initialSectionId: activeSectionDbId,
      },
    });
  }
};

const authStore = useAuthStore();
const vendorStore = useVendorStore();
const currentTenantId = computed(
  () => authStore.selectedTenant?.parent_id ?? authStore.tenantId,
);
const { data: cargoData } = useCargoCompaniesQuery(currentTenantId);

const cargoCompanies = computed(() => cargoData.value ?? []);

const cargoOptions = computed(() =>
  cargoCompanies.value.map((c) => ({
    label: `${c.name} (${c.code})`,
    value: c.id,
  })),
);

const vendorOptions = computed(() =>
  vendorStore.items.map((v) => ({
    label: v.is_default ? `${v.name} (default)` : v.name,
    value: v.id,
  })),
);

const selectedItemIds = ref<number[]>([]);

const toggleRowSelection = (id: number, selected: boolean) => {
  if (selected) {
    if (!selectedItemIds.value.includes(id)) selectedItemIds.value.push(id);
  } else {
    selectedItemIds.value = selectedItemIds.value.filter((i) => i !== id);
  }
};

// Section / Vendor lookup helpers
const getSectionTitle = (sectionId?: number | null) => {
  if (!sectionId) return 'Main Order';
  const found = shipmentStore.currentShipmentSections.find((s) => s.id === sectionId);
  return found?.title || `Section #${sectionId}`;
};

const getSectionVendor = (sectionId?: number | null) => {
  if (!sectionId) {
    const primaryVendorId = shipmentStore.currentShipment?.vendor_id;
    if (primaryVendorId) {
      const v = vendorStore.items.find((v) => v.id === primaryVendorId);
      if (v) return v.name;
    }
    return 'Primary Vendor';
  }
  const found = shipmentStore.currentShipmentSections.find((s) => s.id === sectionId);
  return found?.vendor?.name || 'Primary Vendor';
};

const isFirstItemOfSection = (item: any, index: number) => {
  if (activeSheetId.value !== 'sheet_all') return false;
  if (!shipmentStore.currentShipmentSections || shipmentStore.currentShipmentSections.length <= 1) return false;
  if (index === 0) return true;
  const prevItem = displayedItems.value[index - 1];
  return (prevItem as any)?.sectionId !== item.sectionId;
};

const getSectionItemCount = (sectionId?: number | null) => {
  const items = shipmentStore.currentShipmentItems || [];
  return items.filter((it) => (it.section_id ?? null) === (sectionId ?? null)).length;
};

const getSectionTotalQty = (sectionId?: number | null) => {
  const items = shipmentStore.currentShipmentItems || [];
  return items
    .filter((it) => (it.section_id ?? null) === (sectionId ?? null))
    .reduce((sum, it) => sum + (Number(it.ordered_quantity) || 0), 0);
};

const getSectionTotalPurchase = (sectionId?: number | null) => {
  const items = shipmentStore.currentShipmentItems || [];
  return items
    .filter((it) => (it.section_id ?? null) === (sectionId ?? null))
    .reduce((sum, it) => sum + (Number(it.purchase_price) || 0) * (Number(it.ordered_quantity) || 0), 0);
};

const resolveLineUnitCostBdt = (
  item: GlobalShipmentItem,
  allItems: GlobalShipmentItem[],
): number => {
  const shipment = shipmentStore.currentShipment;
  if (!shipment) {
    return Number(item.purchase_price) || 0;
  }

  if (!isShipmentCostsLocked(shipment)) {
    const forCosting = costingShipmentFromEntries(
      shipment,
      shipmentStore.currentCostEntries,
      allItems,
    );
    return calculateLineLandedCostBdt(item, forCosting, allItems);
  }

  const stamped = item.landed_cost_bdt;
  if (stamped != null && Number.isFinite(Number(stamped))) {
    return Number(stamped);
  }

  const forCosting = costingShipmentFromEntries(
    shipment,
    shipmentStore.currentCostEntries,
    allItems,
  );
  return calculateLineLandedCostBdt(item, forCosting, allItems);
};

// Dynamic table rows
const displayedItems = computed(() => {
  const storeItems = shipmentStore.currentShipmentItems;
  const costEntries = shipmentStore.currentCostEntries;
  const shipment = shipmentStore.currentShipment;
  const cargoWeightKg =
    shipment?.total_weight_kg ?? shipment?.received_weight ?? null;
  void costEntries;
  void cargoWeightKg;
  if (storeItems && storeItems.length > 0) {
    const activeSection = sheets.value.find((s) => s.id === activeSheetId.value);
    const activeSectionDbId = activeSection?.dbId;

    const firstSectionDbId = shipmentStore.currentShipmentSections?.[0]?.id ?? null;

    let filtered = storeItems;
    if (activeSectionDbId != null) {
      filtered = storeItems.filter(
        (it) => it.section_id === activeSectionDbId || (it.section_id == null && activeSectionDbId === firstSectionDbId),
      );
    }

    return filtered.map((item, idx) => {
      const pPrice = Number(item.purchase_price) || 0;
      const oQty = Number(item.ordered_quantity) || 0;
      const unitCost = resolveLineUnitCostBdt(item, storeItems);
      const totalCost = unitCost * oQty;
      const vendorName = getSectionVendor(item.section_id);
      const vendorInitials = vendorName
        .split(' ')
        .map((w) => w[0])
        .join('')
        .slice(0, 2)
        .toUpperCase();

      return {
        id: item.id || idx + 1,
        sl: idx + 1,
        sort_order: item.sort_order ?? idx + 1,
        selected: selectedItemIds.value.includes(item.id),
        name: item.name || 'Unnamed Product',
        code: item.product_code || item.barcode || `ITEM-${item.id}`,
        style_code: item.style_code,
        sku: item.sku,
        barcode: item.barcode,
        product_code: item.product_code,
        product_id: item.product_id,
        purchase_price: item.purchase_price,
        ordered_quantity: oQty,
        received_quantity: item.received_quantity ?? null,
        product_weight: item.product_weight,
        package_weight: item.package_weight,
        landed_cost_bdt: item.landed_cost_bdt ?? unitCost,
        category: getSectionTitle(item.section_id),
        sectionId: item.section_id ?? null,
        vendor: vendorName,
        vendorInitials: vendorInitials || 'PV',
        quantity: oQty,
        price: pPrice,
        cost: totalCost,
        unitCost,
        image_url: item.image_url,
        image: item.image_url || 'https://images.unsplash.com/photo-1601924994987-69e26d50dc26?w=100&auto=format&fit=crop&q=60',
        rawItem: item,
      };
    });
  }

  return [];
});

const batchCodeItemsQuery = useBatchCodeItemsByShipmentQuery(shipmentId);

const emptyBatchSummary: BatchCodeLineSummary = {
  compactLabel: '—',
  summaryLabel: '—',
  subLabel: null,
  lineCount: 0,
  toneClass: 'text-grey-5',
};

const queryClient = useQueryClient();
const tenantStore = useTenantStore();
const createBatchListMutation = useCreateBatchCodeListMutation();

type BatchDialogLine = {
  name: string;
  barcode?: string | null;
  product_code?: string | null;
};

const batchCodeDialogOpen = ref(false);
const batchCodeDialogProductName = ref('');
const batchCodeDialogLine = ref<BatchDialogLine | null>(null);
const batchCodeDialogAdding = ref(false);
const batchCodeDialogTogglingId = ref<number | null>(null);

const shipmentLineHasBatchCodes = (item: { barcode?: string | null; product_code?: string | null }) =>
  Boolean(item.barcode?.trim() || item.product_code?.trim());

const batchCodeDialogRows = computed<BatchCodeMatchTableRow[]>(() => {
  if (!batchCodeDialogLine.value) return [];
  const matches = matchBatchItemsForShipmentLine(
    batchCodeDialogLine.value,
    batchCodeItemsQuery.data.value ?? [],
  );
  return batchMatchTableRows(matches);
});

const batchCodeDialogCanAdd = computed(
  () => batchCodeDialogLine.value !== null && shipmentLineHasBatchCodes(batchCodeDialogLine.value),
);

const resolveBatchParentTenantId = (): number => {
  const currentTenant =
    tenantStore.selectedTenant ?? tenantStore.items.find((t) => t.id === authStore.tenantId);
  const tenantId = currentTenant?.parent_id ?? authStore.tenantId;
  if (!tenantId) throw new Error('No tenant found');
  return tenantId;
};

const extraOutcomesByItemId = ref<Record<number, ShipmentItemOutcome[]>>({});
const addingExtraItemId = ref<number | null>(null);

const extraOutcomesForItem = (itemId: number) =>
  (extraOutcomesByItemId.value[itemId] ?? []).filter((row) => row.reason !== 'ordered');

watch(
  () => shipmentStore.currentShipmentItems.map((i) => i.id).join(','),
  async (key) => {
    const ids = key ? key.split(',').map(Number) : [];
    if (ids.length === 0) {
      extraOutcomesByItemId.value = {};
      return;
    }
    try {
      const rows = await globalShipmentRepository.listShipmentItemOutcomes(ids);
      const map: Record<number, ShipmentItemOutcome[]> = {};
      for (const row of rows) {
        (map[row.shipment_item_id] ??= []).push(row);
      }
      extraOutcomesByItemId.value = map;
    } catch (err) {
      extraOutcomesByItemId.value = {};
      console.error(err);
    }
  },
  { immediate: true },
);

const outcomeOnHandById = ref<Record<number, number>>({});
const lineStockOnHandByItemId = ref<Record<number, number>>({});

const refreshOutcomeOnHand = async () => {
  if (!isShipmentReceived.value) {
    outcomeOnHandById.value = {};
    lineStockOnHandByItemId.value = {};
    return;
  }
  const ids = shipmentStore.currentShipmentItems.map((i) => i.id);
  try {
    const snapshot = await globalShipmentRepository.sumOutcomeOnHandByShipmentItemIds(ids);
    outcomeOnHandById.value = snapshot.byOutcomeId;
    lineStockOnHandByItemId.value = snapshot.byShipmentItemId;
  } catch (err) {
    outcomeOnHandById.value = {};
    lineStockOnHandByItemId.value = {};
    console.error(err);
  }
};

const onHandForOutcome = (itemId: number, outcomeId: number, outcomeQty: number) => {
  const direct = outcomeOnHandById.value[outcomeId] ?? 0;
  if (direct > 0) return direct;
  const lineTotal = lineStockOnHandByItemId.value[itemId] ?? 0;
  if (lineTotal <= 0) return 0;
  const sellableExtras = extraOutcomesForItem(itemId).filter((r) => r.kind === 'sellable');
  if (sellableExtras.length === 1 && sellableExtras[0]?.id === outcomeId) {
    return lineTotal;
  }
  return direct;
};

watch(
  () =>
    [
      shipmentStore.currentShipmentItems.map((i) => i.id).join(','),
      isShipmentReceived.value,
      shipmentStore.currentShipment?.stock_ready,
    ] as const,
  () => {
    void refreshOutcomeOnHand();
  },
  { immediate: true },
);

const canShowVendorDiscountForItem = (itemId: number) => {
  if (!isShipmentReceived.value || !canEditLineCostFields.value) return false;
  return extraOutcomesForItem(itemId).some(
    (row) => row.kind === 'sellable' && Number(row.quantity) > 0,
  );
};

const vendorDiscountDialogOpen = ref(false);
const vendorDiscountDialogRef = ref<InstanceType<typeof ShipmentVendorDiscountDialog> | null>(null);
const vendorDiscountLine = ref<GlobalShipmentItem | null>(null);
const vendorDiscountSubmitting = ref(false);

const vendorDiscountLineLabel = computed(() => {
  const line = vendorDiscountLine.value;
  if (!line) return '';
  const name = (line as { product_name?: string; name?: string }).product_name
    ?? (line as { name?: string }).name;
  return name ? String(name) : `Line #${line.id}`;
});

const vendorDiscountExtras = computed(() => {
  const line = vendorDiscountLine.value;
  if (!line) return [];
  return extraOutcomesForItem(line.id);
});

const openVendorDiscount = (item: Record<string, unknown>) => {
  vendorDiscountLine.value = item as GlobalShipmentItem;
  vendorDiscountDialogOpen.value = true;
};

const reloadExtrasForItems = async (itemIds: number[]) => {
  if (itemIds.length === 0) return;
  const rows = await globalShipmentRepository.listShipmentItemOutcomes(itemIds);
  const next = { ...extraOutcomesByItemId.value };
  for (const id of itemIds) {
    next[id] = rows.filter((r) => r.shipment_item_id === id);
  }
  extraOutcomesByItemId.value = next;
};

const onVendorDiscountSubmit = async (payload: {
  sourceOutcomeId: number;
  quantity: number;
  newPurchasePrice: number;
}) => {
  vendorDiscountSubmitting.value = true;
  try {
    const result = await globalShipmentRepository.applyShipmentOutcomeVendorDiscount(
      shipmentId,
      payload.sourceOutcomeId,
      payload.quantity,
      payload.newPurchasePrice,
    );
    await vendorDiscountDialogRef.value?.loadCredits?.();
    showSuccessNotification(
      `Vendor credit recorded (${currentPurchaseCurrencySymbol}${Number(result.credit_amount).toFixed(2)}). Stock unchanged.`,
    );
  } catch (err) {
    showErrorNotification((err as Error).message || 'Could not apply vendor discount');
  } finally {
    vendorDiscountSubmitting.value = false;
  }
};

const addExtraOutcome = async (item: {
  id: number;
  purchase_price: number;
  landed_cost_bdt?: number | null;
  unitCost?: number;
}) => {
  addingExtraItemId.value = item.id;
  try {
    const created = await globalShipmentRepository.createShipmentItemOutcome({
      parent_tenant_id: resolveBatchParentTenantId(),
      shipment_item_id: item.id,
      quantity: 0,
      kind: 'sellable',
      reason: 'general',
      purchase_price: Number(item.purchase_price) || 0,
      cost: item.landed_cost_bdt ?? item.unitCost ?? null,
    });
    extraOutcomesByItemId.value = {
      ...extraOutcomesByItemId.value,
      [item.id]: [...(extraOutcomesByItemId.value[item.id] ?? []), created],
    };
  } catch (err) {
    showErrorNotification((err as Error).message || 'Could not add price');
  } finally {
    addingExtraItemId.value = null;
  }
};

const updateExtraOutcome = async (id: number, patch: Partial<ShipmentItemOutcome>) => {
  if (!canEditSplits.value) {
    showErrorNotification(
      isShipmentReceived.value
        ? 'Splits are locked after receive. Use Record vendor credit for vendor price agreements.'
        : 'Splits cannot be edited right now.',
    );
    return;
  }
  try {
    const updated = await globalShipmentRepository.updateShipmentItemOutcome(id, patch, {
      shipmentId: shipmentId.value,
    });
    const list = extraOutcomesByItemId.value[updated.shipment_item_id] ?? [];
    extraOutcomesByItemId.value = {
      ...extraOutcomesByItemId.value,
      [updated.shipment_item_id]: list.map((row) => (row.id === updated.id ? updated : row)),
    };
  } catch (err) {
    showErrorNotification((err as Error).message || 'Could not update price');
  }
};

const deleteExtraOutcome = async (id: number) => {
  if (!canEditSplits.value) {
    showErrorNotification('Splits cannot be removed after receive.');
    return;
  }
  try {
    await globalShipmentRepository.deleteShipmentItemOutcome(id);
    const next: Record<number, ShipmentItemOutcome[]> = {};
    for (const [itemId, rows] of Object.entries(extraOutcomesByItemId.value)) {
      next[Number(itemId)] = rows.filter((row) => row.id !== id);
    }
    extraOutcomesByItemId.value = next;
  } catch (err) {
    showErrorNotification((err as Error).message || 'Could not remove price');
  }
};

const ensureBatchCodeListForShipment = async (): Promise<number> => {
  const existing = await batchCodeRepository.getByShipmentId(shipmentId);
  if (existing) return existing.id;

  const parentTenantId = resolveBatchParentTenantId();
  const shipment = shipmentStore.currentShipment;
  if (!shipment) throw new Error('Shipment not found');

  const created = await createBatchListMutation.mutateAsync({
    parentTenantId,
    payload: {
      parent_tenant_id: parentTenantId,
      shipment_id: shipmentId,
    },
    relations: {
      shipment: {
        id: shipment.id,
        name: shipment.name,
        tenant_shipment_id: shipment.tenant_shipment_id ?? null,
      },
    },
  });
  return created.id;
};

const patchBatchItemsByShipment = (updater: (items: BatchCodeItem[]) => BatchCodeItem[]) => {
  const key = procurementStockQueryKeys.batchCodeItemsByShipment(shipmentId);
  queryClient.setQueryData<BatchCodeItem[]>(key, (old) => updater(old ?? []));
};

const patchBatchItemInListCache = (updated: BatchCodeItem) => {
  const listItemsKey = procurementStockQueryKeys.batchCodeItems(updated.list_id);
  queryClient.setQueryData<BatchCodeItem[]>(listItemsKey, (old) =>
    old ? old.map((row) => (row.id === updated.id ? updated : row)) : old,
  );
};

const onToggleBatchArrivedFromDialog = async (itemId: number, value: boolean) => {
  const current = (batchCodeItemsQuery.data.value ?? []).find((row) => row.id === itemId);
  if (!current || current.is_arrived === value || batchCodeDialogTogglingId.value !== null) return;

  batchCodeDialogTogglingId.value = itemId;
  try {
    const updated = await batchCodeRepository.updateItem(itemId, { is_arrived: value });
    patchBatchItemsByShipment((items) =>
      items.map((row) => (row.id === updated.id ? updated : row)),
    );
    patchBatchItemInListCache(updated);
  } catch (error: unknown) {
    showErrorNotification((error as Error).message || 'Failed to update arrived.');
  } finally {
    batchCodeDialogTogglingId.value = null;
  }
};

const onAddBatchFromDialog = async (payload: { batch_id: string; expire_date: string }) => {
  const line = batchCodeDialogLine.value;
  if (!line || batchCodeDialogAdding.value) return;

  batchCodeDialogAdding.value = true;
  try {
    const listId = await ensureBatchCodeListForShipment();
    const expireIso = payload.expire_date ? toIsoDate(payload.expire_date) : null;

    const created = await batchCodeRepository.createItem({
      list_id: listId,
      barcode: line.barcode?.trim() || null,
      product_code: line.product_code?.trim() || null,
      batch_id: payload.batch_id.trim() || null,
      manufacturing_date: null,
      expire_date: expireIso,
      is_arrived: true,
    });

    patchBatchItemsByShipment((items) => [...items, created]);
    queryClient.setQueryData<BatchCodeItem[]>(procurementStockQueryKeys.batchCodeItems(listId), (old) => [
      ...(old ?? []),
      created,
    ]);

    showSuccessNotification('Batch line added.');
  } catch (error: unknown) {
    showErrorNotification((error as Error).message || 'Failed to add batch line.');
  } finally {
    batchCodeDialogAdding.value = false;
  }
};

const openBatchCodeDialog = (item: {
  name: string;
  barcode?: string | null;
  product_code?: string | null;
}) => {
  if (!shipmentLineHasBatchCodes(item)) return;
  batchCodeDialogLine.value = item;
  batchCodeDialogProductName.value = item.name;
  batchCodeDialogOpen.value = true;
};

const batchSummaryByItemId = computed(() =>
  buildBatchSummaryMapForLines(displayedItems.value, batchCodeItemsQuery.data.value ?? []),
);

const batchSummaryForItem = (item: { id: number }) =>
  batchSummaryByItemId.value.get(item.id) ?? emptyBatchSummary;

const allSelected = computed({
  get: () => displayedItems.value.length > 0 && displayedItems.value.every((i) => i.selected),
  set: (val: boolean) => {
    if (val) {
      selectedItemIds.value = displayedItems.value.map((i) => i.id);
    } else {
      selectedItemIds.value = [];
    }
  },
});

// Cell Draft Values & Direct Edit Handlers
const cellDraftValues = reactive<Record<number, Record<string, string | number | null>>>({});

const getCellDraftValue = (item: any, field: string) => {
  if (cellDraftValues[item.id]?.[field] !== undefined) {
    return cellDraftValues[item.id][field];
  }
  return item[field];
};

const onCellDirectInput = (item: any, field: string, val: string | number | null) => {
  if (!cellDraftValues[item.id]) {
    cellDraftValues[item.id] = {};
  }
  cellDraftValues[item.id][field] = val;
};

const onCellDirectBlur = async (item: any, field: string) => {
  if (!cellDraftValues[item.id] || cellDraftValues[item.id][field] === undefined) return;
  const draftVal = cellDraftValues[item.id][field];
  delete cellDraftValues[item.id][field];

  let parsedVal: number | null = null;
  if (draftVal !== null && draftVal !== '' && draftVal !== undefined) {
    const num = Number(draftVal);
    if (!isNaN(num)) {
      parsedVal = num;
    }
  }

  const rawOriginal = item.rawItem ? item.rawItem[field] : item[field];
  const currentNum = rawOriginal != null ? Number(rawOriginal) : null;
  if (parsedVal === currentNum) return;

  if (field === 'ordered_quantity' && parsedVal !== null && parsedVal < 1) {
    $q.notify({
      type: 'warning',
      message: 'Quantity must be at least 1',
      position: 'bottom',
    });
    return;
  }

  try {
    const payload: Record<string, unknown> = {
      [field]: parsedVal,
    };
    await shipmentStore.updateShipmentItem(item.id, payload as any);
    $q.notify({
      type: 'positive',
      message: 'Updated item',
      position: 'bottom',
      timeout: 1000,
    });
  } catch (err: unknown) {
    console.error(`Failed to update ${field}:`, err);
    $q.notify({
      type: 'negative',
      message: (err as Error)?.message || `Failed to update ${field}`,
      position: 'bottom',
    });
  }
};

const openImagePreview = (url?: string | null) => {
  if (!url) return;
  previewImageUrl.value = url;
  showImagePreviewDialog.value = true;
};

const onSlInputChange = async (item: any, newSlValue: any) => {
  const currentIndex = displayedItems.value.findIndex((it) => it.id === item.id);
  if (currentIndex === -1) return;
  const targetPos = parseInt(String(newSlValue), 10);
  const items = displayedItems.value || [];
  if (isNaN(targetPos) || targetPos < 1 || targetPos > items.length) return;
  const targetIndex = targetPos - 1;
  if (targetIndex === currentIndex) return;

  const fullItems = [...(shipmentStore.currentShipmentItems || [])];
  const currentItem = items[currentIndex];
  if (!currentItem) return;

  const fullCurrentIndex = fullItems.findIndex((it) => it.id === currentItem.id);
  if (fullCurrentIndex === -1) return;

  const [removed] = fullItems.splice(fullCurrentIndex, 1);

  const targetItem = items[targetIndex];
  let fullTargetIndex = fullItems.findIndex((it) => it.id === targetItem.id);
  if (fullTargetIndex === -1) {
    fullTargetIndex = targetIndex;
  } else if (targetIndex > currentIndex) {
    fullTargetIndex += 1;
  }

  fullItems.splice(fullTargetIndex, 0, removed);

  if (shipmentId && !isNaN(shipmentId)) {
    const itemsOrder = fullItems.map((it, idx) => ({
      id: it.id,
      sort_order: idx * 10,
    }));
    try {
      await shipmentStore.reorderShipmentItems(shipmentId, itemsOrder);
      await shipmentStore.fetchShipmentDetails(shipmentId);
      $q.notify({
        message: `Moved item to position #${targetPos}`,
        color: 'positive',
        icon: 'ph ph-arrows-down-up',
        position: 'bottom',
        timeout: 1000,
      });
    } catch (err: unknown) {
      console.error('Failed to reorder items', err);
      $q.notify({
        message: 'Failed to reorder item',
        color: 'negative',
        icon: 'ph ph-warning-circle',
        position: 'bottom',
      });
    }
  }
};

const editSingleSelectedItem = () => {
  if (selectedItemIds.value.length !== 1) return;
  const targetId = selectedItemIds.value[0];
  const item = (shipmentStore.currentShipmentItems ?? []).find((it) => it.id === targetId);
  if (item) {
    openEditItem(item);
  }
};

const deleteSingleSelectedItem = () => {
  if (selectedItemIds.value.length !== 1) return;
  const targetId = selectedItemIds.value[0];
  if (targetId != null) {
    confirmDeleteItem(targetId);
    selectedItemIds.value = [];
  }
};

const bulkDeleteSelectedItems = () => {
  if (selectedItemIds.value.length === 0) return;
  const count = selectedItemIds.value.length;
  $q.dialog({
    title: 'Confirm Bulk Deletion',
    message: `Are you sure you want to delete ${count} selected item${count === 1 ? '' : 's'}?`,
    cancel: true,
    persistent: true,
    ok: {
      label: 'Delete',
      color: 'negative',
      flat: true,
    },
  }).onOk(() => {
    void (async () => {
      if (shipmentId && !isNaN(shipmentId)) {
        try {
          await shipmentStore.deleteShipmentItemsBulk(shipmentId, selectedItemIds.value);
          $q.notify({
            message: `Deleted ${count} items successfully`,
            color: 'positive',
            icon: 'ph ph-check-circle',
          });
          selectedItemIds.value = [];
        } catch (err: unknown) {
          $q.notify({
            message: (err as Error).message || 'Failed to delete items',
            color: 'negative',
            icon: 'ph ph-warning-circle',
          });
        }
      }
    })();
  });
};

// Excel Sheets Management
const tableScrollContainerRef = ref<HTMLElement | null>(null);
const hasUserSelectedSheet = ref(false);
const activeSheetId = ref('sheet_all');
const sheets = ref<SheetTabItem[]>([
  { id: 'sheet_all', name: 'All Items' },
]);

const activeSectionDbId = computed(() => {
  const activeSection = sheets.value.find((s) => s.id === activeSheetId.value);
  return activeSection?.dbId ?? null;
});

const firstSectionSheetId = (sections: typeof shipmentStore.currentShipmentSections) =>
  sections?.length ? `section_${sections[0].id}` : null;

const downloadActiveSheetExcel = () => {
  const activeSheet = sheets.value.find((sheet) => sheet.id === activeSheetId.value);
  void downloadExcel({
    sheetId: activeSheetId.value,
    sheetName: activeSheet?.name,
  });
};

const downloadSheetExcel = (sheet: SheetTabItem) => {
  void downloadExcel({
    sheetId: sheet.id,
    sheetName: sheet.name,
  });
};

const onSheetTabChange = async (id: string) => {
  hasUserSelectedSheet.value = true;
  activeSheetId.value = id;
  selectedItemIds.value = [];
  if (shipmentId && !isNaN(shipmentId)) {
    try {
      await shipmentStore.fetchShipmentDetails(shipmentId);
    } catch (err) {
      console.error('Failed to refresh shipment items on section switch:', err);
    }
  }
};

watch(
  () => shipmentStore.currentShipmentSections,
  (sections) => {
    if (sections && sections.length > 0) {
      const generated: SheetTabItem[] = [
        { id: 'sheet_all', name: 'All Items' },
        ...sections.map((sec) => ({
          id: `section_${sec.id}`,
          dbId: sec.id,
          name: sec.title || `Section #${sec.id}`,
          invoiceNumber: (sec as any).invoice_number || sec.metadata?.invoice_number || '',
          invoiceDate: (sec as any).invoice_date || sec.metadata?.invoice_date || '',
          notes: (sec as any).notes || sec.metadata?.notes || '',
        })),
      ];
      sheets.value = generated;
      const defaultSectionId = firstSectionSheetId(sections);
      const activeStillValid = generated.some((s) => s.id === activeSheetId.value);

      if (!activeStillValid) {
        activeSheetId.value = defaultSectionId ?? 'sheet_all';
      } else if (!hasUserSelectedSheet.value && activeSheetId.value === 'sheet_all' && defaultSectionId) {
        activeSheetId.value = defaultSectionId;
      }
    }
  },
  { immediate: true },
);

const scrollThumbWidth = ref(30);
const scrollThumbLeft = ref(0);

const updateScrollbarFromTable = () => {
  const el = tableScrollContainerRef.value;
  if (!el) return;
  const maxScrollLeft = el.scrollWidth - el.clientWidth;
  if (maxScrollLeft <= 0) {
    scrollThumbWidth.value = 100;
    scrollThumbLeft.value = 0;
    return;
  }
  const ratio = el.clientWidth / el.scrollWidth;
  const thumbWidthPct = Math.max(15, Math.min(80, ratio * 100));
  scrollThumbWidth.value = thumbWidthPct;
  const scrollFraction = el.scrollLeft / maxScrollLeft;
  const availableTrackPct = 100 - thumbWidthPct;
  scrollThumbLeft.value = scrollFraction * availableTrackPct;
};

const onTableScroll = () => {
  updateScrollbarFromTable();
};

onMounted(() => {
  if (shipmentId && !isNaN(shipmentId)) {
    void shipmentStore.fetchShipmentDetails(shipmentId);
  }
  updateScrollbarFromTable();
  window.addEventListener('resize', updateScrollbarFromTable);
});

onUnmounted(() => {
  window.removeEventListener('resize', updateScrollbarFromTable);
});

const scrollTableByStep = (delta: number) => {
  if (tableScrollContainerRef.value) {
    tableScrollContainerRef.value.scrollBy({ left: delta, behavior: 'smooth' });
  }
};

const onTrackClick = (fraction: number) => {
  const table = tableScrollContainerRef.value;
  if (!table) return;
  const maxScrollLeft = table.scrollWidth - table.clientWidth;
  table.scrollTo({ left: fraction * maxScrollLeft, behavior: 'smooth' });
};

const startThumbDrag = (e: MouseEvent) => {
  e.preventDefault();
  e.stopPropagation();
  const table = tableScrollContainerRef.value;
  const track = excelBottomBarRef.value?.scrollTrackRef;
  if (!track || !table) return;

  const startX = e.clientX;
  const startScrollLeft = table.scrollLeft;
  const trackRect = track.getBoundingClientRect();
  const availableTrackWidth = trackRect.width * (1 - scrollThumbWidth.value / 100);
  const maxScrollLeft = table.scrollWidth - table.clientWidth;

  const onMouseMove = (moveEvent: MouseEvent) => {
    if (availableTrackWidth <= 0) return;
    const deltaX = moveEvent.clientX - startX;
    const deltaScroll = (deltaX / availableTrackWidth) * maxScrollLeft;
    table.scrollLeft = Math.max(0, Math.min(maxScrollLeft, startScrollLeft + deltaScroll));
  };

  const onMouseUp = () => {
    window.removeEventListener('mousemove', onMouseMove);
    window.removeEventListener('mouseup', onMouseUp);
  };

  window.addEventListener('mousemove', onMouseMove);
  window.addEventListener('mouseup', onMouseUp);
};

// Section / Invoice Sheet actions
const openViewSectionDialog = (sheet: SheetTabItem) => {
  viewingSectionData.value = { ...sheet };
  showViewSectionDialog.value = true;
};

const switchToEditFromView = () => {
  showViewSectionDialog.value = false;
  if (viewingSectionData.value) {
    openEditSectionDialog(viewingSectionData.value);
  }
};

const openAddSectionDialog = () => {
  isEditingSection.value = false;
  editingSectionData.value = {
    title: `Invoice Section ${sheets.value.length + 1}`,
    invoiceNumber: '',
    invoiceDate: '',
    notes: '',
  };
  showAddSectionDialog.value = true;
};

const openEditSectionDialog = (sheet: SheetTabItem) => {
  isEditingSection.value = true;
  editingSectionData.value = {
    id: sheet.id,
    dbId: sheet.dbId,
    title: sheet.name,
    invoiceNumber: sheet.invoiceNumber || '',
    invoiceDate: sheet.invoiceDate || '',
    notes: sheet.notes || '',
  };
  showAddSectionDialog.value = true;
};

const onSaveSectionSheet = async (data: SectionFormData) => {
  if (isEditingSection.value && data.id) {
    const target = sheets.value.find((s) => s.id === data.id);
    if (target) {
      target.name = data.title;
      target.invoiceNumber = data.invoiceNumber;
      target.invoiceDate = data.invoiceDate;
      target.notes = data.notes;

      if (shipmentId && target.dbId) {
        try {
          await shipmentStore.updateSection(target.dbId, {
            title: data.title,
            metadata: {
              invoice_number: data.invoiceNumber,
              invoice_date: data.invoiceDate,
              notes: data.notes,
            },
          });
          await shipmentStore.fetchShipmentDetails(shipmentId);
          $q.notify({
            type: 'positive',
            message: 'Section updated successfully',
          });
        } catch (err: unknown) {
          console.error('Failed to update section in DB', err);
          $q.notify({
            type: 'negative',
            message: err instanceof Error ? err.message : 'Failed to update section',
          });
        }
      }
    }
  } else {
    let createdDbId: number | undefined;
    if (shipmentId && !isNaN(shipmentId)) {
      try {
        const parentTenantId = currentTenantId.value ?? shipmentStore.currentShipment?.parent_tenant_id;
        const vendorId = shipmentStore.currentShipment?.vendor_id ?? shipmentStore.currentShipmentSections[0]?.vendor_id;
        const created = await shipmentStore.createSection({
          parent_tenant_id: parentTenantId ?? undefined,
          shipment_id: shipmentId,
          vendor_id: vendorId ?? undefined,
          title: data.title,
          metadata: {
            invoice_number: data.invoiceNumber,
            invoice_date: data.invoiceDate,
            notes: data.notes,
          },
        });
        createdDbId = created?.id;
        await shipmentStore.fetchShipmentDetails(shipmentId);
        $q.notify({
          type: 'positive',
          message: `Created section "${data.title}"`,
        });
      } catch (err: unknown) {
        console.error('Failed to create section in DB', err);
        $q.notify({
          type: 'negative',
          message: err instanceof Error ? err.message : 'Failed to create section',
        });
      }
    }

    if (createdDbId) {
      hasUserSelectedSheet.value = true;
      activeSheetId.value = `section_${createdDbId}`;
    }
    setTimeout(() => excelBottomBarRef.value?.scrollToTab('end'), 50);
  }
};

const removeSheet = async (id: string) => {
  const target = sheets.value.find((s) => s.id === id);
  if (!target) return;

  if (shipmentId && target.dbId) {
    try {
      await shipmentStore.deleteSection(target.dbId);
      await shipmentStore.fetchShipmentDetails(shipmentId);
      $q.notify({
        type: 'positive',
        message: 'Section deleted successfully',
      });
    } catch (err: unknown) {
      console.error('Failed to delete section in DB', err);
      $q.notify({
        type: 'negative',
        message: err instanceof Error ? err.message : 'Failed to delete section',
      });
    }
  }
};

</script>

<style scoped>
.shipment-items-v2-page {
  background: #fff;
  color: var(--bw-theme-ink);
}

.shipment-items-top-section {
  background: #fff;
}

.shipment-settings-trigger {
  width: 40px;
  height: 40px;
}

.shipment-settings-trigger :deep(.q-icon) {
  font-size: 22px;
}

.shipment-items-middle-section,
.shipment-items-markup-table {
  background: #fff;
  color: var(--bw-theme-ink);
}

.shipment-header-workflow :deep(.shipment-status-toolbar) {
  border: none;
  padding-left: 0;
  padding-right: 0;
}

.section-break-card {
  background: #fff;
  border: 1px solid var(--bw-theme-border);
  border-radius: 8px;
  user-select: none;
}
.section-break-row {
  background: color-mix(in srgb, var(--bw-theme-surface) 88%, var(--bw-theme-base) 12%) !important;
  border-top: 2px solid var(--bw-theme-border) !important;
  border-bottom: 1px solid var(--bw-theme-border) !important;
  user-select: none;
}
.section-break-row td {
  background: color-mix(in srgb, var(--bw-theme-surface) 88%, var(--bw-theme-base) 12%) !important;
  height: 38px !important;
  color: var(--bw-theme-ink);
}
.border-bottom {
  border-bottom: 1px solid var(--bw-theme-border);
}
.border-top {
  border-top: 1px solid var(--bw-theme-border);
}
.border-grey {
  border: 1px solid var(--bw-theme-border);
  border-radius: 8px;
}
.shrink-0 {
  flex-shrink: 0;
}
.avatar-soft-sq {
  border-radius: 6px;
}
.text-xxs {
  font-size: 11px;
}
.font-mono {
  font-family: monospace;
}
.hide-native-scrollbar {
  scrollbar-width: none;
  -ms-overflow-style: none;
}
.hide-native-scrollbar::-webkit-scrollbar {
  display: none;
}

.shipment-items-markup-table th,
.shipment-items-markup-table td {
  padding: 4px 4px !important;
  height: 48px;
  color: var(--bw-theme-ink);
}

.shipment-items-markup-table tbody td:not([class*='bw-ops-col-tint']) {
  background-color: var(--bw-theme-surface) !important;
}

.shipment-items-markup-table thead th:not([class*='bw-ops-col-tint']) {
  background: color-mix(in srgb, var(--bw-theme-surface) 92%, var(--bw-theme-base) 8%) !important;
  color: var(--bw-theme-muted) !important;
  border-bottom: 1px solid var(--bw-theme-border);
}

.shipment-items-markup-table thead th[class*='bw-ops-col-tint'] {
  color: var(--bw-theme-muted) !important;
  border-bottom: 1px solid var(--bw-theme-border);
}

.shipment-items-markup-table tr.row-selected td:not([class*='bw-ops-col-tint']) {
  background-color: color-mix(in srgb, var(--bw-theme-surface) 82%, var(--bw-theme-primary) 18%) !important;
}

.shipment-items-markup-table tr:hover td {
  filter: brightness(0.98);
}

/* Hide number input spinners */
:deep(input[type='number']::-webkit-outer-spin-button),
:deep(input[type='number']::-webkit-inner-spin-button) {
  -webkit-appearance: none !important;
  margin: 0 !important;
}

:deep(input[type='number']) {
  -moz-appearance: textfield !important;
  appearance: textfield !important;
}

:deep(.inline-edit-input .q-field__control) {
  height: 28px !important;
  min-height: 28px !important;
  padding: 0 4px !important;
}

:deep(.excel-cell-input .q-field__control) {
  border-radius: 0 !important;
  border: none !important;
  background-color: transparent !important;
  transition: all 0.1s ease-in-out;
}

:deep(.excel-cell-input .q-field__control:before),
:deep(.excel-cell-input .q-field__control:after) {
  border: none !important;
}

:deep(.excel-cell-input:hover .q-field__control) {
  background-color: color-mix(in srgb, var(--bw-theme-ink) 6%, transparent) !important;
}

:deep(.excel-cell-input.q-field--focused .q-field__control) {
  background-color: var(--bw-theme-surface) !important;
  border: 1.5px solid var(--bw-theme-primary) !important;
  box-shadow: 0 0 0 1px var(--bw-theme-primary) !important;
}

:deep(.excel-cell-input--weight-tint .q-field__control) {
  border-radius: 6px !important;
  background-color: color-mix(in srgb, var(--bw-ops-hue-weight) 78%, var(--bw-theme-surface)) !important;
  box-shadow: none !important;
}
:deep(.excel-cell-input--weight-tint:hover .q-field__control) {
  background-color: color-mix(in srgb, var(--bw-ops-hue-weight) 88%, var(--bw-theme-surface)) !important;
}
:deep(.excel-cell-input--weight-tint.q-field--focused .q-field__control) {
  background-color: color-mix(in srgb, var(--bw-ops-hue-weight) 88%, var(--bw-theme-surface)) !important;
  border: 1.5px solid var(--bw-ops-accent-weight) !important;
  box-shadow: none !important;
}

:deep(.excel-cell-input--price-tint .q-field__control) {
  border-radius: 6px !important;
  background-color: color-mix(in srgb, var(--bw-ops-hue-price) 78%, var(--bw-theme-surface)) !important;
  box-shadow: none !important;
}
:deep(.excel-cell-input--price-tint:hover .q-field__control) {
  background-color: color-mix(in srgb, var(--bw-ops-hue-price) 88%, var(--bw-theme-surface)) !important;
}
:deep(.excel-cell-input--price-tint.q-field--focused .q-field__control) {
  background-color: color-mix(in srgb, var(--bw-ops-hue-price) 88%, var(--bw-theme-surface)) !important;
  border: 1.5px solid var(--bw-ops-accent-price) !important;
  box-shadow: none !important;
}

.hover-bright {
  transition: filter 0.15s ease, transform 0.15s ease;
}
.hover-bright:hover {
  filter: brightness(0.92);
  transform: translateY(-1px);
}

.bulk-paste-header-btn {
  opacity: 0.6;
  transition: opacity 0.15s ease-in-out, transform 0.15s ease-in-out;
  padding: 0 !important;
  min-height: 18px !important;
  min-width: 18px !important;
}

.bulk-paste-header-btn:hover {
  opacity: 1 !important;
  color: var(--q-primary) !important;
  transform: scale(1.1);
}

.shipment-name-container {
  display: inline-flex;
  align-items: center;
  max-width: 400px;
}

.shipment-name-display-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  background: transparent;
  border: 1px solid transparent;
  padding: 3px 6px;
  border-radius: 6px;
  cursor: pointer;
  max-width: 100%;
  text-align: left;
  transition: all 0.15s ease;
}

.shipment-name-display-btn:hover {
  background: var(--bw-neutral-surface-hover, rgba(0, 0, 0, 0.05));
  border-color: #E2E8F0;
}

.shipment-name-display-btn:hover .shipment-name-icon {
  opacity: 1;
  color: var(--q-primary, #0F172A);
}

.shipment-name-text {
  font-size: 15px;
  font-weight: 800;
  color: #0F172A;
  letter-spacing: -0.01em;
  line-height: 1.2;
}

.shipment-name-icon {
  color: #94A3B8;
  opacity: 0.6;
  flex-shrink: 0;
  transition: all 0.15s ease;
}

.shipment-name-input {
  font-size: 15px;
  font-weight: 800;
  color: #0F172A;
  letter-spacing: -0.01em;
  background: #FFFFFF;
  border: 1.5px solid var(--q-primary, #2563EB);
  border-radius: 6px;
  padding: 2px 8px;
  line-height: 1.2;
  height: 28px;
  outline: none;
  box-shadow: 0 0 0 2px rgba(37, 99, 235, 0.15);
  width: 100%;
  min-width: 220px;
}

/* Item Image Cell & Expand Button (1 inch) */
.item-img-cell {
  width: 1.1in;
  min-width: 1.1in;
  max-width: 1.1in;
  padding: 4px 6px;
  overflow: hidden;
}

.item-img-container {
  position: relative;
  width: 1in;
  height: 1in;
  max-width: 1in;
  max-height: 1in;
  border-radius: 8px;
  overflow: hidden;
  background: var(--bw-neutral-surface-subtle, #F1F5F9);
  border: 1px solid var(--bw-theme-border, #E2E8F0);
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto;
}

.item-img-container :deep(.item-img-smart),
.item-img-container :deep(.item-img-element),
.item-img-container :deep(.smart-image-wrapper) {
  display: block !important;
  width: 100% !important;
  height: 100% !important;
  max-width: 100% !important;
  max-height: 100% !important;
  overflow: hidden;
  border-radius: 8px;
}

.item-img-container :deep(.smart-image__img) {
  width: 100% !important;
  height: 100% !important;
  max-width: 100% !important;
  max-height: 100% !important;
  object-fit: contain !important;
  object-position: center;
}

.img-expand-btn {
  position: absolute;
  bottom: 2px;
  right: 2px;
  background: rgba(15, 23, 42, 0.7);
  color: #FFFFFF !important;
  padding: 2px !important;
  opacity: 0;
  transition: opacity 0.15s ease-in-out;
}

.item-img-container:hover .img-expand-btn {
  opacity: 1;
}

.bulk-paste-grid-wrap {
  max-height: 420px;
  overflow: auto;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
}

.bulk-paste-grid {
  width: 100%;
  border-collapse: collapse;
  table-layout: fixed;
}

.bulk-paste-grid th {
  position: sticky;
  top: 0;
  z-index: 1;
  background: #f8fafc;
  font-size: 11px;
  font-weight: 700;
  color: #475569;
  text-align: left;
  padding: 6px 8px;
  border-bottom: 1px solid #cbd5e1;
}

.bulk-paste-grid td {
  padding: 0;
  border-bottom: 1px solid #e2e8f0;
  border-right: 1px solid #e2e8f0;
}

.bulk-paste-grid td:last-child {
  border-right: none;
}

.bulk-paste-cell {
  width: 100%;
  height: 28px;
  border: none;
  outline: none;
  padding: 0 8px;
  font-size: 12px;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  background: #fff;
  color: #0f172a;
}

.bulk-paste-cell:focus {
  box-shadow: inset 0 0 0 2px var(--q-primary, #2563eb);
}

.bulk-paste-cell--value {
  font-weight: 700;
}

/* SL In-Place Editable Input */
.sl-input {
  width: 32px;
  height: 24px;
  text-align: center;
  font-size: 12px;
  font-weight: 700;
  color: #475569;
  border: 1px solid transparent;
  border-radius: 4px;
  background: transparent;
  outline: none;
  transition: all 0.15s ease;
  padding: 0;
}

.sl-input:hover {
  background: rgba(0, 0, 0, 0.04);
  border-color: #CBD5E1;
}

.sl-input:focus {
  background: #FFFFFF;
  border-color: var(--q-primary, #2563EB);
  box-shadow: 0 0 0 1.5px rgba(37, 99, 235, 0.2);
}

.batch-code-tone--warn {
  color: #b42318;
}

.batch-code-tone--ok {
  color: #047857;
}

.batch-code-tone--unset {
  color: #1d4ed8;
}

.batch-code-cell--active {
  cursor: pointer;
}

.batch-code-cell--active:hover {
  background: rgba(15, 23, 42, 0.04);
}

/* Hide number spin buttons on SL input */
.sl-input::-webkit-outer-spin-button,
.sl-input::-webkit-inner-spin-button {
  -webkit-appearance: none;
  margin: 0;
}
.sl-input {
  -moz-appearance: textfield;
}

/* Skeleton Rows & Empty Placeholder */
.shipment-skeleton-row td {
  padding: 8px !important;
  border-bottom: 1px solid #F1F5F9;
}

.empty-state-table-row td {
  background: var(--bw-neutral-surface, #FFFFFF);
}

.empty-placeholder-wrapper {
  user-select: none;
}

.empty-illustration-svg {
  filter: drop-shadow(0 2px 8px rgba(0, 0, 0, 0.04));
  animation: floatIllustration 4s ease-in-out infinite alternate;
}

@keyframes floatIllustration {
  0% {
    transform: translateY(0);
  }
  100% {
    transform: translateY(-4px);
  }
}
</style>
