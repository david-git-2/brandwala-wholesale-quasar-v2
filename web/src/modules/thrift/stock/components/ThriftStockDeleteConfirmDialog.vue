<script setup lang="ts">
import type { ThriftStock } from '../types';

defineProps<{
  deleteConfirmOpen: boolean;
  deleteLoading: boolean;
  selectedRow: ThriftStock | null;
  bulkDeleteConfirmOpen: boolean;
  bulkDeleteLoading: boolean;
  selectedStockIdsCount: number;
  imageRemoveConfirmOpen: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:deleteConfirmOpen', val: boolean): void;
  (e: 'update:bulkDeleteConfirmOpen', val: boolean): void;
  (e: 'update:imageRemoveConfirmOpen', val: boolean): void;
  (e: 'delete-item'): void;
  (e: 'delete-selected-items'): void;
  (e: 'remove-edit-image'): void;
}>();
</script>

<template>
  <div>
    <!-- Delete Confirmation Dialog -->
    <q-dialog
      :model-value="deleteConfirmOpen"
      persistent
      @update:model-value="(val) => emit('update:deleteConfirmOpen', val)"
    >
      <q-card style="width: 350px; max-width: 90vw" class="floating-surface shadow-2 q-pa-md">
        <q-card-section class="row items-center">
          <q-avatar icon="ph ph-warning" color="warning" text-color="white" />
          <span class="q-ml-sm text-weight-bold">Delete Stock Item</span>
        </q-card-section>
        <q-card-section>
          Are you sure you want to delete stock item <strong>{{ selectedRow?.name }}</strong
          >? The Cloudinary image is deleted first; the stock row is only removed if that succeeds.
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup :disable="deleteLoading" />
          <q-btn
            color="negative"
            label="Delete"
            :loading="deleteLoading"
            :disable="deleteLoading"
            @click="emit('delete-item')"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Bulk Delete Confirmation Dialog -->
    <q-dialog
      :model-value="bulkDeleteConfirmOpen"
      persistent
      @update:model-value="(val) => emit('update:bulkDeleteConfirmOpen', val)"
    >
      <q-card style="width: 400px; max-width: 90vw" class="floating-surface shadow-2 q-pa-md">
        <q-card-section class="row items-center">
          <q-avatar icon="ph ph-warning" color="warning" text-color="white" />
          <span class="q-ml-sm text-weight-bold">Delete Selected Stock</span>
        </q-card-section>
        <q-card-section>
          Delete <strong>{{ selectedStockIdsCount }}</strong> selected stock item(s)? Cloudinary
          images are deleted first; stock rows are only removed if image delete succeeds.
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup :disable="bulkDeleteLoading" />
          <q-btn
            color="negative"
            label="Delete all"
            :loading="bulkDeleteLoading"
            :disable="bulkDeleteLoading"
            @click="emit('delete-selected-items')"
          />
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- Remove Image Confirmation Dialog -->
    <q-dialog
      :model-value="imageRemoveConfirmOpen"
      persistent
      @update:model-value="(val) => emit('update:imageRemoveConfirmOpen', val)"
    >
      <q-card style="width: 350px; max-width: 90vw" class="floating-surface shadow-2 q-pa-md">
        <q-card-section class="row items-center">
          <q-avatar icon="ph ph-image" color="warning" text-color="white" />
          <span class="q-ml-sm text-weight-bold">Remove Product Image</span>
        </q-card-section>
        <q-card-section>
          Remove this product image? The change is applied when you save the stock item.
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" color="grey-7" v-close-popup />
          <q-btn color="negative" label="Remove" no-caps @click="emit('remove-edit-image')" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </div>
</template>

<style scoped>
.floating-surface {
  background: rgba(255, 255, 255, 0.86);
  border-radius: 14px;
  border: 1px solid rgba(34, 56, 101, 0.08);
  backdrop-filter: blur(6px);
}
</style>
