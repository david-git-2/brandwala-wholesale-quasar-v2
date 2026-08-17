<template>
  <q-dialog ref="dialogRef" @hide="onDialogHide" position="right" full-height persistent>
    <q-card class="drawer-card column no-wrap">
      <q-card-section class="row items-center q-py-sm q-px-md drawer-header text-white">
        <div class="col">
          <div class="text-subtitle1 text-weight-bold">Add products</div>
          <div class="text-caption" style="opacity: 0.85">
            {{ fileName }}
          </div>
        </div>
        <q-btn icon="ph ph-x" flat round dense color="white" aria-label="Close" @click="onSaved" />
      </q-card-section>

      <AddCostingItemsPanel
        class="col"
        :file-id="fileId"
        layout="drawer"
        @saved="onSaved"
        @create-new-product="onCreateNewProduct"
      />
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useDialogPluginComponent } from 'quasar';
import { useProductBasedCostingStore } from '../stores/productBasedCostingStore';
import AddCostingItemsPanel from './AddCostingItemsPanel.vue';

const props = defineProps<{
  fileId: number;
}>();

defineEmits([...useDialogPluginComponent.emits]);

const { dialogRef, onDialogHide, onDialogOK } = useDialogPluginComponent();
const costingStore = useProductBasedCostingStore();

const fileName = computed(
  () => costingStore.item?.name ?? `Costing File #${props.fileId}`,
);

const onSaved = () => {
  onDialogOK();
};

const onCreateNewProduct = (name: string) => {
  onDialogOK({ createProductName: name });
};
</script>

<style scoped>
.drawer-card {
  width: 640px;
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
