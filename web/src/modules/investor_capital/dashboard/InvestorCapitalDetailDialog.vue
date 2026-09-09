<template>
  <DashboardPaperDrawer v-model="isOpen" @show="isReady = true" @before-hide="isReady = false">
    <section class="paper-section">
      <div class="paper-section__head">
        <span class="paper-section__title">Capital movement</span>
        <span class="paper-section__meta">Stub</span>
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
            <span class="legend-row__val">৳12.4M</span>
          </div>
        </div>
        <div class="legend-row">
          <div class="legend-row__left">
            <span class="ink-dot" style="background: #d97706" />
            <span class="legend-row__label">Deployed</span>
          </div>
          <div class="legend-row__right">
            <span class="legend-row__val">৳1.8M</span>
          </div>
        </div>
        <div class="legend-row">
          <div class="legend-row__left">
            <span class="ink-dot" style="background: #059669" />
            <span class="legend-row__label">Returned</span>
          </div>
          <div class="legend-row__right">
            <span class="legend-row__val">৳640K</span>
          </div>
        </div>
      </div>
    </section>

    <div class="paper-rule" />

    <section class="paper-section">
      <div class="paper-section__head">
        <span class="paper-section__title">Open containers</span>
        <span class="paper-section__meta">3 batches</span>
      </div>
      <div class="grade-list">
        <div class="grade-row">
          <div class="grade-row__left">
            <span class="grade-row__desc">CNT-204 · China fabric</span>
          </div>
          <span class="grade-row__val">৳720K</span>
        </div>
        <div class="grade-row">
          <div class="grade-row__left">
            <span class="grade-row__desc">CNT-211 · Electronics</span>
          </div>
          <span class="grade-row__val">৳640K</span>
        </div>
        <div class="grade-row">
          <div class="grade-row__left">
            <span class="grade-row__desc">CNT-218 · Home goods</span>
          </div>
          <span class="grade-row__val">৳440K</span>
        </div>
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

ensureDashboardChartsRegistered();

const props = defineProps<{
  modelValue: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
}>();

const isOpen = computed({
  get: () => props.modelValue,
  set: (val: boolean) => emit('update:modelValue', val),
});

const isReady = ref(false);

// stub until live RPC
const poolChartData = computed<ChartData<'bar'>>(() => ({
  labels: ['Pool', 'Deployed', 'Returned'],
  datasets: [
    {
      label: 'BDT (K)',
      data: [12400, 1800, 640],
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
