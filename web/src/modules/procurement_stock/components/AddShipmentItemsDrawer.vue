<template>
  <q-dialog
    ref="dialogRef"
    class="add-shipment-items-drawer-dialog"
    maximized
    no-shake
    @hide="onDialogHide"
  >
    <AppResizableOverlayPanel
      :model-value="panelOpen"
      storage-key="procurement.add-shipment-items-drawer-width"
      :default-width="820"
      :min-width="480"
      :max-width="1200"
      aria-label="Add shipment items"
      @update:model-value="onPanelOpenChange"
    >
      <div class="drawer-card column no-wrap full-height">
        <AddShipmentItemsPanel
          class="col"
          :shipment-id="shipmentId"
          :initial-section-id="initialSectionId"
          layout="drawer"
          @saved="onSaved"
          @cancel="onCancel"
        />
      </div>
    </AppResizableOverlayPanel>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { useDialogPluginComponent } from 'quasar';
import AppResizableOverlayPanel from 'src/components/ui/AppResizableOverlayPanel.vue';
import AddShipmentItemsPanel from './AddShipmentItemsPanel.vue';

defineProps<{
  shipmentId: number;
  initialSectionId?: number | null | undefined;
}>();

defineEmits([...useDialogPluginComponent.emits]);

const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent();

const panelOpen = ref(true);

const onPanelOpenChange = (open: boolean) => {
  panelOpen.value = open;
  if (!open) {
    dialogRef.value?.hide();
  }
};

const onSaved = () => {
  onDialogOK();
};

const onCancel = () => {
  dialogRef.value?.hide();
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

<style>
.add-shipment-items-drawer-dialog .q-dialog__backdrop {
  display: none;
}

.add-shipment-items-drawer-dialog .q-dialog__inner {
  padding: 0;
  pointer-events: none;
}
</style>
