<template>
  <div class="dashboard-donut">
    <div v-if="empty" class="dashboard-donut__empty">{{ emptyLabel }}</div>
    <template v-else>
      <div class="dashboard-donut__chart">
        <Doughnut :data="chartData" :options="options" />
        <div v-if="centerValue" class="dashboard-donut__center">
          <span class="dashboard-donut__center-val bw-tabular">{{ centerValue }}</span>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { Doughnut } from 'vue-chartjs';
import type { ChartData, ChartOptions } from 'chart.js';
import { dashboardTooltip, ensureDashboardChartsRegistered } from '../utils/dashboardChartSetup';

ensureDashboardChartsRegistered();

const props = withDefaults(
  defineProps<{
    data: ChartData<'doughnut'>;
    centerValue?: string;
    empty?: boolean;
    emptyLabel?: string;
  }>(),
  {
    emptyLabel: 'No mix yet',
  },
);

const chartData = computed<ChartData<'doughnut'>>(() => ({
  ...props.data,
  datasets: props.data.datasets.map((dataset) => ({
    ...dataset,
    spacing: 2,
  })),
}));

const options: ChartOptions<'doughnut'> = {
  responsive: true,
  maintainAspectRatio: false,
  cutout: '68%',
  plugins: {
    legend: { display: false },
    tooltip: dashboardTooltip(),
  },
};
</script>

<style scoped>
.dashboard-donut {
  width: 100%;
  min-height: 12rem;
}

.dashboard-donut__chart {
  position: relative;
  width: 12rem;
  height: 12rem;
  margin: 0 auto;
}

.dashboard-donut__center {
  position: absolute;
  inset: 0;
  display: grid;
  place-content: center;
  text-align: center;
  pointer-events: none;
}

.dashboard-donut__center-val {
  font-size: 20px;
  font-weight: 700;
  letter-spacing: -0.03em;
  color: var(--bw-theme-ink);
  line-height: 1;
}

.dashboard-donut__empty {
  min-height: 12rem;
  display: grid;
  place-items: center;
  text-align: center;
  font-size: 13px;
  color: var(--bw-theme-muted);
}
</style>
