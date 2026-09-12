<template>
  <div class="dashboard-donut">
    <div v-if="empty" class="dashboard-donut__empty">{{ emptyLabel }}</div>
    <template v-else>
      <div class="dashboard-donut__chart">
        <Doughnut :data="data" :options="options" />
        <div v-if="centerValue || centerCaption" class="dashboard-donut__center">
          <span v-if="centerValue" class="dashboard-donut__center-val bw-tabular">{{ centerValue }}</span>
          <span v-if="centerCaption" class="dashboard-donut__center-caption">{{ centerCaption }}</span>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { Doughnut } from 'vue-chartjs';
import type { ChartData, ChartOptions } from 'chart.js';
import { ensureDashboardChartsRegistered } from '../utils/dashboardChartSetup';

ensureDashboardChartsRegistered();

const props = withDefaults(
  defineProps<{
    data: ChartData<'doughnut'>;
    centerValue?: string;
    centerCaption?: string;
    empty?: boolean;
    emptyLabel?: string;
  }>(),
  {
    emptyLabel: 'No mix yet',
  },
);

const options: ChartOptions<'doughnut'> = {
  responsive: true,
  maintainAspectRatio: false,
  cutout: '76%',
  plugins: {
    legend: { display: false },
    tooltip: {
      callbacks: {
        label: (ctx) => ` ${ctx.label}: ${Number(ctx.parsed).toLocaleString()}`,
      },
    },
  },
};
</script>

<style scoped>
.dashboard-donut {
  width: 100%;
  min-height: 10.5rem;
}

.dashboard-donut__chart {
  position: relative;
  width: 10.5rem;
  height: 10.5rem;
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
  font-size: 1.35rem;
  font-weight: 700;
  letter-spacing: -0.03em;
  color: var(--bw-theme-ink);
  line-height: 1;
}

.dashboard-donut__center-caption {
  margin-top: 0.2rem;
  font-size: 0.68rem;
  color: var(--bw-theme-muted);
  text-transform: uppercase;
  letter-spacing: 0.06em;
}

.dashboard-donut__empty {
  min-height: 10.5rem;
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
