<template>
  <AppResizableOverlayPanel
    :model-value="modelValue"
    storage-key="shop_order.manual-catalog-add-items-width"
    :default-width="820"
    :min-width="480"
    :max-width="1200"
    aria-label="Add manual catalog order items"
    @update:model-value="(val) => emit('update:modelValue', val)"
  >
    <div class="drawer-card column no-wrap full-height">
      <ManualCatalogAddItemsPanel
        class="col"
        :tenant-id="tenantId"
        :browse-shop-ids="browseShopIds"
        :old-order-mode="oldOrderMode"
        layout="drawer"
        @add-product="(row, qty) => emit('add-product', row, qty)"
        @done="onDone"
      />
    </div>
  </AppResizableOverlayPanel>
</template>

<script setup lang="ts">
import AppResizableOverlayPanel from 'src/components/ui/AppResizableOverlayPanel.vue';
import ManualCatalogAddItemsPanel from './ManualCatalogAddItemsPanel.vue';
import type { ShopCatalogItem } from '../../types';

defineProps<{
  modelValue: boolean;
  tenantId: number;
  browseShopIds: number[];
  oldOrderMode?: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  'add-product': [row: ShopCatalogItem, qty: number];
}>();

const onDone = () => {
  emit('update:modelValue', false);
};
</script>

<style scoped>
.drawer-card {
  width: 100%;
  height: 100%;
  min-height: 0;
  overflow: hidden;
  background: #ffffff;
}
</style>
