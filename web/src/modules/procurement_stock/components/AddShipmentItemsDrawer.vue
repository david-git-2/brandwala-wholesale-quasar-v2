<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide" position="right" full-height persistent>
    <q-card class="drawer-card column no-wrap">
      <q-card-section class="row items-center q-py-sm q-px-md drawer-header text-white">
        <div class="col">
          <div class="text-subtitle1 text-weight-bold">Add Items</div>
          <div class="text-caption" style="opacity: 0.85">
            {{ shipmentName }}
          </div>
        </div>
        <q-btn icon="close" flat round dense color="white" v-close-popup />
      </q-card-section>

      <AddShipmentItemsPanel
        class="col"
        :shipment-id="shipmentId"
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
  width: 1000px;
  max-width: 95vw;
  height: calc(100vh - 24px) !important;
  margin: 12px;
  border-radius: 16px !important;
  background: rgba(255, 255, 255, 0.98) !important;
  border: 1px solid rgba(226, 232, 240, 0.9);
  box-shadow: 0 16px 40px rgba(15, 23, 42, 0.15) !important;
  overflow: hidden;
}

.drawer-header {
  background: var(--q-primary) !important;
}
</style>
