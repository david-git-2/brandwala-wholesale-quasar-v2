<template>
  <div>
    <q-card v-if="isLoading" flat bordered class="q-pa-sm">
      <q-skeleton type="rect" height="40px" />
    </q-card>

    <div v-else-if="order" class="row items-center justify-between no-wrap q-gutter-x-sm">
      <div class="row items-center q-gutter-x-xs no-wrap ellipsis min-width-0">
        <span class="text-subtitle2 text-weight-bolder text-grey-8 font-mono bg-grey-2 q-px-xs rounded-borders" style="font-size: 12px">
          {{ order.order_no }}
        </span>
        <span class="text-grey-4">·</span>
        <q-badge
          rounded
          class="text-weight-bold text-caption q-px-sm q-py-xs"
          :color="statusBadge.color"
          :text-color="statusBadge.textColor"
        >
          {{ statusLabel }}
        </q-badge>
      </div>

      <div class="row items-center justify-end q-gutter-x-xs no-wrap workflow-trailing">
        <CatalogOrderColumnSelectorButton
          :visible-columns="visibleColumns"
          @update:visible-columns="emit('update:visible-columns', $event)"
        />
        <q-btn
          flat
          round
          dense
          color="grey-8"
          icon="ph ph-gear"
          size="sm"
          @click="emit('open-settings')"
        >
          <q-tooltip>Order settings and totals</q-tooltip>
        </q-btn>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { ShopOrder } from '../types';
import CatalogOrderColumnSelectorButton from './CatalogOrderColumnSelectorButton.vue';
import { getStaffCatalogStatusLabel, normalizeCatalogOrderStatus } from '../utils/catalogOrderStatus';

const props = defineProps<{
  order: ShopOrder | null;
  isLoading?: boolean;
  visibleColumns?: string[];
}>();

const emit = defineEmits<{
  (e: 'update:visible-columns', columns: string[]): void;
  (e: 'open-settings'): void;
}>();

const statusLabel = computed(() => getStaffCatalogStatusLabel(props.order?.status));

const statusBadge = computed(() => {
  const st = normalizeCatalogOrderStatus(props.order?.status);
  if (st === 'confirmed' || st === 'ready_for_shipment' || st === 'delivered') {
    return { color: 'green-1', textColor: 'green-9' };
  }
  if (st === 'priced' || st === 'final_offered' || st === 'procuring') {
    return { color: 'blue-1', textColor: 'blue-9' };
  }
  if (st === 'cancelled') {
    return { color: 'red-1', textColor: 'red-9' };
  }
  return { color: 'orange-1', textColor: 'orange-9' };
});
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
