<template>
  <ul class="dashboard-chart-legend">
    <li v-for="row in rows" :key="row.label" class="dashboard-chart-legend__row">
      <span class="dashboard-chart-legend__label">{{ row.label }}</span>
      <span class="dashboard-chart-legend__sep" aria-hidden="true">·</span>
      <span class="dashboard-chart-legend__value bw-tabular">{{ row.value }}</span>
      <span v-if="row.pct != null" class="dashboard-chart-legend__pct bw-tabular">({{ row.pct }}%)</span>
    </li>
  </ul>
</template>

<script setup lang="ts">
export type DashboardChartLegendRow = {
  color?: string;
  label: string;
  value: string;
  pct?: number;
};

defineProps<{
  rows: DashboardChartLegendRow[];
}>();
</script>

<style scoped>
.dashboard-chart-legend {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem 0.75rem;
  justify-content: center;
}

.dashboard-chart-legend__row {
  display: flex;
  align-items: baseline;
  flex-wrap: wrap;
  gap: 0.2rem;
  font-size: 12px;
  line-height: 1.35;
}

.dashboard-chart-legend__label {
  color: var(--bw-theme-muted);
}

.dashboard-chart-legend__sep {
  color: var(--bw-theme-muted);
}

.dashboard-chart-legend__value {
  font-weight: 600;
  color: var(--bw-theme-ink);
}

.dashboard-chart-legend__pct {
  color: var(--bw-theme-muted);
}
</style>
