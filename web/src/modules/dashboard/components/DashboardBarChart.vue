<template>
  <div class="dashboard-bar-chart">
    <div v-if="empty" class="dashboard-bar-chart__empty">{{ emptyLabel }}</div>
    <div v-else class="dashboard-bar-chart__canvas">
      <Bar :data="data" :options="chartOptions" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { Bar } from 'vue-chartjs';
import type { ChartData, ChartOptions } from 'chart.js';
import { ensureDashboardChartsRegistered, readThemeRgb, rgba } from '../utils/dashboardChartSetup';

ensureDashboardChartsRegistered();

const props = withDefaults(
  defineProps<{
    data: ChartData<'bar'>;
    indexAxis?: 'x' | 'y';
    empty?: boolean;
    emptyLabel?: string;
  }>(),
  {
    indexAxis: 'x',
    emptyLabel: 'No data yet',
  },
);

const primaryRgb = readThemeRgb();

const chartOptions = computed<ChartOptions<'bar'>>(() => ({
  indexAxis: props.indexAxis,
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: { display: false },
    tooltip: {
      callbacks: {
        label: (item) => ` ${Number(item.raw).toLocaleString()}`,
      },
    },
  },
  scales: {
    x: {
      grid: { display: props.indexAxis === 'y' },
      ticks: { color: 'var(--bw-theme-muted)', font: { size: 10, weight: 600 } },
      border: { display: false },
    },
    y: {
      grid: { color: rgba(primaryRgb, 0.08) },
      ticks: { color: 'var(--bw-theme-muted)', font: { size: 10, weight: 600 } },
      border: { display: false },
    },
  },
}));
</script>

<style scoped>
.dashboard-bar-chart {
  width: 100%;
}

.dashboard-bar-chart__canvas {
  height: 8rem;
}

.dashboard-bar-chart__empty {
  height: 8rem;
  display: grid;
  place-items: center;
  text-align: center;
  font-size: 0.875rem;
  color: var(--bw-theme-muted);
  border: 1px dashed var(--bw-theme-border);
  border-radius: 12px;
  background: color-mix(in srgb, var(--bw-theme-border) 25%, transparent);
}
</style>
