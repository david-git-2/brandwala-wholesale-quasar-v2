<template>
  <div>
    <q-card v-if="isLoading" flat bordered class="q-pa-sm">
      <q-skeleton type="rect" height="72px" />
    </q-card>

    <ProductBasedCostingProgressBar v-else-if="file" :status="status">
      <template #trailing>
        <ProductBasedCostingStaffOverflowMenu @override-status="emit('override-status')" />
      </template>
    </ProductBasedCostingProgressBar>
  </div>
</template>

<script setup lang="ts">
import type { ProductBasedCostingFile } from '../types';
import ProductBasedCostingProgressBar from './ProductBasedCostingProgressBar.vue';
import ProductBasedCostingStaffOverflowMenu from './ProductBasedCostingStaffOverflowMenu.vue';

defineProps<{
  file: ProductBasedCostingFile | null;
  isLoading: boolean;
  status: string;
}>();

const emit = defineEmits<{
  (e: 'override-status'): void;
}>();
</script>
