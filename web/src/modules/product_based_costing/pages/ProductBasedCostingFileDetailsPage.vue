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
          @edit="onEdit"
          @delete="onDelete"
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
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useProductBasedCostingStore } from '../stores/productBasedCostingStore';
import ProductBasedCostingItemAddDialog from '../components/ProductBasedCostingItemAddDialog.vue';
import ProductBasedCostingItemsTable from '../components/ProductBasedCostingItemsTable.vue';
import { useProductStore } from 'src/modules/products/stores/productStore';
import type { ProductBasedCostingItem } from '../types';
import { productBasedCostingService } from '../services/productBasedCostingService';
import { calculateOfferPriceBdt, toNumberSafe } from '../utils/pricing';
const productStore = useProductStore();

const route = useRoute();
const router = useRouter();
const store = useProductBasedCostingStore();

const cargo_rate_kg_gbp = ref<number | null>(null);
const conversion_rate = ref<number | null>(null);
const profit_rate = ref<number | null>(null);
const status = ref<string>('pending');
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

const statusOptions = ['pending', 'offered', 'cancelled'];

const handleCreated = async () => {
  if (!fileId.value) {
    return;
  }

  await store.fetchProductBasedCostingItems(fileId.value);
};

onMounted(async () => {
  await loadData();

  cargo_rate_kg_gbp.value = store.item?.cargo_rate_kg_gbp ?? null;
  conversion_rate.value = store.item?.conversion_rate ?? null;
  profit_rate.value = store.item?.profit_rate ?? null;
  status.value = store.item?.status || 'pending';
});

watch(
  () => route.params.id,
  async () => {
    await loadData();
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
</script>
