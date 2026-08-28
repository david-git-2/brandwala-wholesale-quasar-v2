<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide" position="right" full-height persistent>
    <q-card class="drawer-card column no-wrap">
      <AddShipmentItemsPanel
        class="col"
        :shipment-id="shipmentId"
        :initial-section-id="initialSectionId"
        layout="drawer"
        @saved="onSaved"
        @cancel="onCancel"
      />
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useDialogPluginComponent } from 'quasar';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';
import AddShipmentItemsPanel from './AddShipmentItemsPanel.vue';

const props = defineProps<{
  shipmentId: number;
  initialSectionId?: number | null | undefined;
}>();

defineEmits([...useDialogPluginComponent.emits]);

const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent();
const shipmentStore = useGlobalShipmentStore();

const shipmentName = computed(
  () => shipmentStore.currentShipment?.name ?? `Shipment #${props.shipmentId}`,
);

const onSaved = () => {
  onDialogOK();
};

const onCancel = () => {
  dialogRef.value?.hide();
};
</script>

<style scoped>
.drawer-card {
  width: 820px;
  max-width: 95vw;
  height: calc(100vh - 24px) !important;
  margin: 12px;
  border-radius: 16px !important;
  background: #ffffff !important;
  border: 1px solid #e2e8f0;
  box-shadow: 0 20px 40px -15px rgba(0, 0, 0, 0.2) !important;
  overflow: hidden;
}

.drawer-header {
  background: #0f172a !important; /* Premium dark navy slate */
  border-bottom: 1px solid #334155;
}
</style>
