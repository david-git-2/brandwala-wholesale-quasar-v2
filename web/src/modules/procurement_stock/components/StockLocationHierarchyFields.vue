<template>
  <div class="column q-gutter-y-sm">
    <div
      v-for="row in rows"
      :key="row.key"
      class="row items-center q-col-gutter-sm"
    >
      <div class="col-4 text-caption text-grey-7 text-weight-medium">{{ row.label }}</div>
      <div class="col-8 text-body2 text-grey-9">{{ row.value }}</div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { STOCK_LOCATION_KIND_LABELS } from '../constants/stockLocationHierarchy';
import type { StockLocation } from '../types/stockLocation';
import { formatLocationOption, getStockLocationChain } from '../utils/stockLocationOptions';

const props = defineProps<{
  locations: StockLocation[];
  locationId: number | null | undefined;
}>();

const rows = computed(() => {
  const chain = getStockLocationChain(props.locations, props.locationId);
  const root = chain.returns ?? chain.warehouse;
  const rootLabel = chain.returns
    ? STOCK_LOCATION_KIND_LABELS.returns
    : STOCK_LOCATION_KIND_LABELS.warehouse;

  const fmt = (loc?: StockLocation) => (loc ? formatLocationOption(loc) : '—');

  return [
    { key: 'root', label: rootLabel, value: fmt(root) },
    { key: 'zone', label: STOCK_LOCATION_KIND_LABELS.zone, value: fmt(chain.zone) },
    { key: 'shelf', label: STOCK_LOCATION_KIND_LABELS.shelf, value: fmt(chain.shelf) },
    { key: 'level', label: STOCK_LOCATION_KIND_LABELS.level, value: fmt(chain.level) },
    { key: 'bin', label: STOCK_LOCATION_KIND_LABELS.bin, value: fmt(chain.bin) },
  ];
});
</script>
