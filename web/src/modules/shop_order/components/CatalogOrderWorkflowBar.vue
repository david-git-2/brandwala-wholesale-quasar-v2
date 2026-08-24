<template>
  <div>
    <q-card v-if="isLoading" flat bordered class="q-pa-sm">
      <q-skeleton type="rect" height="72px" />
    </q-card>

    <CatalogOrderProgressBar v-else-if="order" variant="staff" :order="order">
      <template #trailing>
        <div class="row items-center justify-end q-gutter-x-xs no-wrap workflow-trailing">
          <CatalogOrderColumnSelectorButton
            :visible-columns="visibleColumns"
            @update:visible-columns="emit('update:visible-columns', $event)"
          />
          <CatalogOrderStaffOverflowMenu @override-status="emit('override-status')" />
        </div>
      </template>
    </CatalogOrderProgressBar>
  </div>
</template>

<script setup lang="ts">
import type { ShopOrder } from '../types';
import CatalogOrderProgressBar from './CatalogOrderProgressBar.vue';
import CatalogOrderColumnSelectorButton from './CatalogOrderColumnSelectorButton.vue';
import CatalogOrderStaffOverflowMenu from './CatalogOrderStaffOverflowMenu.vue';

defineProps<{
  order: ShopOrder | null;
  isLoading?: boolean;
  visibleColumns?: string[];
}>();

const emit = defineEmits<{
  (e: 'update:visible-columns', columns: string[]): void;
  (e: 'override-status'): void;
}>();
</script>

<style scoped>
.workflow-trailing {
  flex-shrink: 0;
}

@media (max-width: 599px) {
  .workflow-trailing {
    flex-wrap: wrap;
    row-gap: 4px;
  }
}
</style>
