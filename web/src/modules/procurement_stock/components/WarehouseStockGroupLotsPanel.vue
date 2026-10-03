<template>
  <div class="warehouse-group-lots column">
    <WarehouseStockListRow
      v-for="(row, idx) in stockRows"
      :key="row.id"
      :row="row"
      :index="idx + 1"
      :read-only="readOnly"
      :grade-label="gradeLabel(row)"
      :availability-label="formatStockAvailability(row.availability)"
      :shipment-status-label="formatGlobalShipmentStatus(row.shipment_status)"
      :outcome-label="row.outcome_reason ? formatOutcomeReason(row.outcome_reason) : ''"
      :unit-cost-label="formatCost(getUnitCost(row))"
      :line-total-label="formatCost(getUnitCost(row) * row.quantity)"
      @location="emit('location', $event)"
      @condition="emit('condition', $event)"
      @copy-code="emit('copy-code', $event)"
    />
    <div v-if="isFetching && !stockRows.length" class="row justify-center q-py-sm">
      <q-spinner color="primary" size="20px" />
    </div>
    <div
      v-if="hasMore"
      ref="sentinelRef"
      class="warehouse-list-sentinel"
      aria-hidden="true"
    />
    <div v-if="isFetchingNextPage" class="row justify-center q-py-xs">
      <q-spinner color="primary" size="18px" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import WarehouseStockListRow from './WarehouseStockListRow.vue';
import type { GlobalStock } from '../repositories/globalStockRepository';
import { useWarehouseStockInfiniteQuery } from '../composables/useWarehouseStockInfiniteQuery';
import type { StockAvailability } from '../constants/stockAvailability';
import { formatStockAvailability } from '../constants/stockAvailability';
import { formatOutcomeReason } from '../constants/shipmentOutcomeLabels';
import { formatGlobalShipmentStatus } from '../constants/shipmentStatus';
import type { WarehouseStockGroupBy } from '../constants/warehouseStockList';

const props = defineProps<{
  tenantId: number;
  groupBy: WarehouseStockGroupBy;
  groupKey: string;
  readOnly?: boolean;
  search: string;
  shipmentId: number | null;
  shipmentStatus: string | null;
  locationId: number | null;
  availability: StockAvailability | null;
  gradeTagId: number | null;
  hideZeroStock: boolean;
  gradeLabel: (row: GlobalStock) => string;
  getUnitCost: (row: GlobalStock) => number;
  formatCost: (n: number) => string;
}>();

const emit = defineEmits<{
  location: [row: GlobalStock];
  condition: [row: GlobalStock];
  'copy-code': [code: string];
}>();

const sentinelRef = ref<HTMLElement | null>(null);
let observer: IntersectionObserver | null = null;

const {
  stockRows,
  hasMore,
  isFetching,
  isFetchingNextPage,
  fetchNextPage,
} = useWarehouseStockInfiniteQuery({
  tenantId: computed(() => props.tenantId),
  search: computed(() => props.search),
  shipmentId: computed(() => props.shipmentId),
  shipmentStatus: computed(() => props.shipmentStatus),
  locationId: computed(() => props.locationId),
  availability: computed(() => props.availability),
  gradeTagId: computed(() => props.gradeTagId),
  hideZeroStock: computed(() => props.hideZeroStock),
  groupBy: computed(() => props.groupBy),
  groupKey: computed(() => props.groupKey),
});

const disconnectObserver = () => {
  observer?.disconnect();
  observer = null;
};

const tryFetchNext = () => {
  if (!hasMore.value || isFetchingNextPage.value) return;
  void fetchNextPage();
};

onMounted(() => {
  observer = new IntersectionObserver(
    (entries) => {
      if (entries[0]?.isIntersecting) tryFetchNext();
    },
    { root: null, rootMargin: '120px 0px', threshold: 0 },
  );
  if (sentinelRef.value) observer.observe(sentinelRef.value);
});

watch(sentinelRef, (el, prev) => {
  if (prev && observer) observer.unobserve(prev);
  if (el && observer) observer.observe(el);
});

onBeforeUnmount(disconnectObserver);
</script>

<style scoped>
.warehouse-group-lots {
  background: color-mix(in srgb, var(--bw-neutral-canvas, #fbfaf7) 55%, transparent);
  border-bottom: 1px solid var(--bw-neutral-border, #e2e8f0);
}

.warehouse-list-sentinel {
  height: 1px;
  width: 100%;
}
</style>
