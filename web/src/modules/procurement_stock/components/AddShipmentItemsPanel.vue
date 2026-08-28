<template>
  <div
    class="add-items-panel column no-wrap"
    :class="{ 'add-items-panel--drawer': layout === 'drawer' }"
  >
    <AddShipmentCatalogTab
      :shipment-id="shipmentId"
      :initial-section-id="initialSectionId"
      @done="$emit('saved')"
    />
  </div>
</template>

<script setup lang="ts">
import AddShipmentCatalogTab from './AddShipmentCatalogTab.vue';

withDefaults(
  defineProps<{
    shipmentId: number;
    initialSectionId?: number | null | undefined;
    layout?: 'drawer' | 'page';
    showCancel?: boolean;
  }>(),
  {
    initialSectionId: null,
    layout: 'drawer',
    showCancel: true,
  },
);

defineEmits<{
  saved: [];
  cancel: [];
}>();
</script>

<style scoped>
.add-items-panel {
  flex: 1;
  min-height: 0;
  background: transparent;
}

.add-items-panel--drawer {
  width: 100%;
}

.add-items-panel:not(.add-items-panel--drawer) {
  min-height: 70vh;
}
</style>
