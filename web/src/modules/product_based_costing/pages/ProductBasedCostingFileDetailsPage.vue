<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <div>
        <div class="text-h5 text-weight-bold">Product Based Costing File Details</div>
      </div>
    </div>
<div>
  <q-btn flat color="primary" icon="keyboard_backspace" label="Back to Files" @click="router.push({ name: 'product-based-costing-page' })" />
</div>
    <div class="row justify-end q-gutter-sm q-mb-md">
      <q-btn
        color="primary"
        icon="add"
        no-caps
        label="Add Item"
        @click="openCreateDialog"
        style="border-radius: 8px"
      />

      <q-btn
      :disable="status==='pending'"
        color="primary"
        outline
        icon="visibility"
        no-caps
        label="Preview"
        @click="openPreview"
        style="border-radius: 8px"
      />

      <q-btn
        color="primary"
        icon="shopping_cart"
        no-caps
        label="Cart"
        @click="
          router.push({ name: 'product-based-costing-file-cart-page', params: { id: fileId } })
        "
        style="border-radius: 8px"
      />
    </div>
    <q-card flat bordered class="q-pa-md q-mb-md">
      <div v-if="store.loading" class="text-body1">Loading...</div>

      <template v-else-if="store.item">
        <div class="row justify-end">
          <q-select
            v-model="status"
            :options="statusOptions"
            outlined
            dense
            size="sm"
            @update:model-value="onStatusChange"
          />
        </div>

        <div class="text-h6 text-weight-bold">#{{ store.item.id }} {{ store.item.name }}</div>
        <div class="text-subtitle2 q-mt-sm">created for: {{ store.item.order_for }}</div>
      </template>

      <div v-else class="text-negative">File not found.</div>
    </q-card>

    <div class="row q-gutter-sm">
      <q-input
        v-model.number="conversion_rate"
        dense
        outlined
        type="number"
        label="Conversion Rate"
      />
      <q-input
        v-model.number="cargo_rate_kg_gbp"
        dense
        outlined
        type="number"
        label="Cargo Rate (kg/GBP)"
      />
      <q-input v-model.number="profit_rate" dense outlined type="number" label="Profit Rate" />
      <q-btn
        color="primary"
        label="save rates"
        dense
        style="border-radius: 8px"
        @click="onRateSave"
      />
    </div>

    <div class="q-pa-md">
      <div class="text-h6 text-weight-bold q-mb-md">Items</div>

      <div v-if="store.loading" class="text-body1">Loading items...</div>

      <div v-else-if="!store.costingItems.length" class="text-grey-7">No items found.</div>

      <div v-else class="row q-col-gutter-md">
        <ProductBasedCostingItemsTable
          :items="store.costingItems"
          :cargo-rate="cargoRateValue"
          :conversion-rate="conversionRateValue"
          :profit-rate="profitRateValue"
          :status="store.item?.status??'pending'"
          :shipped-item-ids="shippedItemIds"
          @edit="onEdit"
          @delete="onDelete"
          @ship="onShip"
          @row-change="onRowChange"
          @product-weight-change="onProductWeightChange"
          @package-weight-change="onPackageWeightChange"
        />
      </div>
    </div>

    <ProductBasedCostingItemAddDialog
      v-model="showItemDialog"
      :product-based-costing-file-id="fileId"
      @created="handleCreated"
    />

    <ProductBasedCostingItemAddDialog
      v-model="showItemDialog"
      :product-based-costing-file-id="fileId"
      :item-data="selectedItem"
      @updated="handleUpdated"
    />

    <ShipmentItemCompactDialog
      v-model="showAddShipmentDialog"
      :quantity="selectedQuantity"
      :price-gbp="selectedPriceGbp"
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
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useQuasar } from 'quasar';
import { useRoute, useRouter } from 'vue-router';
import { useProductBasedCostingStore } from '../stores/productBasedCostingStore';
import ProductBasedCostingItemAddDialog from '../components/ProductBasedCostingItemAddDialog.vue';
import ProductBasedCostingItemsTable from '../components/ProductBasedCostingItemsTable.vue';
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

const statusOptions = ['pending', 'offered', 'processing', 'cancelled'];

const handleCreated = async () => {
  if (!fileId.value) {
    return;
  }

  await store.fetchProductBasedCostingItems(fileId.value);
  await refreshShippedItemIndicators();
};

onMounted(async () => {
  await loadData();
  const tenantId = tenantStore.selectedTenant?.id;
  if (tenantId) {
    await shipmentStore.fetchShipments(tenantId);
  }
  await refreshShippedItemIndicators();

  cargo_rate_kg_gbp.value = store.item?.cargo_rate_kg_gbp ?? null;
  conversion_rate.value = store.item?.conversion_rate ?? null;
  profit_rate.value = store.item?.profit_rate ?? null;
  status.value = store.item?.status || 'pending';
});

watch(
  () => route.params.id,
  async () => {
    await loadData();
    await refreshShippedItemIndicators();
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

type RowChangePayload = {
  item: ProductBasedCostingItem
  row: unknown
  field: 'quantity' | 'offer_price' | 'status'
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

const openEditDialog = (item: ProductBasedCostingItem) => {
  selectedItem.value = item;
  showItemDialog.value = true;
};

const handleUpdated = async () => {
  if (!fileId.value) {
    return;
  }

  await store.fetchProductBasedCostingItems(fileId.value);
  await refreshShippedItemIndicators();
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

const buildItemMatchKeys = (item: ProductBasedCostingItem) => {
  const keys: string[] = [];
  if (item.product_id != null) {
    keys.push(`product:${item.product_id}`);
  }
  const name = normalizeText(item.name);
  const barcode = normalizeText(item.barcode);
  const productCode = normalizeText(item.product_code);
  if (name || barcode || productCode) {
    keys.push(`meta:${name}|${barcode}|${productCode}`);
  }
  return keys;
};

const buildShipmentMatchKeys = (item: {
  product_id: number | null
  name: string | null
  barcode: string | null
  product_code: string | null
}) => {
  const keys: string[] = [];
  if (item.product_id != null) {
    keys.push(`product:${item.product_id}`);
  }
  const name = normalizeText(item.name);
  const barcode = normalizeText(item.barcode);
  const productCode = normalizeText(item.product_code);
  if (name || barcode || productCode) {
    keys.push(`meta:${name}|${barcode}|${productCode}`);
  }
  return keys;
};

const refreshShippedItemIndicators = async () => {
  const tenantId = tenantStore.selectedTenant?.id;
  if (!tenantId) {
    shippedItemIds.value = [];
    return;
  }

  const productItems = store.costingItems ?? [];
  if (!productItems.length) {
    shippedItemIds.value = [];
    return;
  }

  const itemMap = new Map<string, Set<number>>();
  productItems.forEach((item) => {
    buildItemMatchKeys(item).forEach((key) => {
      const current = itemMap.get(key) ?? new Set<number>();
      current.add(item.id);
      itemMap.set(key, current);
    });
  });

  const shippedIds = new Set<number>();
  const shipmentsResult = await shipmentService.listShipments(tenantId);
  if (!shipmentsResult.success) {
    shippedItemIds.value = [];
    return;
  }

  const shipmentItemsResults = await Promise.all(
    (shipmentsResult.data ?? []).map((shipment) => shipmentService.listShipmentItems(shipment.id)),
  );

  shipmentItemsResults.forEach((result) => {
    if (!result.success) {
      return;
    }

    (result.data ?? [])
      .filter((item) => item.method === 'costing')
      .forEach((item) => {
        buildShipmentMatchKeys(item).forEach((key) => {
          const ids = itemMap.get(key);
          if (!ids) {
            return;
          }
          ids.forEach((id) => shippedIds.add(id));
        });
      });
  });

  shippedItemIds.value = Array.from(shippedIds);
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
  const tenantId = tenantStore.selectedTenant?.id;
  if (!tenantId) {
    return null;
  }

  const itemKeys = new Set(buildItemMatchKeys(item));
  if (!itemKeys.size) {
    return null;
  }

  const shipmentsResult = await shipmentService.listShipments(tenantId);
  if (!shipmentsResult.success) {
    return null;
  }

  const shipmentItemsResults = await Promise.all(
    (shipmentsResult.data ?? []).map((shipment) => shipmentService.listShipmentItems(shipment.id)),
  );

  for (const result of shipmentItemsResults) {
    if (!result.success) {
      continue;
    }

    const matched = (result.data ?? [])
      .filter((entry) => entry.method === 'costing')
      .find((entry) => {
        const entryKeys = buildShipmentMatchKeys(entry);
        return entryKeys.some((key) => itemKeys.has(key));
      });

    if (matched) {
      return matched;
    }
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
    await refreshShippedItemIndicators();
    return;
  }

  const deleteResult = await shipmentStore.deleteShipmentItem({ id: shipmentItem.id });
  if (!deleteResult.success) {
    return;
  }

  confirmRemoveShipmentOpen.value = false;
  pendingRemoveShipItem.value = null;
  await refreshShippedItemIndicators();
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

  const quantity = Math.max(0, Number(data.quantity) || 0);
  if (quantity <= 0) {
    return;
  }

  await shipmentStore.addShipmentItemManual({
    shipment_id: data.shipment_id,
    order_id: null,
    method: 'costing',
    name: rowItem.name ?? null,
    quantity,
    barcode: rowItem.barcode ?? null,
    product_code: rowItem.product_code ?? null,
    product_id: rowItem.product_id ?? null,
    image_url: rowItem.image_url ?? null,
    product_weight: rowItem.product_weight ?? null,
    package_weight: rowItem.package_weight ?? null,
    price_gbp: data.price_gbp,
    received_quantity: 0,
    damaged_quantity: 0,
    stolen_quantity: 0,
  });

  selectedShipItem.value = null;
  selectedQuantity.value = null;
  selectedPriceGbp.value = null;
  await refreshShippedItemIndicators();
};
</script>
