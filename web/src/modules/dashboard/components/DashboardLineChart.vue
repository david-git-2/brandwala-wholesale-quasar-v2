<template>
  <div class="dashboard-line-chart">
    <div v-if="empty" class="dashboard-line-chart__empty">{{ emptyLabel }}</div>
    <div v-else class="dashboard-line-chart__canvas">
      <Line :data="data" :options="options" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { Line } from 'vue-chartjs';
import type { ChartData, ChartOptions } from 'chart.js';
import { ensureDashboardChartsRegistered, readThemeRgb, rgba } from '../utils/dashboardChartSetup';

ensureDashboardChartsRegistered();

withDefaults(
  defineProps<{
    data: ChartData<'line'>;
    empty?: boolean;
    emptyLabel?: string;
  }>(),
  {
    emptyLabel: 'No sales today',
  },
);

const primaryRgb = readThemeRgb();

const options: ChartOptions<'line'> = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: { display: false },
    tooltip: {
      callbacks: {
        label: (item) => ` ৳${Number(item.raw).toLocaleString()}`,
      },
    },
  },
  scales: {
    x: {
      grid: { display: false },
      ticks: { color: 'var(--bw-theme-muted)', font: { size: 10, weight: 600 } },
      border: { display: false },
    },
    y: {
      grid: { color: rgba(primaryRgb, 0.08) },
      ticks: {
        color: 'var(--bw-theme-muted)',
        font: { size: 10 },
        callback: (val) => {
          const n = Number(val);
          if (n >= 1000) return `৳${Math.round(n / 1000)}k`;
          return `৳${n}`;
        },
      },
      border: { display: false },
    },
  },
};
</script>

<style scoped>
.dashboard-line-chart {
  width: 100%;
}

.dashboard-line-chart__canvas {
  height: 8rem;
}

.dashboard-line-chart__empty {
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
