<template>
  <q-page class="q-pa-md thrift-stock-page">
    <div class="q-gutter-y-md">
      <!-- Standard Page Header -->
      <ThriftStockHeader :can-create="canCreate" @register-stock="openAddDialog" />

      <!-- Standard Toolbar Card -->
      <ThriftStockToolbar
        v-model:search="searchText"
        v-model:selected-column-names="selectedColumnNames"
        v-model:all-selectable-columns-selected="allSelectableColumnsSelected"
        v-model:view-mode="viewMode"
        :active-filter-count="activeFilterCount"
        :column-selector-options="columnSelectorOptions"
        :csv-export-loading="csvExportLoading"
        @open-filters="openFilterDrawer"
        @download-csv="downloadStockCsv"
      />

      <!-- Filter Sidebar Drawer -->
      <ThriftStockFilterDrawer
        v-model="filterDrawerOpen"
        v-model:status-filter="draftStatusFilter"
        v-model:condition-filter="draftConditionFilter"
        :status-options="statusOptions"
        :condition-options="conditionOptions"
        @apply="onApplyDrawerFilters"
        @reset="onResetDrawerFilters"
      />

      <!-- Bulk Selection Bar -->
      <ThriftStockBulkActionBar
        :selected-count="selectedStockIds.length"
        :can-delete="canDelete"
        @clear-selection="clearStockSelection"
        @confirm-bulk-delete="confirmBulkDelete"
      />

      <!-- Table Component -->
      <ThriftStockTable
        v-model:table-pagination="tablePagination"
        :stocks="stocks"
        :loading="loading"
        :store-page="store.page"
        :store-page-size="store.pageSize"
        :columns="columns"
        :visible-columns="displayVisibleColumns"
        :selected-stock-ids="selectedStockIds"
        :all-page-rows-selected="allPageRowsSelected"
        :some-page-rows-selected="somePageRowsSelected"
        :cost-breakdown-by-stock-id="costBreakdownByStockId"
        :boxes-list="boxesList"
        :table-cell-class="tableCellClass"
        :sticky-cell-class="stickyCellClass"
        :shipment-purchase-currency="shipmentPurchaseCurrency"
        :shipment-cost-currency="shipmentCostCurrency"
        :item-markup-pct-for-row="itemMarkupPctForRow"
        :effective-markup-label="effectiveMarkupLabel"
        :get-box-name="getBoxName"
        :can-edit="canEdit"
        :can-delete="canDelete"
        @toggle-select-all-page="toggleSelectAllPage"
        @toggle-stock-selection="({ id, checked }) => toggleStockSelection(id, checked)"
        @open-barcode-preview="openBarcodePreview"
        @open-measurements-dialog="openMeasurementsDialog"
        @open-landed-breakdown-dialog="openLandedBreakdownDialog"
        @reset-item-markup-to-shipment="resetItemMarkupToShipment"
        @reset-price-to-suggested="resetPriceToSuggested"
        @open-edit-dialog="openEditDialog"
        @confirm-delete="confirmDelete"
        @update-status="({ id, status }) => updateStatus(id, status)"
        @open-hold-dialog="openHoldDialog"
        @release-hold="releaseHold"
        @text-cell-save="({ row, field, val }) => onTextCellSave(row, field, val)"
        @section-save="({ row, val }) => onSectionSave(row, val)"
        @box-save="({ row, val }) => onBoxSave(row, val)"
        @number-cell-save="({ row, field, val }) => onNumberCellSave(row, field, val)"
        @condition-save="({ row, val }) => onConditionSave(row, val)"
        @origin-unit-price-save="({ row, val }) => onOriginUnitPriceSave(row, val)"
        @extra-origin-unit-price-save="({ row, val }) => onExtraOriginUnitPriceSave(row, val)"
        @additional-charges-cost-save="({ row, val }) => saveStockCell(row, { additional_charges_cost: val })"
        @item-markup-save="({ row, val }) => onItemMarkupSave(row, val)"
        @listed-unit-price-save="({ row, val }) => onListedUnitPriceSave(row, val)"
        @status-cell-save="({ row, val }) => onStatusCellSave(row, val)"
      />

      <!-- Register & Edit Stock Form Dialog -->
      <ThriftStockRegisterDialog
        v-model="dialogOpen"
        v-model:form="form"
        v-model:origin-unit-price="originUnitPrice"
        v-model:extra-origin-unit-price="extraOriginUnitPrice"
        v-model:additional-charges-cost="additionalChargesCost"
        v-model:pricing="pricing"
        :editing-id="editingId"
        :edit-image="editImage"
        :shipments="shipments"
        :filtered-boxes="filteredBoxes"
        :categories="categories"
        :types="types"
        :shelves="shelves"
        :purchase-currency="purchaseCurrency"
        :cost-currency="costCurrency"
        :purchase-currency-symbol="purchaseCurrencySymbol"
        :cost-currency-symbol="costCurrencySymbol"
        @shipment-change="onShipmentChange"
        @open-uploader="openEditUploader"
        @remove-image-click="imageRemoveConfirmOpen = true"
        @submit="onSubmit"
        @hide="onEditDialogHide"
      />

      <!-- Quick Add Stock Dialog -->
      <ThriftStockQuickAddDialog
        v-model="quickAddDialogOpen"
        v-model:form="quickAddForm"
        :shipments="shipments"
        :categories="categories"
        :types="types"
        :quick-add-filtered-boxes="quickAddFilteredBoxes"
        :condition-select-options="conditionSelectOptions"
        :quick-add-barcode-loading="quickAddBarcodeLoading"
        :quick-add-purchase-currency="quickAddPurchaseCurrency"
        :default-origin-unit-price="settings?.default_origin_unit_price || 0"
        :quick-submitting="quickSubmitting"
        :can-submit-quick-add="canSubmitQuickAdd"
        @quick-shipment-change="onQuickShipmentChange"
        @open-uploader="
          uploaderTarget = 'quick';
          isUploaderOpen = true;
        "
        @submit="submitQuickAdd"
        @hide="onQuickAddDialogHide"
      />

      <!-- Hold Dialog -->
      <q-dialog v-model="holdDialogOpen" persistent>
        <q-card style="min-width: 360px; max-width: 420px">
          <q-card-section>
            <div class="text-h6">Hold item</div>
            <div class="text-caption text-grey-7 q-mt-xs">
              {{ holdTarget?.barcode || holdTarget?.name || 'Stock' }} — removes from open sell until
              release or invoice with the same phone.
            </div>
          </q-card-section>
          <q-card-section class="q-gutter-y-sm">
            <q-input
              v-model="holdForm.heldForPhone"
              label="Customer phone *"
              dense
              outlined
              autofocus
            />
            <q-input v-model="holdForm.heldForName" label="Customer name" dense outlined />
            <q-input
              v-model="holdForm.holdNote"
              label="Hold note"
              dense
              outlined
              type="textarea"
              autogrow
            />
          </q-card-section>
          <q-card-actions align="right">
            <q-btn flat no-caps label="Cancel" v-close-popup :disable="holdSubmitting" />
            <q-btn
              color="orange-8"
              unelevated
              no-caps
              label="Place hold"
              :loading="holdSubmitting"
              @click="submitHold"
            />
          </q-card-actions>
        </q-card>
      </q-dialog>

      <!-- Barcode Preview Dialog -->
      <ThriftStockBarcodePreviewDialog
        v-model="barcodePreviewOpen"
        :barcode-value="previewBarcodeValue"
        :stock-label="previewStockLabel"
        @copy="copyPreviewBarcode"
      />

      <!-- Delete Confirmation Dialogs -->
      <ThriftStockDeleteConfirmDialog
        v-model:delete-confirm-open="deleteConfirmOpen"
        v-model:bulk-delete-confirm-open="bulkDeleteConfirmOpen"
        v-model:image-remove-confirm-open="imageRemoveConfirmOpen"
        :delete-loading="deleteLoading"
        :selected-row="selectedRow"
        :bulk-delete-loading="bulkDeleteLoading"
        :selected-stock-ids-count="selectedStockIds.length"
        @delete-item="deleteItem"
        @delete-selected-items="deleteSelectedItems"
        @remove-edit-image="removeEditImage"
      />

      <!-- Global Cloudinary Uploader Dialog -->
      <CloudinaryUploaderDialog
        v-model="isUploaderOpen"
        :folder="uploaderCloudinaryFolder"
        defer-upload
        @selected="onImageSelected"
      />

      <PageInitialLoader v-if="actionLoading" overlay />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useModulePermissions } from 'src/modules/navigation/modulePermissions';
import { useThriftStockStore } from '../stores/thriftStockStore';
import { useThriftStocksQuery, type ThriftStockQueryParams } from '../composables/useThriftStocksQuery';
import PageInitialLoader from 'src/components/PageInitialLoader.vue';

// Sub-components
import ThriftStockHeader from '../components/ThriftStockHeader.vue';
import ThriftStockToolbar from '../components/ThriftStockToolbar.vue';
import ThriftStockFilterDrawer from '../components/ThriftStockFilterDrawer.vue';
import ThriftStockBulkActionBar from '../components/ThriftStockBulkActionBar.vue';
import ThriftStockTable from '../components/ThriftStockTable.vue';
import type { ThriftStockViewMode } from '../components/ThriftStockToolbar.vue';
import ThriftStockRegisterDialog from '../components/ThriftStockRegisterDialog.vue';
import ThriftStockQuickAddDialog from '../components/ThriftStockQuickAddDialog.vue';
import ThriftStockBarcodePreviewDialog from '../components/ThriftStockBarcodePreviewDialog.vue';
import ThriftStockDeleteConfirmDialog from '../components/ThriftStockDeleteConfirmDialog.vue';
import CloudinaryUploaderDialog from 'src/components/CloudinaryUploaderDialog.vue';

import {
  useThriftStockColumns,
  statusOptions,
  conditionOptions,
  conditionSelectOptions,
} from '../composables/useThriftStockColumns';

// Composables
import { useThriftStockCosting } from '../composables/useThriftStockCosting';
import { useThriftStockForms } from '../composables/useThriftStockForms';
import { useThriftStockActions } from '../composables/useThriftStockActions';

const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();
const store = useThriftStockStore();
const { hasModuleAccess } = useModulePermissions();

const canCreate = computed(() => hasModuleAccess('thrift_stock', 'create'));
const canEdit = computed(() => hasModuleAccess('thrift_stock', 'edit'));
const canDelete = computed(() => hasModuleAccess('thrift_stock', 'delete'));

const {
  columns,
  columnSelectorOptions,
  selectedColumnNames,
  visibleColumns,
  allSelectableColumnsSelected,
  tableCellClass,
  stickyCellClass,
} = useThriftStockColumns();

/** Compact mode: SL + image always shown; these selectable cols only (no select/actions). */
const COMPACT_COLUMN_NAMES = ['barcode', 'size', 'brand_name', 'listed_unit_price'] as const;
const savedTableColumns = ref<string[] | null>(null);
const viewMode = ref<ThriftStockViewMode>('compact');

const displayVisibleColumns = computed(() => {
  if (viewMode.value === 'compact') {
    return ['sl', 'image', ...COMPACT_COLUMN_NAMES];
  }
  return visibleColumns.value;
});

watch(
  viewMode,
  (mode) => {
    if (mode === 'compact') {
      if (!savedTableColumns.value) {
        savedTableColumns.value = [...selectedColumnNames.value];
      }
      selectedColumnNames.value = [...COMPACT_COLUMN_NAMES];
      return;
    }
    if (savedTableColumns.value) {
      selectedColumnNames.value = savedTableColumns.value;
      savedTableColumns.value = null;
    }
  },
  { immediate: true },
);

const queryParams = computed<ThriftStockQueryParams>(() => ({
  tenantId: authStore.tenantId ?? 0,
  page: store.page,
  pageSize: store.pageSize,
  search: store.search,
  status: store.statusFilter,
  condition: store.conditionFilter,
  // Avoid exact COUNT on filtered search; keeps large-tenant typeahead usable.
  skip_count: !!store.search?.trim(),
}));

const { data: stocksQueryData, isLoading: queryLoading, isFetching: queryFetching } = useThriftStocksQuery(queryParams);
const stocks = computed(() => stocksQueryData.value?.data ?? []);
const loading = computed(() => queryLoading.value || queryFetching.value);

// Initialize state from URL query parameters or defaults
const initialPage = Number(route.query.page) || store.page || 1;
const initialLimit = Number(route.query.limit) || store.pageSize || 25;
const initialSearch = (route.query.search as string) ?? store.search ?? '';
const initialStatus = (route.query.status as string) || store.statusFilter || null;
const initialCondition = (route.query.condition as string) || store.conditionFilter || null;

store.setPage(initialPage);
store.setPageSize(initialLimit);
store.setSearch(initialSearch);
store.setStatusFilter(initialStatus);
store.setConditionFilter(initialCondition);

const tablePagination = computed({
  get: () => ({
    page: store.page,
    rowsPerPage: store.pageSize,
    rowsNumber: stocksQueryData.value?.meta?.total ?? 0,
  }),
  set: (val) => {
    store.setPage(val.page);
    store.setPageSize(val.rowsPerPage);
  },
});

watch(
  () => ({
    page: store.page,
    limit: store.pageSize,
    search: store.search,
    status: store.statusFilter,
    condition: store.conditionFilter,
  }),
  (newParams) => {
    const query = { ...route.query };

    if (newParams.page > 1) query.page = String(newParams.page);
    else delete query.page;

    if (newParams.limit !== 25) query.limit = String(newParams.limit);
    else delete query.limit;

    if (newParams.search) query.search = newParams.search;
    else delete query.search;

    if (newParams.status) query.status = newParams.status;
    else delete query.status;

    if (newParams.condition) query.condition = newParams.condition;
    else delete query.condition;

    void router.replace({ query });
  },
  { deep: true },
);

// Toolbar & Filter Drawer state
const searchText = ref(store.search);
const filterDrawerOpen = ref(false);
const statusFilter = ref<string | null>(store.statusFilter);
const conditionFilter = ref<string | null>(store.conditionFilter);
const draftStatusFilter = ref<string | null>(null);
const draftConditionFilter = ref<string | null>(null);

watch(() => store.search, (val) => {
  if (searchText.value !== val) searchText.value = val;
});
watch(searchText, (val) => {
  if (store.search !== val) {
    store.setSearch(val);
    store.setPage(1);
  }
});
watch(() => store.statusFilter, (val) => {
  if (statusFilter.value !== val) statusFilter.value = val;
});
watch(() => store.conditionFilter, (val) => {
  if (conditionFilter.value !== val) conditionFilter.value = val;
});

const activeFilterCount = computed(
  () => (statusFilter.value ? 1 : 0) + (conditionFilter.value ? 1 : 0),
);

function openFilterDrawer() {
  draftStatusFilter.value = statusFilter.value;
  draftConditionFilter.value = conditionFilter.value;
  filterDrawerOpen.value = true;
}

function onApplyDrawerFilters() {
  statusFilter.value = draftStatusFilter.value;
  conditionFilter.value = draftConditionFilter.value;
  filterDrawerOpen.value = false;
  onFiltersChanged();
}

function onResetDrawerFilters() {
  draftStatusFilter.value = null;
  draftConditionFilter.value = null;
}

function onFiltersChanged() {
  store.setSearch(searchText.value);
  store.setStatusFilter(statusFilter.value);
  store.setConditionFilter(conditionFilter.value);
  store.setPage(1);
}

// 1. Setup Forms Composable
const {
  settings,
  categories,
  types,
  boxesList,
  shelves,
  shipments,
  shipmentById,
  purchaseCurrency,
  costCurrency,
  purchaseCurrencySymbol,
  costCurrencySymbol,
  quickAddPurchaseCurrency,
  shipmentPurchaseCurrency,
  shipmentCostCurrency,
  filteredBoxes,
  quickAddFilteredBoxes,
  uploaderCloudinaryFolder,
  dialogOpen,
  editingId,
  quickAddDialogOpen,
  isUploaderOpen,
  uploaderTarget,
  quickSubmitting,
  imageRemoveConfirmOpen,
  actionLoading,
  quickAddForm,
  quickAddBarcodeLoading,
  canSubmitQuickAdd,
  editImage,
  form,
  originUnitPrice,
  extraOriginUnitPrice,
  additionalChargesCost,
  pricing,
  onShipmentChange,
  onQuickShipmentChange,
  getBoxName,
  openAddDialog,
  openEditDialog,
  openEditUploader,
  onQuickAddDialogHide,
  onEditDialogHide,
  onImageSelected,
  removeEditImage,
  submitQuickAdd,
  onSubmit,
  buildPricingFromRow,
} = useThriftStockForms(
  stocks,
  computed(() => costing.costBreakdownByStockId.value),
  computed(() => costing.shipmentStocksCache.value),
  (id) => costing.invalidateShipmentCache(id),
);

// 2. Setup Costing Composable
const costing = useThriftStockCosting(
  stocks,
  shipmentById,
  settings,
  shipmentCostCurrency,
);
const {
  costBreakdownByStockId,
  openMeasurementsDialog,
  openLandedBreakdownDialog,
  itemMarkupPctForRow,
  effectiveMarkupLabel,
} = costing;

// 3. Setup Actions Composable
const {
  selectedStockIds,
  selectedRow,
  deleteConfirmOpen,
  deleteLoading,
  bulkDeleteConfirmOpen,
  bulkDeleteLoading,
  csvExportLoading,
  barcodePreviewOpen,
  previewBarcodeValue,
  previewStockLabel,
  allPageRowsSelected,
  somePageRowsSelected,
  toggleSelectAllPage,
  toggleStockSelection,
  clearStockSelection,
  confirmDelete,
  confirmBulkDelete,
  deleteItem,
  deleteSelectedItems,
  updateStatus,
  holdDialogOpen,
  holdSubmitting,
  holdTarget,
  holdForm,
  openHoldDialog,
  submitHold,
  releaseHold,
  openBarcodePreview,
  copyPreviewBarcode,
  saveStockCell,
  onTextCellSave,
  onSectionSave,
  onConditionSave,
  onBoxSave,
  onNumberCellSave,
  onOriginUnitPriceSave,
  onExtraOriginUnitPriceSave,
  onItemMarkupSave,
  resetItemMarkupToShipment,
  onListedUnitPriceSave,
  resetPriceToSuggested,
  onStatusCellSave,
  downloadStockCsv,
} = useThriftStockActions(
  stocks,
  costBreakdownByStockId,
  computed(() => costing.shipmentStocksCache.value),
  (id) => costing.invalidateShipmentCache(id),
  shipmentById,
  settings,
  boxesList,
  shipmentPurchaseCurrency,
  shipmentCostCurrency,
  buildPricingFromRow,
);
</script>

<style scoped>
.thrift-stock-page {
  background: transparent;
}
</style>
