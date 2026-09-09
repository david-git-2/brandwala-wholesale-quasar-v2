<template>
  <DashboardPaperDrawer v-model="isOpen" @show="isReady = true" @before-hide="isReady = false">
    <section class="paper-section">
      <div class="paper-section__head">
        <span class="paper-section__title">Cases by status</span>
        <span class="paper-section__meta">27 open · stub</span>
      </div>
      <div class="bar-chart-wrap">
        <transition name="chart-fade">
          <Bar v-if="isReady" :data="statusChartData" :options="barOptions" />
        </transition>
      </div>
      <div class="grade-list">
        <div class="grade-row">
          <div class="grade-row__left">
            <span class="grade-row__desc">Pending approval</span>
          </div>
          <span class="grade-row__val">8</span>
        </div>
        <div class="grade-row">
          <div class="grade-row__left">
            <span class="grade-row__desc">Awaiting receipt</span>
          </div>
          <span class="grade-row__val">9</span>
        </div>
        <div class="grade-row">
          <div class="grade-row__left">
            <span class="grade-row__desc">Inspecting</span>
          </div>
          <span class="grade-row__val">5</span>
        </div>
        <div class="grade-row">
          <div class="grade-row__left">
            <span class="grade-row__desc">Closed this month</span>
          </div>
          <span class="grade-row__val">14</span>
        </div>
      </div>
    </section>

    <div class="paper-rule" />

    <section class="paper-section">
      <div class="paper-section__head">
        <span class="paper-section__title">Channel split</span>
        <span class="paper-section__meta">Open cases</span>
      </div>
      <div class="legend-list">
        <div class="legend-row">
          <div class="legend-row__left">
            <span class="ink-dot" style="background: #7c3aed" />
            <span class="legend-row__label">Wholesale</span>
          </div>
          <div class="legend-row__right">
            <span class="legend-row__val">18</span>
            <span class="legend-row__pct">67%</span>
          </div>
        </div>
        <div class="legend-row">
          <div class="legend-row__left">
            <span class="ink-dot" style="background: #0d9488" />
            <span class="legend-row__label">Dropship</span>
          </div>
          <div class="legend-row__right">
            <span class="legend-row__val">9</span>
            <span class="legend-row__pct">33%</span>
          </div>
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
const statusChartData = computed<ChartData<'bar'>>(() => ({
  labels: ['Pending', 'Receipt', 'Inspect', 'Closed'],
  datasets: [
    {
      label: 'Cases',
      data: [8, 9, 5, 14],
      backgroundColor: ['#d97706', '#0284c7', '#7c3aed', '#059669'],
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
