<template>
  <q-page class="q-pa-md">
    <div class="row items-center justify-between q-mb-md">
      <div>
        <div class="text-h5 text-weight-bold">Product Based Costing File Details</div>
      </div>
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
        <div v-if="store.item.note" class="q-mt-sm text-body2">note: {{ store.item.note }}</div>
      </template>

      <div v-else class="text-negative">File not found.</div>
    </q-card>

    <div class="row q-gutter-sm">
      <q-input v-model="conversion_rate" dense outlined type="number" label="Conversion Rate" />
      <q-input
        v-model="cargo_rate_kg_gbp"
        dense
        outlined
        type="number"
        label="Cargo Rate (kg/GBP)"
      />
      <q-input v-model="profit_rate" dense outlined type="number" label="Profit Rate" />
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
          :cargo-rate="650"
          :conversion-rate="140"
          :profit-rate="25"
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
const productStore = useProductStore();

const route = useRoute();
const router = useRouter();
const store = useProductBasedCostingStore();

const cargo_rate_kg_gbp = ref();
const conversion_rate = ref();
const profit_rate = ref();
const status = ref();
const fileId = computed(() => Number(route.params.id));

const onStatusChange = async () => {
  await store.updateProductBasedCostingFile({
    id: fileId.value,
    status: status.value,
  });
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
  await store.fetchProductBasedCostingItems(fileId.value);
};

onMounted(async () => {
  await loadData();

  cargo_rate_kg_gbp.value = store.item?.cargo_rate_kg_gbp || null;
  conversion_rate.value = store.item?.conversion_rate || null;
  profit_rate.value = store.item?.profit_rate || null;
  status.value = store.item?.status || 'pending';
});

watch(
  () => route.params.id,
  async () => {
    await loadData();
  },
);

const onEdit = (item: unknown) => {
  console.log('edit', item);
  openEditDialog(item);
};

const onDelete = async (item: unknown) => {
  console.log('delete', item);
  await store.deleteProductBasedCostingItem(item.id);
};

const onRowChange = async (payload) => {
  await store.updateProductBasedCostingItem(payload.item);
  console.log('Row changed:', payload);
};

const showItemDialog = ref(false);
const selectedItem = ref(null);

const openCreateDialog = () => {
  console.log('Opening create dialog');
  selectedItem.value = null;
  showItemDialog.value = true;
};

const openEditDialog = (item) => {
  selectedItem.value = item;
  showItemDialog.value = true;
};

const handleUpdated = async () => {
  await store.fetchProductBasedCostingItems(fileId.value);
};

const onRateSave = async () => {
  console.log('Saving rates:', {
    conversion_rate: conversion_rate.value,
    cargo_rate_kg_gbp: cargo_rate_kg_gbp.value,
    profit_rate: profit_rate.value,
  });
  const payload = {
    id: store.item.id,

    name: store.item.name,
    order_for: store.item.order_for,
    note: store.item.note,
    conversion_rate: conversion_rate.value,
    cargo_rate_kg_gbp: cargo_rate_kg_gbp.value,
    profit_rate: profit_rate.value,
    status: status.value,
  };

  await store.updateProductBasedCostingFile(payload);
};

const onProductWeightChange = async (payload) => {
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
  });
};

const onPackageWeightChange = async (payload) => {
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
  });
};
</script>
