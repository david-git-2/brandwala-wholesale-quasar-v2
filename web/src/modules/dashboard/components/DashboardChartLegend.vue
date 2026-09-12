<template>
  <ul class="dashboard-chart-legend">
    <li v-for="row in rows" :key="row.label" class="dashboard-chart-legend__row">
      <span class="dashboard-chart-legend__left">
        <span class="dashboard-chart-legend__dot" :style="{ background: row.color }" />
        <span class="dashboard-chart-legend__label">{{ row.label }}</span>
      </span>
      <span class="dashboard-chart-legend__right">
        <span class="dashboard-chart-legend__value bw-tabular">{{ row.value }}</span>
        <span v-if="row.pct != null" class="dashboard-chart-legend__pct bw-tabular">{{ row.pct }}%</span>
      </span>
    </li>
  </ul>
</template>

<script setup lang="ts">
export type DashboardChartLegendRow = {
  color: string;
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
  display: grid;
  gap: 0.45rem;
}

.dashboard-chart-legend__row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
}

.dashboard-chart-legend__left {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  min-width: 0;
}

.dashboard-chart-legend__dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}

.dashboard-chart-legend__label {
  font-size: 0.78rem;
  color: var(--bw-theme-muted);
  line-height: 1.2;
}

.dashboard-chart-legend__right {
  display: flex;
  align-items: baseline;
  gap: 0.35rem;
  flex-shrink: 0;
}

.dashboard-chart-legend__value {
  font-size: 0.8rem;
  font-weight: 700;
  color: var(--bw-theme-ink);
}

.dashboard-chart-legend__pct {
  font-size: 0.72rem;
  color: var(--bw-theme-muted);
}
</style>
