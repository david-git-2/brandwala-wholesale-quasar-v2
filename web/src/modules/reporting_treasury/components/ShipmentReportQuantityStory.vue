<template>
  <div class="qty-story">
    <div class="text-subtitle2 text-weight-bold q-mb-sm">Pieces</div>
    <div class="stacked-bar q-mb-sm" role="img" :aria-label="stackAria">
      <div
        v-for="seg in segments"
        :key="seg.key"
        class="stacked-seg"
        :class="`seg-${seg.key}`"
        :style="{ width: `${seg.pct}%` }"
      />
    </div>
    <div class="row q-col-gutter-sm q-mb-xs">
      <div v-for="stat in mainStats" :key="stat.key" class="col-6 col-sm-3">
        <div class="stat-label">{{ stat.label }}</div>
        <div class="stat-val tf-num">{{ stat.value }}</div>
      </div>
    </div>
    <div class="text-caption text-grey-7 tf-num">
      Sold {{ soldPct }}% of batch
      <span v-if="extraCaption"> · {{ extraCaption }}</span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { ShipmentReportQtySummary } from '../types/shipmentReportDetailTypes';

const props = defineProps<{
  qty: ShipmentReportQtySummary;
}>();

const denom = computed(() => Math.max(props.qty.should_arrive, 1));

const segments = computed(() => {
  const d = denom.value;
  const arrived = Math.min(props.qty.arrived, d);
  const loss = Math.min(props.qty.loss_at_shipment, Math.max(0, d - arrived));
  const remaining = Math.min(props.qty.warehouse_remaining, Math.max(0, d - arrived - loss));
  const stalled = Math.min(props.qty.warehouse_stalled, Math.max(0, d - arrived - loss - remaining));
  const items = [
    { key: 'arrived', pct: (arrived / d) * 100 },
    { key: 'loss', pct: (loss / d) * 100 },
    { key: 'remaining', pct: (remaining / d) * 100 },
    { key: 'stalled', pct: (stalled / d) * 100 },
  ];
  return items.filter((s) => s.pct > 0.05);
});

const stackAria = computed(() => {
  return `Arrived ${props.qty.arrived}, loss ${props.qty.loss_at_shipment} of ${props.qty.should_arrive}`;
});

const soldPct = computed(() => {
  if (props.qty.should_arrive <= 0) return '0';
  return ((props.qty.sold / props.qty.should_arrive) * 100).toFixed(1);
});

const mainStats = computed(() => [
  { key: 'should', label: 'Should arrive', value: props.qty.should_arrive },
  { key: 'arrived', label: 'Arrived', value: props.qty.arrived },
  { key: 'sold', label: 'Sold', value: props.qty.sold },
  { key: 'loss', label: 'Loss', value: props.qty.loss_at_shipment },
]);

const extraCaption = computed(() => {
  const parts: string[] = [];
  if (props.qty.warehouse_stalled > 0) parts.push(`${props.qty.warehouse_stalled} held`);
  if (props.qty.warehouse_remaining > 0) parts.push(`${props.qty.warehouse_remaining} in warehouse`);
  return parts.join(', ');
});
</script>

<style scoped>
.stacked-bar {
  display: flex;
  width: 100%;
  height: 8px;
  border-radius: 4px;
  overflow: hidden;
  background: var(--tf-neutral-border);
}

.stacked-seg {
  height: 100%;
  min-width: 2px;
  transition: width 0.2s ease;
}

.seg-arrived {
  background: var(--tf-success);
}

.seg-loss {
  background: var(--tf-warning);
}

.seg-remaining {
  background: var(--tf-info);
}

.seg-stalled {
  background: var(--tf-neutral-chrome);
}

.stat-label {
  font-size: 11px;
  font-weight: 600;
  color: var(--tf-neutral-muted);
}

.stat-val {
  font-size: 16px;
  font-weight: 700;
  color: var(--tf-neutral-ink);
}
</style>
