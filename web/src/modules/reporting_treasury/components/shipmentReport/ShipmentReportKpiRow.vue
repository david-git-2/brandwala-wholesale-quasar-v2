<template>
  <q-card flat bordered class="q-pa-md report-section">
    <div class="row q-col-gutter-sm q-mb-sm">
      <div
        v-for="tile in primaryKpis"
        :key="tile.key"
        class="col-12 col-sm-6 col-md-3"
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
    <div class="row q-col-gutter-sm q-mt-sm">
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
import type { ShipmentReportKpiTile } from '../../composables/useShipmentReportView';
import ShipmentReportStatTile from './ShipmentReportStatTile.vue';

defineProps<{
  primaryKpis: ShipmentReportKpiTile[];
  secondaryKpis: ShipmentReportKpiTile[];
}>();
</script>

<style scoped>
.report-section {
  background: var(--tf-neutral-surface);
  border-radius: var(--tf-radius-md, 12px);
}
</style>