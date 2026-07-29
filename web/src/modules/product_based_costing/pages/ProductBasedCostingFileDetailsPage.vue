<template>
  <q-page class="q-pa-md costing-details-page">
    <div class="q-gutter-y-md">
      <!-- Top Header Bar Component -->
      <ProductBasedCostingFileHeader
        :file="file ?? null"
        :is-loading="isLoading"
        :backlog-count="backlog.items.value.length"
        :backlog-loading="backlog.loading.value"
        :visible-columns="visibleColumns"
        :all-billing-profiles="allBillingProfiles"
        :loading-profiles="loadingProfiles"
        :saving-billing-profile="savingBillingProfile"
        @go-back="goBack"
        @open-backlog="openBacklogDrawer"
        @open-create-item="openCreateDialog"
        @open-edit-file="showFileDialog = true"
        @open-bulk-paste="openBulkPaste"
        @open-catalog="openCatalogDialog"
        @open-preview="openPreviewAndPrint"
        @download-excel="handleDownloadExcel"
        @update:visible-columns="onVisibleColumnsUpdate"
        @save-inline-name="handleSaveInlineName"
        @update-billing-profile="onInlineBillingProfileChange"
      />

      <template v-if="!isLoading">
        <!-- Workflow Bar Component -->
        <ProductBasedCostingFileWorkflowBar
          :file="file ?? null"
          :is-loading="isLoading"
          :status="status"
          :updating-status="updatingStatus"
          :target-updating-status="targetUpdatingStatus"
          @update-status="onUpdateStatus"
          @save-rates="onRateSave"
        />

        <div v-if="!file" class="text-negative">File not found.</div>

        <!-- Costing Items Table Card -->
        <q-card v-else flat bordered class="q-pa-none costing-items-surface">
          <ProductBasedCostingItemsTable
            ref="itemsTableRef"
            :items="costingItems"
            :cargo-rate="cargoRateValue"
            :conversion-rate="conversionRateValue"
            :profit-rate="profitRateValue"
            :status="file?.status ?? 'pending'"
            :shipped-item-ids="shippedItemIds"
            :visible-columns="visibleColumns"
            @edit="onEdit"
            @delete="onDelete"
            @row-change="onRowChange"
            @product-weight-change="onProductWeightChange"
            @package-weight-change="onPackageWeightChange"
            @bulk-delete="onBulkDelete"
            @update:visible-columns="onVisibleColumnsUpdate"
          />
        </q-card>

        <!-- Summary Metrics Component -->
        <ProductBasedCostingFileSummaryCards
          v-if="costingItems.length"
          :summary-metrics="summaryMetrics"
          :conversion-rate="conversionRateValue"
        />

        <!-- Drawers & Dialogs -->
        <PbcBacklogSuggestDrawer
          v-model="showBacklogDrawer"
          :items="availableBacklogItems"
          :loading="backlog.loading.value"
          :adding="backlog.saving.value"
          @add="handleConsumeBacklog"
        />

        <ProductBasedCostingFileDialog
          v-model="showFileDialog"
          :data="editFormData"
          @submit="handleUpdateFileDialog"
        />

        <ProductBasedCostingItemAddDialog
          v-model="showItemDialog"
          :product-based-costing-file-id="fileId"
          :item-data="selectedItem"
          :default-vendor-code="file?.vendor_code ?? null"
          :default-market-code="file?.market_code ?? null"
          @created="handleCreated"
          @updated="handleUpdated"
        />
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useQuasar } from 'quasar';
import { useRoute, useRouter } from 'vue-router';
import { useQueryClient } from '@tanstack/vue-query';
import ProductBasedCostingFileHeader from '../components/ProductBasedCostingFileHeader.vue';
import ProductBasedCostingFileWorkflowBar from '../components/ProductBasedCostingFileWorkflowBar.vue';
import ProductBasedCostingFileSummaryCards from '../components/ProductBasedCostingFileSummaryCards.vue';
import ProductBasedCostingFileDialog from '../components/ProductBasedCostingFileDialog.vue';
import ProductBasedCostingItemAddDialog from '../components/ProductBasedCostingItemAddDialog.vue';
import PbcBacklogSuggestDrawer from '../components/PbcBacklogSuggestDrawer.vue';
import AddCostingItemsDrawer from '../components/AddCostingItemsDrawer.vue';
import BulkPasteCostingItemsDialog from '../components/BulkPasteCostingItemsDialog.vue';
import ProductBasedCostingPreviewColumnSelectorDialog from '../components/ProductBasedCostingPreviewColumnSelectorDialog.vue';
import ProductBasedCostingItemsTable from '../components/ProductBasedCostingItemsTable.vue';
import { useProductStore } from 'src/modules/products/stores/productStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import type { BillingProfile } from 'src/modules/sales_invoice/repositories/billingProfileRepository';
import { useBillingProfilesQuery } from 'src/modules/sales_invoice/composables/useBillingProfileQuery';
import { productBasedCostingQueryKeys } from '../shared/queryKeys/productBasedCostingQueryKeys';
import { useProductBasedCostingFileDetailQuery } from '../composables/useProductBasedCostingFileDetailQuery';
import { useProductBasedCostingItemsQuery } from '../composables/useProductBasedCostingItemsQuery';
import { useUpdateProductBasedCostingFileMutation } from '../composables/useProductBasedCostingFileMutations';
import {
  useDeleteProductBasedCostingItemMutation,
  useDeleteProductBasedCostingItemsBulkMutation,
  useUpdateProductBasedCostingItemMutation,
  useUpdateProductBasedCostingItemsByFileIdMutation,
  useRecalculateOfferPricesMutation,
} from '../composables/useProductBasedCostingItemMutations';
import type { ProductBasedCostingItem } from '../types';
import { useMembershipColumnPreference } from 'src/modules/membership/composables/useMembershipColumnPreference';
import { usePbcBacklog } from '../composables/usePbcBacklog';
import {
  allColumnNames,
  alwaysVisibleColumns,
  getDefaultVisibleColumnsForStatus,
  useProductBasedCostingFileDetailsState,
} from '../composables/useProductBasedCostingFileDetailsState';

const $q = useQuasar();
const route = useRoute();
const router = useRouter();
const productStore = useProductStore();
const tenantStore = useTenantStore();
const queryClient = useQueryClient();
const backlog = usePbcBacklog();

const showBacklogDrawer = ref(false);
const showFileDialog = ref(false);
const showItemDialog = ref(false);
const selectedItem = ref<ProductBasedCostingItem | null>(null);
const savingBillingProfile = ref(false);

const status = ref<string>('pending');
const updatingStatus = ref(false);
const targetUpdatingStatus = ref<string | null>(null);
const shippedItemIds = ref<number[]>([]);

const fileId = computed(() => {
  const parsed = Number(route.params.id);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
});

// Queries
const { data: file, isLoading: isLoadingFile } = useProductBasedCostingFileDetailQuery(fileId);
const { data: costingItemsData, isLoading: isLoadingItems } = useProductBasedCostingItemsQuery(fileId);

const isLoading = computed(() => isLoadingFile.value || isLoadingItems.value);
const costingItems = computed(() => costingItemsData.value ?? []);

const availableBacklogItems = computed(() => {
  const currentProductIds = new Set(
    costingItems.value
      .map((item) => item.product_id)
      .filter((id): id is number => id != null),
  );
  const currentBarcodes = new Set(
    costingItems.value
      .map((item) => item.barcode?.trim())
      .filter((b): b is string => Boolean(b)),
  );

  return backlog.items.value.filter((item) => {
    if (item.product_id && currentProductIds.has(item.product_id)) {
      return false;
    }
    if (item.barcode && currentBarcodes.has(item.barcode.trim())) {
      return false;
    }
    return true;
  });
});

// Mutations
const updateFileMutation = useUpdateProductBasedCostingFileMutation();
const updateItemMutation = useUpdateProductBasedCostingItemMutation();
const deleteItemMutation = useDeleteProductBasedCostingItemMutation();
const deleteItemsBulkMutation = useDeleteProductBasedCostingItemsBulkMutation();
const updateItemsByFileIdMutation = useUpdateProductBasedCostingItemsByFileIdMutation();
const recalculateOfferPricesMutation = useRecalculateOfferPricesMutation();

// Billing Profiles
const tenantIdRef = computed(() => tenantStore.selectedTenant?.id);
const { data: billingProfilesResult, isLoading: loadingProfiles } = useBillingProfilesQuery(tenantIdRef);
const allBillingProfiles = computed(() => billingProfilesResult.value?.data ?? []);

// Column Preferences
const { visibleColumns } = useMembershipColumnPreference({
  preferenceKey: 'ui.productBasedCosting.fileDetailsVisibleColumns',
  allColumnNames,
  alwaysVisibleColumns,
  defaultVisibleColumns: allColumnNames,
});

const onVisibleColumnsUpdate = (columns: string[]) => {
  visibleColumns.value = columns;
};

// Rates values
const cargoRateValue = computed(() => file.value?.cargo_rate_kg_gbp ?? 0);
const conversionRateValue = computed(() => file.value?.conversion_rate ?? 140);
const profitRateValue = computed(() => file.value?.profit_rate ?? 25);

// Composable State & Logic Helpers
const { summaryMetrics, downloadExcel } = useProductBasedCostingFileDetailsState({
  costingItems,
  cargoRateValue,
  conversionRateValue,
});

watch(
  file,
  (newFile) => {
    if (newFile) {
      status.value = newFile.status || 'pending';
    }
  },
  { immediate: true },
);

const editFormData = computed(() => {
  if (!file.value) return null;
  return {
    id: file.value.id,
    name: file.value.name ?? '',
    order_for: file.value.order_for ?? '',
    billing_profile_id: file.value.billing_profile_id ?? null,
    note: file.value.note ?? '',
    vendor_code: file.value.vendor_code ?? null,
    market_code: file.value.market_code ?? null,
  };
});

async function handleSaveInlineName(name: string) {
  if (!fileId.value) return;
  await updateFileMutation.mutateAsync({
    id: fileId.value,
    name,
  });
}

async function onInlineBillingProfileChange(val: BillingProfile | null) {
  if (!fileId.value || savingBillingProfile.value) return;
  const newProfileId = val?.id ?? null;
  const newOrderFor = val?.name ?? file.value?.order_for ?? '';

  if (newProfileId === file.value?.billing_profile_id && newOrderFor === file.value?.order_for) {
    return;
  }

  savingBillingProfile.value = true;
  try {
    await updateFileMutation.mutateAsync({
      id: fileId.value,
      billing_profile_id: newProfileId,
      order_for: newOrderFor,
    });
    refreshBacklog();
  } finally {
    savingBillingProfile.value = false;
  }
}

async function handleUpdateFileDialog(payload: {
  id: number | null;
  name: string;
  order_for: string;
  billing_profile_id: number | null;
  note: string;
  vendor_code: string | null;
  market_code: string | null;
}) {
  if (!payload.id) return;
  await updateFileMutation.mutateAsync({
    id: payload.id,
    name: payload.name,
    order_for: payload.order_for,
    billing_profile_id: payload.billing_profile_id,
    note: payload.note,
    vendor_code: payload.vendor_code,
    market_code: payload.market_code,
  });
  showFileDialog.value = false;
  refreshBacklog();
}

async function onStatusChange() {
  if (!fileId.value) return;

  await updateFileMutation.mutateAsync({
    id: fileId.value,
    status: status.value,
  });

  visibleColumns.value = getDefaultVisibleColumnsForStatus(status.value);

  if (status.value === 'confirmed' && costingItems.value.length > 0) {
    await updateItemsByFileIdMutation.mutateAsync({
      fileId: fileId.value,
      payload: {
        confirmed_quantity: 0,
      },
    });
  }

  if (status.value === 'offered') {
    await recalculateAndPersistOfferPrices();
  }
}

async function onUpdateStatus(nextStatus: string) {
  if (status.value === nextStatus || updatingStatus.value) return;
  updatingStatus.value = true;
  targetUpdatingStatus.value = nextStatus;
  try {
    status.value = nextStatus;
    await onStatusChange();
  } finally {
    updatingStatus.value = false;
    targetUpdatingStatus.value = null;
  }
}

async function onRateSave(payload: {
  conversion_rate: number | null;
  cargo_rate_kg_gbp: number | null;
  profit_rate: number | null;
}) {
  if (!file.value || !fileId.value) return;
  await updateFileMutation.mutateAsync({
    id: file.value.id,
    conversion_rate: payload.conversion_rate || 0,
    cargo_rate_kg_gbp: payload.cargo_rate_kg_gbp || 0,
    profit_rate: payload.profit_rate || 0,
  });
  await recalculateAndPersistOfferPrices();
}

async function recalculateAndPersistOfferPrices() {
  if (!fileId.value) return;
  await recalculateOfferPricesMutation.mutateAsync(fileId.value);
}

function refreshBacklog() {
  const tenantId = tenantStore.selectedTenant?.id;
  const profileId = file.value?.billing_profile_id;
  if (tenantId && profileId) {
    void backlog.fetchBacklogItems(tenantId, profileId);
  }
}

function openBacklogDrawer() {
  refreshBacklog();
  showBacklogDrawer.value = true;
}

async function handleConsumeBacklog(backlogIds: number[]) {
  if (!fileId.value) return;
  const addedIds = await backlog.consumeBacklogItems(fileId.value, backlogIds);
  if (addedIds.length > 0) {
    void queryClient.invalidateQueries({
      queryKey: productBasedCostingQueryKeys.itemsList(fileId.value),
    });
    refreshBacklog();
    showBacklogDrawer.value = false;
  }
}

function handleCreated() {
  if (!fileId.value) return;
  void queryClient.invalidateQueries({
    queryKey: productBasedCostingQueryKeys.itemsList(fileId.value),
  });
  refreshBacklog();
}

function openCreateDialog() {
  selectedItem.value = null;
  showItemDialog.value = true;
}

function onEdit(item: ProductBasedCostingItem) {
  selectedItem.value = item;
  showItemDialog.value = true;
}

async function onDelete(item: ProductBasedCostingItem) {
  await deleteItemMutation.mutateAsync(item.id);
}

async function onBulkDelete(ids: number[]) {
  if (!ids.length || !fileId.value) return;
  await deleteItemsBulkMutation.mutateAsync({
    fileId: fileId.value,
    ids,
  });
  refreshBacklog();
}

const itemsTableRef = ref<InstanceType<typeof ProductBasedCostingItemsTable> | null>(null);

type RowChangePayload = {
  item: ProductBasedCostingItem;
  row: unknown;
  field: string;
};

async function onRowChange(payload: RowChangePayload) {
  try {
    await updateItemMutation.mutateAsync({
      id: payload.item.id,
      quantity: payload.item.quantity,
      confirmed_quantity: payload.item.confirmed_quantity ?? null,
      ordered_quantity: payload.item.ordered_quantity ?? null,
      delivered_quantity: payload.item.delivered_quantity,
      offer_price: payload.item.offer_price,
      is_offer_price_manual: payload.item.is_offer_price_manual ?? false,
      product_weight: payload.item.product_weight,
      package_weight: payload.item.package_weight,
      note: payload.item.note,
    });
  } catch {
    if (fileId.value) {
      await queryClient.refetchQueries({
        queryKey: productBasedCostingQueryKeys.itemsList(fileId.value),
      });
    }
    itemsTableRef.value?.resetRows();
  }
}

function openCatalogDialog() {
  if (!fileId.value) return;
  $q.dialog({
    component: AddCostingItemsDrawer,
    componentProps: { fileId: fileId.value },
  }).onOk(() => {
    void queryClient.invalidateQueries({
      queryKey: productBasedCostingQueryKeys.itemsList(fileId.value),
    });
    refreshBacklog();
  });
}

function openBulkPaste() {
  if (!costingItems.value.length) {
    $q.notify({ type: 'warning', message: 'No costing items to update.' });
    return;
  }
  $q.dialog({ component: BulkPasteCostingItemsDialog });
}

function openPreviewAndPrint() {
  if (!fileId.value) return;
  $q.dialog({
    component: ProductBasedCostingPreviewColumnSelectorDialog,
  }).onOk((res: { visibleColumns?: string[] }) => {
    if (!fileId.value) return;
    const cols = res?.visibleColumns ?? [];
    const previewRoute = router.resolve({
      name: 'product-based-costing-file-preview-page',
      params: { id: fileId.value },
      ...(cols.length ? { query: { cols: cols.join(',') } } : {}),
    });
    window.open(previewRoute.href, '_blank', 'noopener');
  });
}

function handleDownloadExcel() {
  void downloadExcel($q, file.value ?? null, costingItems.value);
}

function handleUpdated() {
  return;
}

type WeightChangePayload = {
  item: ProductBasedCostingItem;
  row: unknown;
  field: 'product_weight' | 'package_weight';
};

async function onProductWeightChange(payload: WeightChangePayload) {
  try {
    if (payload.item.product_id) {
      const res = await productStore.updateProduct({
        id: payload.item.product_id,
        product_weight: payload.item.product_weight,
      });
      if (res && 'success' in res && !res.success) {
        throw new Error(res.error || 'Failed to update product weight.');
      }
    }
    await updateItemMutation.mutateAsync({
      id: payload.item.id,
      product_weight: payload.item.product_weight,
      offer_price: payload.item.offer_price,
    });
  } catch {
    if (fileId.value) {
      await queryClient.refetchQueries({
        queryKey: productBasedCostingQueryKeys.itemsList(fileId.value),
      });
    }
    itemsTableRef.value?.resetRows();
  }
}

async function onPackageWeightChange(payload: WeightChangePayload) {
  try {
    if (payload.item.product_id) {
      const res = await productStore.updateProduct({
        id: payload.item.product_id,
        package_weight: payload.item.package_weight,
      });
      if (res && 'success' in res && !res.success) {
        throw new Error(res.error || 'Failed to update package weight.');
      }
    }
    await updateItemMutation.mutateAsync({
      id: payload.item.id,
      package_weight: payload.item.package_weight,
      offer_price: payload.item.offer_price,
    });
  } catch {
    if (fileId.value) {
      await queryClient.refetchQueries({
        queryKey: productBasedCostingQueryKeys.itemsList(fileId.value),
      });
    }
    itemsTableRef.value?.resetRows();
  }
}

function goBack() {
  void router.push({ name: 'product-based-costing-page' });
}
</script>

<style scoped lang="scss">
.costing-details-page {
  background: transparent;
}

.costing-items-surface {
  overflow: hidden;
}
</style>
