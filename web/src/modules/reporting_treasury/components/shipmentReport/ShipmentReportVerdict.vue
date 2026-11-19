<template>
  <q-card flat bordered class="q-pa-md report-section">
    <div class="text-body2 text-weight-medium q-mb-sm">{{ verdict.sentence }}</div>
    <div class="row q-gutter-xs">
      <q-chip
        v-for="chip in verdict.chips"
        :key="chip.key"
        dense
        size="sm"
        :class="chipClass(chip.tone)"
      >
        {{ chip.label }}
      </q-chip>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import type { ShipmentReportVerdictModel } from '../../composables/useShipmentReportView';

defineProps<{
  verdict: ShipmentReportVerdictModel;
}>();

function chipClass(tone: string) {
  if (tone === 'positive') return 'verdict-chip verdict-chip--positive';
  if (tone === 'negative') return 'verdict-chip verdict-chip--negative';
  if (tone === 'attention') return 'verdict-chip verdict-chip--attention';
  return 'verdict-chip';
}
</script>

<style scoped>
.report-section {
  background: var(--tf-neutral-surface);
  border-radius: var(--tf-radius-md, 12px);
}

.verdict-chip {
  background: var(--tf-neutral-subtle);
  color: var(--tf-neutral-ink);
}

.verdict-chip--positive {
  background: var(--tf-positive-soft);
  color: var(--tf-neutral-ink);
}

.verdict-chip--negative {
  background: var(--tf-negative-soft);
  color: var(--tf-neutral-ink);
}

.verdict-chip--attention {
  background: var(--tf-attention-soft);
  color: var(--tf-neutral-ink);
}
</style>