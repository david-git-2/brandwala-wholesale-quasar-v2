<template>
  <DashboardPaperDrawer v-model="isOpen" @show="isReady = true" @before-hide="isReady = false">
    <section class="paper-section">
      <div class="paper-section__head">
        <span class="paper-section__title">My board</span>
        <span class="paper-section__meta">14 assigned · stub</span>
      </div>
      <div class="availability-row">
        <div class="donut-wrap">
          <transition name="chart-fade">
            <Doughnut v-if="isReady" :data="statusChartData" :options="donutOptions" />
          </transition>
          <div class="donut-center">
            <span class="donut-center__val">14</span>
            <span class="donut-center__sub">Mine</span>
          </div>
        </div>
        <div class="legend-list">
          <div class="legend-row">
            <div class="legend-row__left">
              <span class="ink-dot" style="background: #0284c7" />
              <span class="legend-row__label">Open</span>
            </div>
            <div class="legend-row__right">
              <span class="legend-row__val">5</span>
              <span class="legend-row__pct">36%</span>
            </div>
          </div>
          <div class="legend-row">
            <div class="legend-row__left">
              <span class="ink-dot" style="background: #d97706" />
              <span class="legend-row__label">Doing</span>
            </div>
            <div class="legend-row__right">
              <span class="legend-row__val">4</span>
              <span class="legend-row__pct">29%</span>
            </div>
          </div>
          <div class="legend-row">
            <div class="legend-row__left">
              <span class="ink-dot" style="background: #dc2626" />
              <span class="legend-row__label">Stuck</span>
            </div>
            <div class="legend-row__right">
              <span class="legend-row__val">2</span>
              <span class="legend-row__pct">14%</span>
            </div>
          </div>
          <div class="legend-row">
            <div class="legend-row__left">
              <span class="ink-dot" style="background: #059669" />
              <span class="legend-row__label">Done</span>
            </div>
            <div class="legend-row__right">
              <span class="legend-row__val">3</span>
              <span class="legend-row__pct">21%</span>
            </div>
          </div>
        </div>
      </div>
    </section>
  </DashboardPaperDrawer>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { Doughnut } from 'vue-chartjs';
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
const statusChartData = computed<ChartData<'doughnut'>>(() => ({
  labels: ['Open', 'Doing', 'Stuck', 'Done'],
  datasets: [
    {
      data: [5, 4, 2, 3],
      backgroundColor: ['#0284c7', '#d97706', '#dc2626', '#059669'],
      borderWidth: 0,
      hoverOffset: 3,
    },
  ],
}));

const donutOptions: ChartOptions<'doughnut'> = {
  responsive: true,
  maintainAspectRatio: false,
  cutout: '72%',
  plugins: {
    legend: { display: false },
    tooltip: { backgroundColor: '#1c1917', padding: 8, cornerRadius: 6 },
  },
};
</script>
