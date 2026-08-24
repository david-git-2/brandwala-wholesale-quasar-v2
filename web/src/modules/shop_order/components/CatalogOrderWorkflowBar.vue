<template>
  <div>
    <q-card v-if="isLoading" flat bordered class="q-pa-sm">
      <q-skeleton type="rect" height="72px" />
    </q-card>

    <CatalogOrderProgressBar v-else-if="order" variant="staff" :order="order">
      <template #trailing>
        <div class="row items-center justify-end q-gutter-x-xs no-wrap workflow-trailing">
          <div class="column items-end q-gutter-y-xs">
            <div v-if="!ratesExpanded" class="text-caption text-grey-7 rates-summary text-right">
              {{ ratesSummary }}
            </div>
            <q-btn
              flat
              dense
              no-caps
              color="primary"
              :icon="ratesExpanded ? 'ph ph-caret-up' : 'ph ph-sliders-horizontal'"
              :label="ratesExpanded ? 'Hide rates' : 'Rates'"
              class="q-px-sm"
              style="border-radius: 8px"
              @click="ratesExpanded = !ratesExpanded"
            />
          </div>
          <CatalogOrderStaffOverflowMenu
            :visible-columns="visibleColumns"
            @update:visible-columns="emit('update:visible-columns', $event)"
            @override-status="emit('override-status')"
          />
        </div>
      </template>
    </CatalogOrderProgressBar>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { ShopOrder } from '../types';
import CatalogOrderProgressBar from './CatalogOrderProgressBar.vue';
import CatalogOrderStaffOverflowMenu from './CatalogOrderStaffOverflowMenu.vue';

const props = defineProps<{
  order: ShopOrder | null;
  isLoading?: boolean;
  visibleColumns?: string[];
}>();

const emit = defineEmits<{
  (e: 'update:visible-columns', columns: string[]): void;
  (e: 'override-status'): void;
}>();

const ratesExpanded = defineModel<boolean>('ratesExpanded', { default: false });

const ratesSummary = computed(() => {
  const o = props.order;
  if (!o) return 'No rates';
  const conv = o.conversion_rate ?? 0;
  const cargo = o.cargo_rate ?? 0;
  const profit = o.profit_rate ?? 0;
  const basis = o.profit_basis === 'total_cost' ? 'Total Cost' : 'Purchase';
  return `Conv ${conv} · Cargo ${cargo} · Profit ${profit}% (${basis})`;
});
</script>

<style scoped>
.rates-summary {
  max-width: 220px;
  white-space: nowrap;
}

.workflow-trailing {
  flex-shrink: 0;
}

@media (max-width: 599px) {
  .rates-summary {
    white-space: normal;
    max-width: 140px;
  }

  .workflow-trailing {
    flex-wrap: wrap;
    row-gap: 4px;
  }
}
</style>
