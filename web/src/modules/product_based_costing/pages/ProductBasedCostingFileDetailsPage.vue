<template>
  <q-page class="q-pa-md costing-details-page">
    <PageInitialLoader v-if="store.loading" />
    <template v-else>
      <q-card flat class="q-mb-md floating-surface hero-surface shadow-1">
        <q-card-section class="q-py-sm">
          <div class="row items-center justify-between q-col-gutter-sm">
            <div class="col">
              <div class="row items-center q-gutter-sm">
                <q-badge color="primary" outline class="text-weight-medium">
                  #{{ store?.item?.id ?? '-' }}
                </q-badge>
                <div class="text-h6 text-weight-bold">
                  {{ store?.item?.name ?? 'Costing File' }}
                </div>
              </div>
              <div class="text-caption text-grey-8 q-mt-xs">
                Created for {{ store?.item?.order_for ?? '-' }}
              </div>
            </div>
            <div class="col-auto row items-center q-gutter-sm">
              <q-chip
                v-if="store.item"
                dense
                square
                clickable
                :style="statusChipStyle(status)"
                class="costing-file-status-chip q-px-md q-py-sm"
              >
                <span class="status-chip-dot" :style="{ backgroundColor: statusDotColor(status) }" />
                {{ status }}
                <q-menu>
                  <q-list dense style="min-width: 150px">
                    <q-item
                      v-for="option in statusOptions"
                      :key="option"
                      clickable
                      v-close-popup
                      @click="onStatusMenuSelect(option)"
                    >
                      <q-item-section>{{ option }}</q-item-section>
                    </q-item>
                  </q-list>
                </q-menu>
              </q-chip>
              <q-btn
                color="primary"
                unelevated
                no-caps
                size="sm"
                icon="add"
                dense
                label="Add Item"
                class="q-px-md q-py-sm"
                @click="openCreateDialog"
              />
              <q-btn
                color="primary"
                outline
                no-caps
                size="sm"
                icon="view_column"
                dense
                label="Columns"
                aria-label="Select columns"
                class="q-px-md q-py-sm"
              >
                <q-menu>
                  <q-list style="min-width: 240px">
                    <q-item>
                      <q-item-section>
                        <div class="text-subtitle2">Show Columns</div>
                      </q-item-section>
                    </q-item>
                    <q-item>
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
              </q-btn>
              <q-btn-dropdown
                color="indigo-8"
                outline
                no-caps
                size="sm"
                dense
                label="Actions"
                class="q-px-md q-py-sm"
                dropdown-icon="expand_more"
              >
                <q-list dense>
                  <q-item clickable v-close-popup :disable="status === 'pending'" @click="openPreview">
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
                  <q-item
                    clickable
                    v-close-popup
                    @click="router.push({ name: 'product-based-costing-file-cart-page', params: { id: fileId } })"
                  >
                    <q-item-section avatar>
                      <q-icon name="shopping_cart" />
                    </q-item-section>
                    <q-item-section>Cart</q-item-section>
                  </q-item>
                </q-list>
              </q-btn-dropdown>
            </div>
          </div>
        </q-card-section>
      </q-card>

      <q-card flat class="q-mb-sm floating-surface shadow-1">
        <q-card-section class="q-py-xs">
          <div class="row items-center justify-between q-col-gutter-sm">
            <div class="col-12 col-sm-3">
              <q-input
                v-model.number="conversion_rate"
                dense
                filled
                type="number"
                class="soft-input"
                label="Conversion Rate"
              />
            </div>
            <div class="col-12 col-sm-3">
              <q-input
                v-model.number="cargo_rate_kg_gbp"
                dense
                filled
                type="number"
                class="soft-input"
                label="Cargo Rate (kg/GBP)"
              />
            </div>
            <div class="col-12 col-sm-3">
              <q-input v-model.number="profit_rate" dense filled   type="number" class="soft-input" label="Profit Rate" />
            </div>
            <div class="col-12 col-sm-auto row justify-end">
              <q-btn color="primary" label="Save" no-caps size="sm" class="pill-btn slim-btn rates-save-btn" @click="onRateSave" />
            </div>
          </div>
        </q-card-section>
      </q-card>

      <div v-if="!store.item" class="text-negative q-mb-md">File not found.</div>

      <div class="q-pa-xs q-md-pa-sm">
        <div v-if="!store.costingItems.length" class="text-grey-7 q-pa-md">No items found.</div>
        <div v-else class="row q-col-gutter-md">
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
            @update:visible-columns="visibleColumns = $event"
          />
        </div>
      </div>

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
        :default-shipment-id="(store.item?.default_shipment_id as number | null | undefined) ?? null"
        @shipment-change="onDefaultShipmentChange"
        @save="onSaveShipment"
      />

      <q-dialog v-model="confirmRemoveShipmentOpen">
        <q-card style="min-width: 360px">
          <q-card-section class="text-h6">Remove From Shipment?</q-card-section>
          <q-card-section>
            This will remove the selected item from its shipment.
          </q-card-section>
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
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useQuasar } from 'quasar';
import { useRoute, useRouter } from 'vue-router';
import { useProductBasedCostingStore } from '../stores/productBasedCostingStore';
import ProductBasedCostingItemAddDialog from '../components/ProductBasedCostingItemAddDialog.vue';
import ProductBasedCostingItemsTable from '../components/ProductBasedCostingItemsTable.vue';
import PageInitialLoader from 'src/components/PageInitialLoader.vue';
import { useProductStore } from 'src/modules/products/stores/productStore';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { useShipmentStore } from 'src/modules/shipment/stores/shipmentStore';
import { shipmentService } from 'src/modules/shipment/services/shipmentService';
import ShipmentItemCompactDialog from 'src/modules/shipment/components/ShipmentItemCompactDialog.vue';
import type { ProductBasedCostingItem } from '../types';
import { productBasedCostingService } from '../services/productBasedCostingService';
import { calculateOfferPriceBdt, toNumberSafe } from '../utils/pricing';
const productStore = useProductStore();
const shipmentStore = useShipmentStore();
const tenantStore = useTenantStore();
const $q = useQuasar();

const route = useRoute();
const router = useRouter();
const store = useProductBasedCostingStore();

const cargo_rate_kg_gbp = ref<number | null>(null);
const conversion_rate = ref<number | null>(null);
const profit_rate = ref<number | null>(null);
const status = ref<string>('pending');
const showAddShipmentDialog = ref(false);
const selectedQuantity = ref<number | null>(null);
const selectedPriceGbp = ref<number | null>(null);
const selectedShipItem = ref<ProductBasedCostingItem | null>(null);
const shippedItemIds = ref<number[]>([]);
const confirmRemoveShipmentOpen = ref(false);
const pendingRemoveShipItem = ref<ProductBasedCostingItem | null>(null);
const alwaysVisibleColumns = ['select', 'sl', 'image', 'name']
const allColumnNames = [
  'select', 'sl', 'image', 'name', 'brand', 'note', 'qty', 'barcodeText', 'website', 'priceGbp',
  'productWeight', 'packageWeight', 'totalWeight', 'cargoRate', 'cargoCostGbp', 'totalCostGbp',
  'rowTotalCostGbp', 'costBdt', 'totalCostBdt', 'offerPriceBdt', 'totalBdt', 'profitPerUnitBdt',
  'profitBdt', 'profitRate', 'status', 'action',
]
const visibleColumns = ref<string[]>([...allColumnNames])
const columnSelectorOptions = [
  { label: 'Brand', value: 'brand' },
  { label: 'Note', value: 'note' },
  { label: 'Qty', value: 'qty' },
  { label: 'Barcode / Code / Product ID', value: 'barcodeText' },
  { label: 'Website', value: 'website' },
  { label: 'Price (GBP)/Unit', value: 'priceGbp' },
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
]
const selectableColumnValues = columnSelectorOptions.map((option) => option.value)
const allSelectableColumnsSelected = computed({
  get: () => selectableColumnValues.every((value) => visibleColumns.value.includes(value)),
  set: (checked: boolean) => {
    visibleColumns.value = checked
      ? [...alwaysVisibleColumns, ...selectableColumnValues]
      : [...alwaysVisibleColumns]
  },
})
const cargoRateValue = computed(() => cargo_rate_kg_gbp.value ?? 0);
const conversionRateValue = computed(() => conversion_rate.value ?? 140);
const profitRateValue = computed(() => profit_rate.value ?? 25);
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

const onStatusMenuSelect = async (nextStatus: string) => {
  if (status.value === nextStatus) {
    return
  }
  status.value = nextStatus
  await onStatusChange()
}

const statusChipStyle = (currentStatus: string) => {
  const value = (currentStatus ?? '').toLowerCase()
  if (value === 'pending') {
    return {
      backgroundColor: '#efd399',
      color: '#6a4a14',
      border: '1px solid #d8b672',
    }
  }
  if (value === 'offered') {
    return {
      backgroundColor: '#c8d8f8',
      color: '#27487a',
      border: '1px solid #a9c4f3',
    }
  }
  if (value === 'processing') {
    return {
      backgroundColor: '#c3e8d2',
      color: '#1f5d3c',
      border: '1px solid #9fd4b7',
    }
  }
  if (value === 'invoicing') {
    return {
      backgroundColor: '#e8eaf6',
      color: '#283593',
      border: '1px solid #c5cae9',
    }
  }
  if (value === 'invoiced') {
    return {
      backgroundColor: '#e0f2f1',
      color: '#00695c',
      border: '1px solid #b2dfdb',
    }
  }
  if (value === 'cancelled') {
    return {
      backgroundColor: '#f2c7d0',
      color: '#6f2b3a',
      border: '1px solid #e3a6b3',
    }
  }
  return {
    backgroundColor: '#dbe5f3',
    color: '#3b4b66',
    border: '1px solid #b9c8dd',
  }
}

const statusDotColor = (currentStatus: string) => {
  const value = (currentStatus ?? '').toLowerCase()
  if (value === 'pending') return '#9a6a24'
  if (value === 'offered') return '#3f67b3'
  if (value === 'processing') return '#2f8b5d'
  if (value === 'invoicing') return '#3f51b5'
  if (value === 'invoiced') return '#009688'
  if (value === 'cancelled') return '#a64c62'
  return '#66758c'
}

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

const statusOptions = ['pending', 'offered', 'processing', 'invoicing', 'invoiced', 'cancelled'];

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
      return
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
    return
  }

  const results = await Promise.allSettled(
    ids.map((id) => productBasedCostingService.deleteProductBasedCostingItem(id)),
  )

  const failedCount = results.filter(
    (result) =>
      result.status === 'rejected' ||
      (result.status === 'fulfilled' && !result.value.success),
  ).length

  await store.fetchProductBasedCostingItems(fileId.value)
  refreshShippedItemIndicators()

  if (failedCount > 0) {
    $q.notify({
      type: 'warning',
      message: `${ids.length - failedCount} item(s) deleted, ${failedCount} failed.`,
    })
    return
  }

  $q.notify({
    type: 'positive',
    message: `${ids.length} item(s) deleted successfully.`,
  })
}

type RowChangePayload = {
  item: ProductBasedCostingItem
  row: unknown
  field: 'quantity' | 'offer_price' | 'status' | 'note' | 'delivered_quantity'
}

type WeightChangePayload = {
  item: ProductBasedCostingItem
  row: unknown
  field: 'product_weight' | 'package_weight'
}

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

const openPreview = () => {
  if (!fileId.value) {
    return
  }

  const previewRoute = router.resolve({
    name: 'product-based-costing-file-preview-page',
    params: { id: fileId.value },
  })

  window.open(previewRoute.href, '_blank', 'noopener')
}

const openPrintPage = () => {
  if (!fileId.value) {
    return
  }
  const printRoute = router.resolve({
    name: 'product-based-costing-file-print-page',
    params: { id: fileId.value },
  })
  window.open(printRoute.href, '_blank', 'noopener')
}

const safeNamePart = (value: string) =>
  value.replace(/[^a-z0-9-_]+/gi, '_').replace(/^_+|_+$/g, '')

const downloadExcel = async () => {
  if (!store.item) {
    $q.notify({ type: 'warning', message: 'No costing file selected.' })
    return
  }

  try {
    const ExcelJS = await import('exceljs')
    const workbook = new ExcelJS.Workbook()
    const worksheet = workbook.addWorksheet('Costing Items')

    worksheet.columns = [
      { header: 'Name', key: 'name', width: 34 },
      { header: 'Brand', key: 'brand', width: 22 },
      { header: 'Barcode', key: 'barcode', width: 22 },
      { header: 'Product Code', key: 'product_code', width: 22 },
      { header: 'Product ID', key: 'product_id', width: 12 },
      { header: 'Qty', key: 'quantity', width: 10 },
      { header: 'Price GBP', key: 'price_gbp', width: 12 },
      { header: 'Offer Price', key: 'offer_price', width: 12 },
      { header: 'Status', key: 'status', width: 14 },
      { header: 'Note', key: 'note', width: 40 },
    ]

    const headerRow = worksheet.getRow(1)
    headerRow.font = { bold: true }
    headerRow.alignment = { vertical: 'middle', horizontal: 'center' }
    headerRow.height = 22

    const items = store.costingItems ?? []
    for (const item of items) {
      const row = worksheet.addRow({
        name: item.name ?? '',
        brand: item.brand ?? '',
        barcode: item.barcode ?? '',
        product_code: item.product_code ?? '',
        product_id: item.product_id ?? '',
        quantity: item.quantity ?? '',
        price_gbp: item.price_gbp ?? '',
        offer_price: item.offer_price ?? '',
        status: item.status ?? '',
        note: item.note ?? '',
      })

      row.height = 24
      row.alignment = { vertical: 'middle', wrapText: true }
    }

    worksheet.views = [{ state: 'frozen', ySplit: 1 }]
    worksheet.autoFilter = {
      from: 'A1',
      to: 'J1',
    }

    const buffer = await workbook.xlsx.writeBuffer()
    const blob = new Blob([buffer], {
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    })
    const url = URL.createObjectURL(blob)
    const anchor = document.createElement('a')
    const fileTitle = safeNamePart(store.item.name ?? `costing_file_${store.item.id}`)
    anchor.href = url
    anchor.download = `${fileTitle || `costing_file_${store.item.id}`}.xlsx`
    anchor.click()
    URL.revokeObjectURL(url)
  } catch (error) {
    $q.notify({
      type: 'negative',
      message: error instanceof Error ? error.message : 'Failed to generate Excel.',
    })
  }
}

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
    conversion_rate: conversion_rate.value ||0,
    cargo_rate_kg_gbp: cargo_rate_kg_gbp.value||0,
    profit_rate: profit_rate.value ||0,
  };

  await store.updateProductBasedCostingFile(payload);
  await recalculateAndPersistOfferPrices();
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
  shippedItemIds.value = Array.from(new Set(productItems
    .filter((item) => item.assigned_shipment_id != null)
    .map((item) => item.id)));
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

  const result = await shipmentService.listShipmentItems(item.assigned_shipment_id);
  if (!result.success) {
    return null;
  }

  const shipmentItems = (result.data ?? []).filter((entry) => entry.method === 'costing');
  const itemProductId = item.product_id ?? null;
  const itemName = normalizeText(item.name);
  const itemBarcode = normalizeText(item.barcode);
  const itemProductCode = normalizeText(item.product_code);
  const matched = shipmentItems.find((entry) => {
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

  const deleteResult = await shipmentStore.deleteShipmentItem({ id: shipmentItem.id });
  if (!deleteResult.success) {
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
  shipment_id: number
  quantity: number
  price_gbp: number | null
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

  const addResult = await shipmentStore.addShipmentItemManual({
    shipment_id: data.shipment_id,
    order_id: null,
    method: 'costing',
    name: rowItem.name ?? null,
    quantity,
    barcode: rowItem.barcode ?? null,
    product_code: rowItem.product_code ?? null,
    product_id: rowItem.product_id,
    image_url: rowItem.image_url ?? null,
    product_weight: rowItem.product_weight ?? null,
    package_weight: rowItem.package_weight ?? null,
    price_gbp: data.price_gbp,
  });

  if (!addResult.success) {
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
</script>

<style scoped>
.costing-details-page {
  background: transparent;
}

.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}

.costing-file-status-chip {
  border-radius: 6px !important;
  font-weight: 600;
  letter-spacing: 0.01em;
  text-transform: capitalize;
}

.status-chip-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  margin-right: 6px;
}

.hero-surface {
  border-radius: 16px;
}



.slim-btn {
  min-height: 32px;
  padding-left: 10px;
  padding-right: 10px;
}

.rates-save-btn {
  min-width: 90px;
}

.soft-input :deep(.q-field__control) {
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.82);
}
</style>
