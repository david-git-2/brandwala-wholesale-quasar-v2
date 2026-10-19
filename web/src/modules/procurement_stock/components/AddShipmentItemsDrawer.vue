<template>
  <AppResizableOverlayPanel
    :model-value="modelValue"
    storage-key="procurement.add-shipment-items-drawer-width"
    :default-width="820"
    :min-width="480"
    :max-width="1200"
    aria-label="Add shipment items"
    @update:model-value="(val) => emit('update:modelValue', val)"
  >
    <div class="drawer-card column no-wrap full-height">
      <AddShipmentItemsPanel
        class="col"
        :shipment-id="shipmentId"
        :initial-section-id="initialSectionId"
        layout="drawer"
        @saved="onSaved"
      />
    </div>
  </AppResizableOverlayPanel>
</template>

<script setup lang="ts">
import AppResizableOverlayPanel from 'src/components/ui/AppResizableOverlayPanel.vue';
import AddShipmentItemsPanel from './AddShipmentItemsPanel.vue';

defineProps<{
  modelValue: boolean;
  shipmentId: number;
  initialSectionId?: number | null | undefined;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  saved: [];
}>();

const onSaved = () => {
  emit('saved');
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
