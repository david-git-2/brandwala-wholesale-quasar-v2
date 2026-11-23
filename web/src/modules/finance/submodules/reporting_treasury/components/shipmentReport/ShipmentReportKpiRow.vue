<template>
  <q-card flat bordered class="q-pa-md report-section">
    <div class="text-caption text-weight-bold q-mb-xs kpi-section-label">Money</div>
    <div class="row q-col-gutter-sm q-mb-sm">
      <div
        v-for="tile in primaryKpis"
        :key="tile.key"
        class="col-12 col-sm-6"
        :class="primaryColClass"
      >
        <ShipmentReportStatTile
          :label="tile.label"
          :value="tile.value"
          :hint="tile.hint"
          :emphasis="tile.emphasis"
          :tone="tile.tone"
        />
      </div>
    </div>
    <q-separator />
    <div class="text-caption text-weight-bold q-mt-sm q-mb-xs kpi-section-label">Pieces</div>
    <div class="row q-col-gutter-sm">
      <div
        v-for="tile in secondaryKpis"
        :key="tile.key"
        class="col-12 col-sm-4"
      >
        <ShipmentReportStatTile
          :label="tile.label"
          :value="tile.value"
          :hint="tile.hint"
          :emphasis="tile.emphasis"
          :tone="tile.tone === 'negative' ? 'negative' : undefined"
        />
      </div>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { ShipmentReportKpiTile } from '../../composables/useShipmentReportView';
import ShipmentReportStatTile from './ShipmentReportStatTile.vue';

const props = defineProps<{
  primaryKpis: ShipmentReportKpiTile[];
  secondaryKpis: ShipmentReportKpiTile[];
}>();

const primaryColClass = computed(() =>
  props.primaryKpis.length >= 5 ? 'col-md-4 col-xl' : 'col-md-3',
);
</script>

<style scoped>
.report-section {
  background: var(--tf-neutral-surface);
  border-radius: var(--tf-radius-md, 12px);
}

.kpi-section-label {
  color: var(--tf-neutral-chrome-text);
  text-transform: uppercase;
  letter-spacing: 0.04em;
  font-size: 11px;
}
</style>