<template>
  <q-page class="q-pa-sm costing-details-page">
    <div class="q-gutter-y-sm">
      <!-- Top Header Bar Component -->
      <ProductBasedCostingFileHeader
        :file="file ?? null"
        :is-loading="isLoading"
        :visible-columns="visibleColumns"
        :all-billing-profiles="allBillingProfiles"
        :loading-profiles="loadingProfiles"
        :saving-billing-profile="savingBillingProfile"
        :item-count="costingItems.length"
        @go-back="goBack"
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

      <q-banner
        v-if="!isLoading && file && availableBacklogItems.length"
        dense
        class="bg-orange-1 text-grey-9 rounded-borders"
      >
        <template #avatar>
          <q-icon name="ph ph-tray" color="orange-9" />
        </template>
        {{ stillNeededBannerText }}
        <template #action>
          <q-btn
            flat
            dense
            no-caps
            color="primary"
            :label="$t('product_based_costing.review')"
            @click="openBacklogDrawer"
          />
          <q-btn
            unelevated
            dense
            no-caps
            color="primary"
            :label="$t('product_based_costing.add_all')"
            :loading="backlog.saving.value"
            @click="handleAddAllStillNeeded"
          />
        </template>
      </q-banner>

      <q-banner
        v-if="!isLoading && file && nextStepBanner"
        dense
        class="bg-primary-soft text-primary rounded-borders"
      >
        {{ nextStepBanner }}
      </q-banner>

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

        <div v-if="!file" class="text-negative">{{ $t('product_based_costing.file_not_found') }}</div>

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
          :already-on-file-items="alreadyOnFileBacklogItems"
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
import { useI18n } from 'vue-i18n';
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
  useRecalculateOfferPricesMutation,
} from '../composables/useProductBasedCostingItemMutations';
import { productBasedCostingRepository } from '../repositories/productBasedCostingRepository';
import type { ProductBasedCostingItem } from '../types';
import { useMembershipColumnPreference } from 'src/modules/membership/composables/useMembershipColumnPreference';
import { usePbcBacklog, type BacklogItem } from '../composables/usePbcBacklog';
import {
  allColumnNames,
  alwaysVisibleColumns,
  quoteVisibleColumns,
  getDefaultVisibleColumnsForStatus,
  normalizePbcFileStatus,
  useProductBasedCostingFileDetailsState,
} from '../composables/useProductBasedCostingFileDetailsState';

const $q = useQuasar();
const { t } = useI18n();
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

function isBacklogItemOnCurrentFile(item: BacklogItem) {
  if (item.product_id && costingItems.value.some((row) => row.product_id === item.product_id)) {
    return true;
  }
  const barcode = item.barcode?.trim();
  if (barcode && costingItems.value.some((row) => row.barcode?.trim() === barcode)) {
    return true;
  }
  return false;
}

const availableBacklogItems = computed(() =>
  backlog.items.value.filter((item) => !isBacklogItemOnCurrentFile(item)),
);

const alreadyOnFileBacklogItems = computed(() =>
  backlog.items.value.filter((item) => isBacklogItemOnCurrentFile(item)),
);

const stillNeededBannerText = computed(() => {
  const count = availableBacklogItems.value.length;
  return count === 1
    ? t('product_based_costing.still_needed_one')
    : t('product_based_costing.still_needed', { count });
});

const nextStepBanner = computed(() => {
  if (!file.value) return '';
  if (costingItems.value.length === 0) {
    if (availableBacklogItems.value.length > 0) return '';
    return t('product_based_costing.next_empty');
  }
  if (status.value === 'pending') return t('product_based_costing.next_pending');
  if (status.value === 'offered') return t('product_based_costing.next_offered');
  if (status.value === 'confirmed') return t('product_based_costing.next_confirmed');
  if (status.value === 'procuring') return t('product_based_costing.next_procuring');
  return '';
});

// Mutations
const updateFileMutation = useUpdateProductBasedCostingFileMutation();
const updateItemMutation = useUpdateProductBasedCostingItemMutation();
const deleteItemMutation = useDeleteProductBasedCostingItemMutation();
const deleteItemsBulkMutation = useDeleteProductBasedCostingItemsBulkMutation();
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
  defaultVisibleColumns: quoteVisibleColumns,
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
      status.value = normalizePbcFileStatus(newFile.status || 'pending');
      const saved = visibleColumns.value;
      const isLegacyAll =
        saved.length === allColumnNames.length &&
        allColumnNames.every((col) => saved.includes(col));
      if (isLegacyAll) {
        visibleColumns.value = getDefaultVisibleColumnsForStatus(status.value);
      } else if (status.value === 'confirmed') {
        const mustHave = ['confirmedQty', 'offerPriceBdt', 'priceGbp', 'profitRate', 'costBdt', 'status'];
        const missing = mustHave.filter((col) => !saved.includes(col));
        if (missing.length) {
          visibleColumns.value = [...saved, ...missing];
        }
      } else if (status.value === 'procuring') {
        const mustHave = ['confirmedQty', 'status'];
        const missing = mustHave.filter((col) => !saved.includes(col));
        if (missing.length) {
          visibleColumns.value = [...saved, ...missing];
        }
      }
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
    await Promise.all(
      costingItems.value.map((item) =>
        productBasedCostingRepository.updateProductBasedCostingItem({
          id: item.id,
          confirmed_quantity: item.quantity ?? 0,
        }),
      ),
    );
    await queryClient.invalidateQueries({
      queryKey: productBasedCostingQueryKeys.itemsList(fileId.value),
    });
  }

  if (status.value === 'offered') {
    await recalculateAndPersistOfferPrices();
  }
}

async function applyStatus(nextStatus: string) {
  if (status.value === nextStatus || updatingStatus.value) return;
  updatingStatus.value = true;
  targetUpdatingStatus.value = nextStatus;
  try {
    status.value = nextStatus;
    await onStatusChange();
    if (nextStatus === 'offered' && costingItems.value.length > 0) {
      $q.dialog({
        title: t('product_based_costing.status_offered'),
        message: t('product_based_costing.offered_dialog_message'),
        cancel: { label: t('product_based_costing.not_now'), flat: true },
        ok: { label: t('product_based_costing.open_offer'), unelevated: true, color: 'primary' },
      }).onOk(() => {
        openPreviewAndPrint();
      });
    }
  } finally {
    updatingStatus.value = false;
    targetUpdatingStatus.value = null;
  }
}

function onUpdateStatus(nextStatus: string) {
  if (status.value === nextStatus || updatingStatus.value) return;
  if (nextStatus === 'confirmed') {
    $q.dialog({
      title: t('product_based_costing.confirm_order_title'),
      message: t('product_based_costing.confirm_order_message'),
      cancel: { label: t('product_based_costing.cancel'), flat: true },
      ok: { label: t('product_based_costing.confirm_order'), unelevated: true, color: 'primary' },
    }).onOk(() => {
      void applyStatus(nextStatus);
    });
    return;
  }
  void applyStatus(nextStatus);
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

async function handleAddAllStillNeeded() {
  const ids = availableBacklogItems.value.map((item) => item.id);
  await handleConsumeBacklog(ids);
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

function openCreateDialog(name?: string) {
  const prefill = typeof name === 'string' ? name.trim() : '';
  selectedItem.value = prefill ? ({ name: prefill } as ProductBasedCostingItem) : null;
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
    if (payload.field === 'price_gbp' && payload.item.product_id) {
      const res = await productStore.updateProduct({
        id: payload.item.product_id,
        list_price_amount: payload.item.price_gbp,
      });
      if (res && 'success' in res && !res.success) {
        throw new Error(res.error || t('product_based_costing.update_price_failed'));
      }
    }
    await updateItemMutation.mutateAsync({
      id: payload.item.id,
      quantity: payload.item.quantity,
      confirmed_quantity: payload.item.confirmed_quantity ?? null,
      price_gbp: payload.item.price_gbp,
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
  }).onOk((result?: { createProductName?: string }) => {
    void queryClient.invalidateQueries({
      queryKey: productBasedCostingQueryKeys.itemsList(fileId.value),
    });
    refreshBacklog();
    if (result?.createProductName != null) {
      openCreateDialog(result.createProductName);
    }
  });
}

function openBulkPaste() {
  if (!costingItems.value.length) {
    $q.notify({ type: 'warning', message: t('product_based_costing.no_items_to_update') });
    return;
  }
  $q.dialog({ component: BulkPasteCostingItemsDialog });
}

function openPreviewDialog() {
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

function openPreviewAndPrint() {
  if (!fileId.value) return;
  const incompleteCount = costingItems.value.filter((item) => {
    const price = Number(item.price_gbp ?? 0);
    const weight = Number(item.product_weight ?? 0);
    return !(price > 0) || !(weight > 0);
  }).length;
  const cargoZero = cargoRateValue.value <= 0;
  if (incompleteCount > 0 || cargoZero) {
    const parts = [
      cargoZero ? t('product_based_costing.cargo_rate_zero') : '',
      incompleteCount === 1
        ? t('product_based_costing.incomplete_item_one')
        : incompleteCount > 0
          ? t('product_based_costing.incomplete_items', { count: incompleteCount })
          : '',
    ].filter(Boolean);
    $q.dialog({
      title: t('product_based_costing.offer_incomplete_title'),
      message: parts.join(' '),
      cancel: { label: t('product_based_costing.go_back'), flat: true },
      ok: { label: t('product_based_costing.open_anyway'), unelevated: true, color: 'primary' },
    }).onOk(() => openPreviewDialog());
    return;
  }
  openPreviewDialog();
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
        throw new Error(res.error || t('product_based_costing.update_product_weight_failed'));
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
        throw new Error(res.error || t('product_based_costing.update_package_weight_failed'));
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

.bg-primary-soft {
  background: var(--bw-theme-primary-soft, rgb(37 99 235 / 0.12));
}
</style>
