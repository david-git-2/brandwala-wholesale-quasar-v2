<template>
  <DashboardPaperDrawer v-model="isOpen" @show="isReady = true" @before-hide="isReady = false">
    <section class="paper-section">
      <div class="paper-section__head">
        <span class="paper-section__title">Capital movement</span>
        <span class="paper-section__meta">Live</span>
      </div>
      <div class="bar-chart-wrap">
        <transition name="chart-fade">
          <Bar v-if="isReady" :data="poolChartData" :options="barOptions" />
        </transition>
      </div>
      <div class="legend-list">
        <div class="legend-row">
          <div class="legend-row__left">
            <span class="ink-dot" style="background: #0284c7" />
            <span class="legend-row__label">Pool</span>
          </div>
          <div class="legend-row__right">
            <span class="legend-row__val">{{ formatDashboardMoney(metrics?.activePoolAmount ?? 0) }}</span>
          </div>
        </div>
        <div class="legend-row">
          <div class="legend-row__left">
            <span class="ink-dot" style="background: #d97706" />
            <span class="legend-row__label">Deployed</span>
          </div>
          <div class="legend-row__right">
            <span class="legend-row__val">{{ formatDashboardMoney(metrics?.deployedAmount ?? 0) }}</span>
          </div>
        </div>
        <div class="legend-row">
          <div class="legend-row__left">
            <span class="ink-dot" style="background: #059669" />
            <span class="legend-row__label">Returned</span>
          </div>
          <div class="legend-row__right">
            <span class="legend-row__val">{{ formatDashboardMoney(metrics?.returnedAmount ?? 0) }}</span>
          </div>
        </div>
      </div>
    </section>

    <div class="paper-rule" />

    <section class="paper-section">
      <div class="paper-section__head">
        <span class="paper-section__title">Open containers</span>
        <span class="paper-section__meta">{{ containerMeta }}</span>
      </div>
      <div class="grade-list">
        <div v-for="row in (metrics?.openContainers ?? [])" :key="row.name" class="grade-row">
          <div class="grade-row__left">
            <span class="grade-row__desc">{{ row.name }}</span>
          </div>
          <span class="grade-row__val">{{ formatDashboardMoney(row.allocatedCost) }}</span>
        </div>
        <p v-if="!(metrics?.openContainers?.length)" class="grade-row__desc">No open containers</p>
      </div>
    </section>
  </DashboardPaperDrawer>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { Bar } from 'vue-chartjs';
import type { ChartData, ChartOptions } from 'chart.js';
import DashboardPaperDrawer from 'src/modules/dashboard/components/DashboardPaperDrawer.vue';
import { ensureDashboardChartsRegistered } from 'src/modules/dashboard/utils/dashboardChartSetup';
import {
  formatDashboardCount,
  formatDashboardMoney,
} from 'src/modules/dashboard/utils/formatDashboardMetric';
import type { InvestorCapitalDashboardMetrics } from '../repositories/investorCapitalDashboardRepository';

ensureDashboardChartsRegistered();

const props = defineProps<{
  modelValue: boolean;
  metrics?: InvestorCapitalDashboardMetrics | null;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
}>();

const isOpen = computed({
  get: () => props.modelValue,
  set: (val: boolean) => emit('update:modelValue', val),
});

const isReady = ref(false);

const containerMeta = computed(
  () => `${formatDashboardCount(props.metrics?.openContainerCount ?? 0)} batches`,
);

const poolChartData = computed<ChartData<'bar'>>(() => ({
  labels: ['Pool', 'Deployed', 'Returned'],
  datasets: [
    {
      label: 'BDT',
      data: [
        props.metrics?.activePoolAmount ?? 0,
        props.metrics?.deployedAmount ?? 0,
        props.metrics?.returnedAmount ?? 0,
      ],
      backgroundColor: ['#0284c7', '#d97706', '#059669'],
      borderRadius: 4,
      borderSkipped: false,
    },
  ],
}));

const barOptions: ChartOptions<'bar'> = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: { display: false },
    tooltip: { backgroundColor: '#1c1917', padding: 6, cornerRadius: 6 },
  },
  scales: {
    x: {
      grid: { display: false },
      ticks: { color: '#57534e', font: { size: 10, weight: 700 } },
      border: { display: false },
    },
    y: {
      grid: { color: 'rgba(214, 204, 188, 0.45)' },
      ticks: { color: '#78716c', font: { size: 10, weight: 600 } },
      border: { display: false },
    },
  },
};
</script>
