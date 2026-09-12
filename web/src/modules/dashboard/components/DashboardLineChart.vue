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
import {
  dashboardTooltip,
  ensureDashboardChartsRegistered,
  readThemeRgb,
  rgba,
} from '../utils/dashboardChartSetup';

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
      ...dashboardTooltip(),
      callbacks: {
        label: (item) => `৳${Number(item.raw).toLocaleString()}`,
      },
    },
  },
  scales: {
    x: { display: false },
    y: { display: false },
  },
  elements: {
    point: { radius: 0, hoverRadius: 0 },
    line: {
      borderWidth: 2,
      borderColor: rgba(primaryRgb, 1),
      backgroundColor: rgba(primaryRgb, 0.16),
    },
  },
};
</script>

<style scoped>
.dashboard-line-chart {
  width: 100%;
  min-width: 0;
  max-width: 100%;
  overflow: hidden;
}

.dashboard-line-chart__canvas {
  position: relative;
  height: 7.5rem;
  min-width: 0;
  max-width: 100%;
  overflow: hidden;
}

.dashboard-line-chart__empty {
  height: 7.5rem;
  display: grid;
  place-items: center;
  text-align: center;
  font-size: 13px;
  color: var(--bw-theme-muted);
}
</style>
