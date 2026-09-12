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
import { dashboardTooltip, ensureDashboardChartsRegistered } from '../utils/dashboardChartSetup';

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

const chartOptions = computed<ChartOptions<'bar'>>(() => ({
  indexAxis: props.indexAxis,
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: { display: false },
    tooltip: dashboardTooltip(),
  },
  datasets: {
    bar: {
      maxBarThickness: 12,
      borderRadius: 4,
    },
  },
  scales: {
    x: {
      display: props.indexAxis === 'x',
      grid: { display: false },
      ticks: {
        color: 'var(--bw-theme-muted)',
        font: { size: 11, weight: 500 },
      },
      border: { display: false },
    },
    y: {
      display: props.indexAxis === 'y',
      grid: { display: false },
      ticks: {
        color: 'var(--bw-theme-muted)',
        font: { size: 11, weight: 500 },
      },
      border: { display: false },
    },
  },
}));
</script>

<style scoped>
.dashboard-bar-chart {
  width: 100%;
  min-width: 0;
  max-width: 100%;
  overflow: hidden;
}

.dashboard-bar-chart__canvas {
  position: relative;
  height: 7.5rem;
  min-width: 0;
  max-width: 100%;
  overflow: hidden;
}

.dashboard-bar-chart__empty {
  height: 7.5rem;
  display: grid;
  place-items: center;
  text-align: center;
  font-size: 13px;
  color: var(--bw-theme-muted);
}
</style>
