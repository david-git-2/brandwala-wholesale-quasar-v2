<template>
  <q-page class="q-pa-md costing-details-page">
    <PageInitialLoader v-if="store.loading" />
    <template v-else>
      <div class="q-gutter-y-md">
        <section class="row items-center justify-between q-col-gutter-md">
          <div class="col">
            <div class="row items-center q-gutter-x-sm">
              <q-btn flat dense icon="arrow_back" color="grey-7" @click="goBack" />
              <div>
                <div class="text-overline text-primary">Product Based Costing</div>
                <h1 class="text-h5 text-weight-bold q-my-none">
                  {{ store?.item?.name ?? 'Costing File' }}
                </h1>
                <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
                  Created for {{ store?.item?.order_for ?? '-' }}
                </p>
              </div>
            </div>
          </div>
          <div class="col-auto row q-gutter-sm items-center">
            <q-btn
              color="primary"
              unelevated
              no-caps
              label="Add Item"
              @click="openCreateDialog"
            />
            <q-btn flat dense icon="more_vert" aria-label="Actions">
              <q-menu style="min-width: 200px">
                <q-list dense>
                  <q-item clickable v-close-popup @click="openBulkPaste">
                    <q-item-section avatar>
                      <q-icon name="content_paste" />
                    </q-item-section>
                    <q-item-section>Bulk Paste</q-item-section>
                  </q-item>
                  <q-item clickable v-close-popup @click="openCatalogDialog">
                    <q-item-section avatar>
                      <q-icon name="shopping_cart" />
                    </q-item-section>
                    <q-item-section>Add from Catalog</q-item-section>
                  </q-item>
                  <q-item clickable>
                    <q-item-section avatar>
                      <q-icon name="view_column" />
                    </q-item-section>
                    <q-item-section>Columns</q-item-section>
                    <q-item-section side>
                      <q-icon name="keyboard_arrow_right" />
                    </q-item-section>
                    <q-menu anchor="top end" self="top start">
                      <q-list style="min-width: 240px">
                        <q-item>
                          <q-item-section>
                            <div class="text-subtitle2">Show Columns</div>
                          </q-item-section>
                        </q-item>
                        <q-item clickable>
                          <q-item-section>
                            <q-checkbox
                              v-model="allSelectableColumnsSelected"
                              label="Select / Deselect All"
                            />
                          </q-item-section>
                        </q-item>
                        <q-item>
                          <q-item-section>
                            <q-option-group
                              v-model="visibleColumns"
                              type="checkbox"
                              :options="columnSelectorOptions"
                            />
                          </q-item-section>
                        </q-item>
                      </q-list>
                    </q-menu>
                  </q-item>
                  <q-separator />
                  <q-item
                    clickable
                    v-close-popup
                    :disable="status === 'pending'"
                    @click="openPreview"
                  >
                    <q-item-section avatar>
                      <q-icon name="visibility" />
                    </q-item-section>
                    <q-item-section>Preview</q-item-section>
                  </q-item>
                  <q-item clickable v-close-popup @click="openPrintPage">
                    <q-item-section avatar>
                      <q-icon name="picture_as_pdf" />
                    </q-item-section>
                    <q-item-section>PDF</q-item-section>
                  </q-item>
                  <q-item clickable v-close-popup @click="downloadExcel">
                    <q-item-section avatar>
                      <q-icon name="table_view" />
                    </q-item-section>
                    <q-item-section>Download Excel</q-item-section>
                  </q-item>
                </q-list>
              </q-menu>
            </q-btn>
          </div>
        </section>

        <q-card v-if="store.item" flat bordered class="q-pa-sm">
          <div class="row items-center justify-between q-col-gutter-sm">
            <div class="col-grow row items-center q-gutter-xs status-workflow-row">
              <template v-for="(st, idx) in workflowStatuses" :key="st">
                <q-btn
                  :color="status === st ? getStatusColor(st) : isPassedStatus(st) ? 'grey-5' : 'grey-3'"
                  :text-color="status === st ? 'white' : isPassedStatus(st) ? 'grey-9' : 'grey-7'"
                  :outline="status !== st"
                  :unelevated="status === st"
                  dense
                  no-caps
                  class="q-px-md text-caption text-weight-bold"
                  :loading="updatingStatus && targetUpdatingStatus === st"
                  :disable="updatingStatus && targetUpdatingStatus !== st"
                  @click="onUpdateStatus(st)"
                >
                  <q-icon
                    v-if="status === st"
                    name="check_circle"
                    size="14px"
                    class="q-mr-xs"
                  />
                  {{ formatStatusLabel(st) }}
                </q-btn>
                <q-icon
                  v-if="idx < workflowStatuses.length - 1"
                  name="chevron_right"
                  color="grey-5"
                  size="18px"
                  class="status-workflow-chevron"
                />
              </template>
              <q-separator vertical class="q-mx-sm status-workflow-sep" />
              <q-btn
                :color="status === 'cancelled' ? 'negative' : 'grey-3'"
                :text-color="status === 'cancelled' ? 'white' : 'grey-7'"
                :outline="status !== 'cancelled'"
                :unelevated="status === 'cancelled'"
                dense
                no-caps
                class="q-px-md text-caption text-weight-bold"
                :loading="updatingStatus && targetUpdatingStatus === 'cancelled'"
                :disable="updatingStatus && targetUpdatingStatus !== 'cancelled'"
                @click="onUpdateStatus('cancelled')"
              >
                <q-icon
                  v-if="status === 'cancelled'"
                  name="cancel"
                  size="14px"
                  class="q-mr-xs"
                />
                Cancelled
              </q-btn>
            </div>

            <div class="col-auto row items-center q-gutter-sm">
              <div v-if="!ratesExpanded" class="text-caption text-grey-7 rates-summary">
                {{ ratesSummary }}
              </div>
              <q-btn
                flat
                dense
                no-caps
                color="primary"
                :icon="ratesExpanded ? 'expand_less' : 'tune'"
                :label="ratesExpanded ? 'Hide Rates' : 'Rates'"
                @click="ratesExpanded = !ratesExpanded"
              />
            </div>
          </div>

          <div v-if="ratesExpanded" class="row items-end q-col-gutter-sm q-mt-sm">
            <div class="col-12 col-sm-6 col-md-3">
              <q-input
                v-model.number="conversion_rate"
                dense
                outlined
                type="number"
                class="soft-input"
                label="Conversion Rate"
              />
            </div>
            <div class="col-12 col-sm-6 col-md-3">
              <q-input
                v-model.number="cargo_rate_kg_gbp"
                dense
                outlined
                type="number"
                class="soft-input"
                label="Cargo Rate (kg/GBP)"
              />
            </div>
            <div class="col-12 col-sm-6 col-md-3">
              <q-input
                v-model.number="profit_rate"
                dense
                outlined
                type="number"
                class="soft-input"
                label="Profit Rate"
              />
            </div>
            <div class="col-12 col-sm-6 col-md-3">
              <q-btn
                color="primary"
                unelevated
                no-caps
                dense
                class="full-width"
                label="Save Rates"
                @click="onRateSave"
              />
            </div>
          </div>
        </q-card>

        <div v-if="!store.item" class="text-negative">File not found.</div>
        <div v-else-if="!store.costingItems.length" class="text-grey-7 q-pa-md">
          No items found.
        </div>
        <q-card v-else flat bordered class="q-pa-none costing-items-surface">
          <ProductBasedCostingItemsTable
            :items="store.costingItems"
            :cargo-rate="cargoRateValue"
            :conversion-rate="conversionRateValue"
            :profit-rate="profitRateValue"
            :status="store.item?.status ?? 'pending'"
            :shipped-item-ids="shippedItemIds"
            :visible-columns="visibleColumns"
            @edit="onEdit"
            @delete="onDelete"
            @ship="onShip"
            @row-change="onRowChange"
            @product-weight-change="onProductWeightChange"
            @package-weight-change="onPackageWeightChange"
            @bulk-delete="onBulkDelete"
            @update:visible-columns="onVisibleColumnsUpdate"
          />
        </q-card>

        <ProductBasedCostingItemAddDialog
          v-model="showItemDialog"
          :product-based-costing-file-id="fileId"
          :item-data="selectedItem"
          :default-vendor-code="store.item?.vendor_code ?? null"
          :default-market-code="store.item?.market_code ?? null"
          @created="handleCreated"
          @updated="handleUpdated"
        />

        <ShipmentItemCompactDialog
          v-model="showAddShipmentDialog"
          :quantity="selectedQuantity"
          :price-gbp="selectedPriceGbp"
          :loading="shipmentStore.saving"
          :default-shipment-id="
            (store.item?.default_shipment_id as number | null | undefined) ?? null
          "
          @shipment-change="onDefaultShipmentChange"
          @save="onSaveShipment"
        />

        <q-dialog v-model="confirmRemoveShipmentOpen">
          <q-card style="min-width: 360px">
            <q-card-section class="text-h6">Remove From Shipment?</q-card-section>
            <q-card-section> This will remove the selected item from its shipment. </q-card-section>
            <q-card-actions align="right">
              <q-btn flat label="Cancel" v-close-popup />
              <q-btn
                color="negative"
                label="Remove"
                :loading="shipmentStore.saving"
                @click="onConfirmRemoveShipment"
              />
            </q-card-actions>
          </q-card>
        </q-dialog>
      </div>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useQuasar } from 'quasar';
import { useRoute, useRouter } from 'vue-router';
import { useProductBasedCostingStore } from '../stores/productBasedCostingStore';
import ProductBasedCostingItemAddDialog from '../components/ProductBasedCostingItemAddDialog.vue';
import AddCostingItemsDrawer from '../components/AddCostingItemsDrawer.vue';
import BulkPasteCostingItemsDialog from '../components/BulkPasteCostingItemsDialog.vue';
import ProductBasedCostingItemsTable from '../components/ProductBasedCostingItemsTable.vue';
import PageInitialLoader from 'src/components/PageInitialLoader.vue';
import { useProductStore } from 'src/modules/products/stores/productStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { useGlobalShipmentStore } from 'src/modules/procurement_stock/stores/globalShipmentStore';
import { globalShipmentRepository } from 'src/modules/procurement_stock/repositories/globalShipmentRepository';
import ShipmentItemCompactDialog from 'src/modules/procurement_stock/components/ShipmentItemCompactDialog.vue';
import type { ProductBasedCostingItem } from '../types';
import { productBasedCostingService } from '../services/productBasedCostingService';
import { calculateOfferPriceBdt, toNumberSafe } from '../utils/pricing';
import { buildCostingExcelWorkbook } from '../utils/buildCostingExcelWorkbook';
import { useMembershipColumnPreference } from 'src/modules/membership/composables/useMembershipColumnPreference';
const productStore = useProductStore();
const shipmentStore = useGlobalShipmentStore();
const tenantStore = useTenantStore();
const $q = useQuasar();

const route = useRoute();
const router = useRouter();
const store = useProductBasedCostingStore();

const cargo_rate_kg_gbp = ref<number | null>(null);
const conversion_rate = ref<number | null>(null);
const profit_rate = ref<number | null>(null);
const ratesExpanded = ref(false);
const status = ref<string>('pending');
const updatingStatus = ref(false);
const targetUpdatingStatus = ref<string | null>(null);
const showAddShipmentDialog = ref(false);
const selectedQuantity = ref<number | null>(null);
const selectedPriceGbp = ref<number | null>(null);
const selectedShipItem = ref<ProductBasedCostingItem | null>(null);
const shippedItemIds = ref<number[]>([]);
const confirmRemoveShipmentOpen = ref(false);
const pendingRemoveShipItem = ref<ProductBasedCostingItem | null>(null);
const alwaysVisibleColumns = ['select', 'sl', 'image', 'name'];
const allColumnNames = [
  'select',
  'sl',
  'image',
  'name',
  'brand',
  'note',
  'qty',
  'deliveredQty',
  'barcodeText',
  'website',
  'priceGbp',
  'totalPurchasePriceGbp',
  'productWeight',
  'packageWeight',
  'totalWeight',
  'cargoRate',
  'cargoCostGbp',
  'totalCostGbp',
  'rowTotalCostGbp',
  'costBdt',
  'totalCostBdt',
  'offerPriceBdt',
  'totalBdt',
  'profitPerUnitBdt',
  'profitBdt',
  'profitRate',
  'status',
  'action',
];
const { visibleColumns } = useMembershipColumnPreference({
  preferenceKey: 'ui.productBasedCosting.fileDetailsVisibleColumns',
  allColumnNames,
  alwaysVisibleColumns,
  defaultVisibleColumns: allColumnNames,
});
const columnSelectorOptions = [
  { label: 'Brand', value: 'brand' },
  { label: 'Note', value: 'note' },
  { label: 'Qty', value: 'qty' },
  { label: 'Delivered Qty', value: 'deliveredQty' },
  { label: 'Barcode / Code / Product ID', value: 'barcodeText' },
  { label: 'Website', value: 'website' },
  { label: 'Price (GBP)/Unit', value: 'priceGbp' },
  { label: 'Total Purchase Price (GBP)', value: 'totalPurchasePriceGbp' },
  { label: 'Product Wt (g/Unit)', value: 'productWeight' },
  { label: 'Package Wt (g/Unit)', value: 'packageWeight' },
  { label: 'Total Wt (g/Unit)', value: 'totalWeight' },
  { label: 'Cargo Rate', value: 'cargoRate' },
  { label: 'Cargo Cost (GBP/Unit)', value: 'cargoCostGbp' },
  { label: 'Total Cost (GBP/Unit)', value: 'totalCostGbp' },
  { label: 'Row Total Cost (GBP)', value: 'rowTotalCostGbp' },
  { label: 'Cost (BDT/Unit)', value: 'costBdt' },
  { label: 'Row Total Cost (BDT)', value: 'totalCostBdt' },
  { label: 'Offer Price (BDT/Unit)', value: 'offerPriceBdt' },
  { label: 'Row Offer Total (BDT)', value: 'totalBdt' },
  { label: 'Profit (BDT/Unit)', value: 'profitPerUnitBdt' },
  { label: 'Row Total Profit (BDT)', value: 'profitBdt' },
  { label: 'Profit Rate (%)', value: 'profitRate' },
  { label: 'Status', value: 'status' },
  { label: 'Action', value: 'action' },
];
const selectableColumnValues = columnSelectorOptions.map((option) => option.value);
const allSelectableColumnsSelected = computed({
  get: () => selectableColumnValues.every((value) => visibleColumns.value.includes(value)),
  set: (checked: boolean) => {
    visibleColumns.value = checked
      ? [...alwaysVisibleColumns, ...selectableColumnValues]
      : [...alwaysVisibleColumns];
  },
});
const onVisibleColumnsUpdate = (columns: string[]) => {
  visibleColumns.value = columns;
};
const cargoRateValue = computed(() => cargo_rate_kg_gbp.value ?? 0);
const conversionRateValue = computed(() => conversion_rate.value ?? 140);
const profitRateValue = computed(() => profit_rate.value ?? 25);
const ratesSummary = computed(
  () =>
    `Conv ${conversionRateValue.value} · Cargo ${cargoRateValue.value} · Profit ${profitRateValue.value}%`,
);
const fileId = computed(() => {
  const parsed = Number(route.params.id);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
});

const onStatusChange = async () => {
  if (!fileId.value) {
    return;
  }

  const fileUpdateResult = await store.updateProductBasedCostingFile({
    id: fileId.value,
    status: status.value,
  });

  if (!fileUpdateResult?.success || status.value !== 'offered') {
    return;
  }

  await recalculateAndPersistOfferPrices();
};

const workflowStatuses = [
  'pending',
  'offered',
  'processing',
  'ordered',
  'invoicing',
  'invoiced',
] as const;

const formatStatusLabel = (value: string) =>
  value.replace(/_/g, ' ').replace(/\b\w/g, (char) => char.toUpperCase());

const isPassedStatus = (st: string) => {
  if (status.value === 'cancelled') {
    return false;
  }
  const currentIdx = workflowStatuses.indexOf(status.value as (typeof workflowStatuses)[number]);
  const targetIdx = workflowStatuses.indexOf(st as (typeof workflowStatuses)[number]);
  return currentIdx > -1 && targetIdx > -1 && targetIdx < currentIdx;
};

const getStatusColor = (st: string) => {
  switch (st) {
    case 'pending':
      return 'orange-8';
    case 'offered':
      return 'blue-8';
    case 'processing':
      return 'teal-8';
    case 'ordered':
      return 'light-blue-9';
    case 'invoicing':
      return 'indigo-8';
    case 'invoiced':
      return 'green-8';
    case 'cancelled':
      return 'negative';
    default:
      return 'primary';
  }
};

const onUpdateStatus = async (nextStatus: string) => {
  if (status.value === nextStatus || updatingStatus.value) {
    return;
  }
  updatingStatus.value = true;
  targetUpdatingStatus.value = nextStatus;
  try {
    status.value = nextStatus;
    await onStatusChange();
  } finally {
    updatingStatus.value = false;
    targetUpdatingStatus.value = null;
  }
};

const recalculateAndPersistOfferPrices = async () => {
  if (!fileId.value) {
    return;
  }

  const cargoRate = cargoRateValue.value;
  const conversionRate = conversionRateValue.value;
  const profitRate = profitRateValue.value;

  const updates = (store.costingItems ?? []).map((item) => {
    const nextOfferPrice = calculateOfferPriceBdt({
      priceGbp: toNumberSafe(item.price_gbp),
      productWeight: toNumberSafe(item.product_weight),
      packageWeight: toNumberSafe(item.package_weight),
      cargoRate,
      conversionRate,
      profitRate,
    });

    return productBasedCostingService.updateProductBasedCostingItem({
      id: item.id,
      offer_price: nextOfferPrice,
    });
  });

  await Promise.allSettled(updates);
  await store.fetchProductBasedCostingItems(fileId.value);
};

const loadData = async () => {
  if (!fileId.value) {
    return;
  }

  await Promise.all([
    store.fetchProductBasedCostingFileById(fileId.value),
    store.fetchProductBasedCostingItems(fileId.value),
  ]);
};

const handleCreated = async () => {
  if (!fileId.value) {
    return;
  }

  // Keep store in sync with backend using a single items fetch.
  // Avoid shipment refresh here because it fans out into many API calls.
  await store.fetchProductBasedCostingItems(fileId.value);
};

onMounted(async () => {
  await loadData();
  const tenantId = tenantStore.selectedTenant?.id;
  if (tenantId) {
    await shipmentStore.fetchShipments(tenantId);
  }
  refreshShippedItemIndicators();

  cargo_rate_kg_gbp.value = store.item?.cargo_rate_kg_gbp ?? null;
  conversion_rate.value = store.item?.conversion_rate ?? null;
  profit_rate.value = store.item?.profit_rate ?? null;
  status.value = store.item?.status || 'pending';
});

watch(
  () => route.params.id,
  async (newId, oldId) => {
    if (newId === oldId) {
      return;
    }
    await loadData();
    refreshShippedItemIndicators();
  },
);

const onEdit = (item: ProductBasedCostingItem) => {
  console.log('edit', item);
  openEditDialog(item);
};

const onDelete = async (item: ProductBasedCostingItem) => {
  console.log('delete', item);
  await store.deleteProductBasedCostingItem(item.id);
};

const onBulkDelete = async (ids: number[]) => {
  if (!ids.length) {
    return;
  }

  const results = await Promise.allSettled(
    ids.map((id) => productBasedCostingService.deleteProductBasedCostingItem(id)),
  );

  const failedCount = results.filter(
    (result) =>
      result.status === 'rejected' || (result.status === 'fulfilled' && !result.value.success),
  ).length;

  await store.fetchProductBasedCostingItems(fileId.value);
  refreshShippedItemIndicators();

  if (failedCount > 0) {
    $q.notify({
      type: 'warning',
      message: `${ids.length - failedCount} item(s) deleted, ${failedCount} failed.`,
    });
    return;
  }

  $q.notify({
    type: 'positive',
    message: `${ids.length} item(s) deleted successfully.`,
  });
};

type RowChangePayload = {
  item: ProductBasedCostingItem;
  row: unknown;
  field: 'quantity' | 'offer_price' | 'status' | 'note' | 'delivered_quantity';
};

type WeightChangePayload = {
  item: ProductBasedCostingItem;
  row: unknown;
  field: 'product_weight' | 'package_weight';
};

const onRowChange = async (payload: RowChangePayload) => {
  await store.updateProductBasedCostingItem(payload.item);
  console.log('Row changed:', payload);
};

const showItemDialog = ref(false);
const selectedItem = ref<ProductBasedCostingItem | null>(null);

const openCreateDialog = () => {
  console.log('Opening create dialog');
  selectedItem.value = null;
  showItemDialog.value = true;
};

const openCatalogDialog = () => {
  if (!fileId.value) return;

  $q.dialog({
    component: AddCostingItemsDrawer,
    componentProps: { fileId: fileId.value },
  }).onOk(() => {
    void store.fetchProductBasedCostingItems(fileId.value!);
  });
};

const openBulkPaste = () => {
  if (!store.costingItems.length) {
    $q.notify({ type: 'warning', message: 'No costing items to update.' });
    return;
  }

  $q.dialog({
    component: BulkPasteCostingItemsDialog,
  });
};

const openPreview = () => {
  if (!fileId.value) {
    return;
  }

  const previewRoute = router.resolve({
    name: 'product-based-costing-file-preview-page',
    params: { id: fileId.value },
  });

  window.open(previewRoute.href, '_blank', 'noopener');
};

const openPrintPage = () => {
  if (!fileId.value) {
    return;
  }
  const printRoute = router.resolve({
    name: 'product-based-costing-file-print-page',
    params: { id: fileId.value },
  });
  window.open(printRoute.href, '_blank', 'noopener');
};

const safeNamePart = (value: string) =>
  value.replace(/[^a-z0-9-_]+/gi, '_').replace(/^_+|_+$/g, '');

const downloadExcel = async () => {
  if (!store.item) {
    $q.notify({ type: 'warning', message: 'No costing file selected.' });
    return;
  }

  const loading = $q.loading.show({ message: 'Generating Excel...' });

  try {
    const workbook = await buildCostingExcelWorkbook({
      file: store.item,
      items: store.costingItems ?? [],
    });

    const buffer = await workbook.xlsx.writeBuffer();
    const blob = new Blob([buffer], {
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement('a');
    const fileTitle = safeNamePart(store.item.name ?? `costing_file_${store.item.id}`);
    anchor.href = url;
    anchor.download = `${fileTitle || `costing_file_${store.item.id}`}.xlsx`;
    anchor.click();
    URL.revokeObjectURL(url);
  } catch (error) {
    $q.notify({
      type: 'negative',
      message: error instanceof Error ? error.message : 'Failed to generate Excel.',
    });
  } finally {
    loading();
  }
};

const openEditDialog = (item: ProductBasedCostingItem) => {
  selectedItem.value = item;
  showItemDialog.value = true;
};

const handleUpdated = () => {
  return;
};

const onRateSave = async () => {
  if (!store.item || !fileId.value) {
    return;
  }

  console.log('Saving rates:', {
    conversion_rate: conversion_rate.value,
    cargo_rate_kg_gbp: cargo_rate_kg_gbp.value,
    profit_rate: profit_rate.value,
  });
  const payload = {
    id: store.item.id,
    conversion_rate: conversion_rate.value || 0,
    cargo_rate_kg_gbp: cargo_rate_kg_gbp.value || 0,
    profit_rate: profit_rate.value || 0,
  };

  await store.updateProductBasedCostingFile(payload);
  await recalculateAndPersistOfferPrices();
  ratesExpanded.value = false;
};

const onProductWeightChange = async (payload: WeightChangePayload) => {
  console.log('Product weight changed:', payload.item.product_id);
  if (payload.item.product_id) {
    await productStore.updateProduct({
      id: payload.item.product_id,
      product_weight: payload.item.product_weight,
    });
  }
  await store.updateProductBasedCostingItem({
    id: payload.item.id,
    product_weight: payload.item.product_weight,
    offer_price: payload.item.offer_price,
  });
};

const onPackageWeightChange = async (payload: WeightChangePayload) => {
  console.log('Package weight changed:', payload);
  if (payload.item.product_id) {
    await productStore.updateProduct({
      id: payload.item.product_id,
      package_weight: payload.item.package_weight,
    });
  }
  await store.updateProductBasedCostingItem({
    id: payload.item.id,
    package_weight: payload.item.package_weight,
    offer_price: payload.item.offer_price,
  });
};

const openShipmentDialog = (item: ProductBasedCostingItem) => {
  selectedShipItem.value = item;
  selectedQuantity.value = item.quantity ?? null;
  selectedPriceGbp.value = item.price_gbp ?? null;
  showAddShipmentDialog.value = true;
};

const normalizeText = (value: string | null | undefined) => (value ?? '').trim().toLowerCase();

const refreshShippedItemIndicators = () => {
  const productItems = store.costingItems ?? [];
  shippedItemIds.value = Array.from(
    new Set(
      productItems.filter((item) => item.assigned_shipment_id != null).map((item) => item.id),
    ),
  );
};

const onShip = (item: ProductBasedCostingItem) => {
  if (shippedItemIds.value.includes(item.id)) {
    pendingRemoveShipItem.value = item;
    confirmRemoveShipmentOpen.value = true;
    return;
  }

  openShipmentDialog(item);
};

const findShipmentItemForCostingItem = async (item: ProductBasedCostingItem) => {
  if (item.assigned_shipment_id == null) {
    return null;
  }

  const items = await globalShipmentRepository.listShipmentItems(item.assigned_shipment_id);
  const shipmentItems = (items ?? []).filter((entry) => entry.add_method === 'costing');
  const itemProductId = item.product_id ?? null;
  const itemName = normalizeText(item.name);
  const itemBarcode = normalizeText(item.barcode);
  const itemProductCode = normalizeText(item.product_code);
  const matched =
    shipmentItems.find((entry) => {
      if (itemProductId != null && entry.product_id === itemProductId) {
        return true;
      }

      return (
        normalizeText(entry.name) === itemName &&
        normalizeText(entry.barcode) === itemBarcode &&
        normalizeText(entry.product_code) === itemProductCode
      );
    }) ?? null;

  if (matched) {
    return matched;
  }

  return null;
};

const onConfirmRemoveShipment = async () => {
  const item = pendingRemoveShipItem.value;
  if (!item) {
    confirmRemoveShipmentOpen.value = false;
    return;
  }

  const shipmentItem = await findShipmentItemForCostingItem(item);
  if (!shipmentItem) {
    $q.notify({
      type: 'warning',
      message: 'No linked shipment item found.',
    });
    confirmRemoveShipmentOpen.value = false;
    pendingRemoveShipItem.value = null;
    refreshShippedItemIndicators();
    return;
  }

  try {
    await shipmentStore.deleteShipmentItem(shipmentItem.id);
  } catch {
    return;
  }

  await store.updateProductBasedCostingItem({
    id: item.id,
    assigned_shipment_id: null,
  });

  confirmRemoveShipmentOpen.value = false;
  pendingRemoveShipItem.value = null;
  refreshShippedItemIndicators();
};

const onSaveShipment = async (data: {
  shipment_id: number;
  quantity: number;
  price_gbp: number | null;
}) => {
  const rowItem = selectedShipItem.value;
  if (!rowItem) {
    return;
  }

  if (rowItem.product_id == null) {
    $q.notify({
      type: 'negative',
      message: 'Product ID is required before adding shipment.',
    });
    return;
  }

  const quantity = Math.max(0, Number(data.quantity) || 0);
  if (quantity <= 0) {
    return;
  }

  let newItem;
  try {
    newItem = await shipmentStore.addShipmentItem({
      shipment_id: data.shipment_id,
      product_id: rowItem.product_id,
      vendor_id: null,
      name: rowItem.name ?? '',
      ordered_quantity: quantity,
      image_url: rowItem.image_url ?? null,
      add_method: 'costing',
      purchase_price: data.price_gbp ?? 0,
      product_weight: rowItem.product_weight ?? 0,
      package_weight: rowItem.package_weight ?? 0,
      barcode: rowItem.barcode ?? null,
      product_code: rowItem.product_code ?? null,
      source_child_tenant_id: null,
      source_type: null,
      source_id: null,
    });
  } catch {
    return;
  }

  if (!newItem) {
    return;
  }

  await store.updateProductBasedCostingItem({
    id: rowItem.id,
    assigned_shipment_id: data.shipment_id,
  });

  showAddShipmentDialog.value = false;
  selectedShipItem.value = null;
  selectedQuantity.value = null;
  selectedPriceGbp.value = null;
  if (!shippedItemIds.value.includes(rowItem.id)) {
    shippedItemIds.value = [...shippedItemIds.value, rowItem.id];
  }
};

const onDefaultShipmentChange = async (shipmentId: number | null) => {
  if (!fileId.value) {
    return;
  }

  const currentDefault = store.item?.default_shipment_id ?? null;
  if (currentDefault === shipmentId) {
    return;
  }

  await store.updateProductBasedCostingFile({
    id: fileId.value,
    default_shipment_id: shipmentId,
  });
};

const goBack = () => {
  void router.push({ name: 'product-based-costing-page' });
};
</script>

<style scoped>
.costing-details-page {
  background: transparent;
}

.costing-items-surface {
  overflow: hidden;
}

.soft-input :deep(.q-field__control) {
  border-radius: 8px;
}

.status-workflow-row {
  flex-wrap: wrap;
  row-gap: 8px;
}

.status-workflow-sep {
  align-self: stretch;
  min-height: 24px;
}

.rates-summary {
  white-space: nowrap;
}

@media (max-width: 599px) {
  .status-workflow-chevron,
  .status-workflow-sep {
    display: none;
  }

  .rates-summary {
    white-space: normal;
  }
}
</style>
