<template>
  <q-card flat bordered class="q-pa-md report-section">
    <div class="text-subtitle2 text-weight-bold q-mb-sm">Pieces</div>
    <div v-if="ordered <= 0" class="text-caption" style="color: var(--tf-neutral-muted)">
      No pieces on this batch.
    </div>
    <template v-else>
      <div class="pieces-bar" role="img" :aria-label="ariaLabel">
        <div
          v-for="seg in segmentsWithPct"
          :key="seg.key"
          class="pieces-bar__seg"
          :class="`pieces-bar__seg--${seg.key}`"
          :style="{ width: `${seg.sharePct}%` }"
        />
      </div>
      <div class="row q-col-gutter-xs q-mt-sm">
        <div
          v-for="seg in segments"
          :key="seg.key"
          class="col-auto text-caption"
        >
          <span class="pieces-legend-dot" :class="`pieces-legend-dot--${seg.key}`" />
          {{ seg.label }}: <span class="tf-num text-weight-medium">{{ seg.qty }}</span>
          <span class="tf-num" style="color: var(--tf-neutral-muted)"> ({{ seg.sharePct }}%)</span>
        </div>
      </div>
      <div class="text-caption q-mt-xs" style="color: var(--tf-neutral-muted)">
        Ordered {{ ordered }} · Received OK {{ arrived }}
      </div>
    </template>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { ShipmentReportPieceSegment } from '../../composables/useShipmentReportView';

const props = defineProps<{
  segments: ShipmentReportPieceSegment[];
  ordered: number;
  arrived: number;
}>();

const segmentsWithPct = computed(() => {
  const sum = props.segments.reduce((a, s) => a + s.qty, 0) || props.ordered || 1;
  return props.segments.map((s) => ({
    ...s,
    sharePct: Math.max((s.qty / sum) * 100, s.qty > 0 ? 2 : 0),
  }));
});

const ariaLabel = computed(() =>
  props.segments.map((s) => `${s.label} ${s.qty}`).join(', '),
);
</script>

<style scoped>
.report-section {
  background: var(--tf-neutral-surface);
  border-radius: var(--tf-radius-md, 12px);
}

.pieces-bar {
  display: flex;
  height: 12px;
  width: 100%;
  overflow: hidden;
  border-radius: var(--tf-radius-sm);
  border: 1px solid var(--tf-neutral-border);
  background: var(--tf-neutral-subtle);
}

.pieces-bar__seg {
  min-width: 2px;
  height: 100%;
}

.pieces-bar__seg--sold {
  background: var(--tf-positive-soft);
  border-right: 1px solid var(--tf-neutral-border);
}

.pieces-bar__seg--lost {
  background: var(--tf-negative-soft);
  border-right: 1px solid var(--tf-neutral-border);
}

.pieces-bar__seg--left {
  background: var(--tf-attention-soft);
}

.pieces-legend-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 2px;
  margin-right: 4px;
  vertical-align: middle;
}

.pieces-legend-dot--sold {
  background: var(--tf-positive-soft);
  border: 1px solid var(--tf-neutral-border);
}

.pieces-legend-dot--lost {
  background: var(--tf-negative-soft);
  border: 1px solid var(--tf-neutral-border);
}

.pieces-legend-dot--left {
  background: var(--tf-attention-soft);
  border: 1px solid var(--tf-neutral-border);
}
</style>