<template>
  <DashboardPaperDrawer v-model="isOpen" @show="isReady = true" @before-hide="isReady = false">
    <section class="paper-section">
      <div class="paper-section__head">
        <span class="paper-section__title">Who holds the money</span>
        <span class="paper-section__meta">Stub balances</span>
      </div>
      <div class="availability-row">
        <div class="donut-wrap">
          <transition name="chart-fade">
            <Doughnut v-if="isReady" :data="holderChartData" :options="donutOptions" />
          </transition>
          <div class="donut-center">
            <span class="donut-center__val">72%</span>
            <span class="donut-center__sub">Company</span>
          </div>
        </div>
        <div class="legend-list">
          <div class="legend-row">
            <div class="legend-row__left">
              <span class="ink-dot" style="background: #059669" />
              <span class="legend-row__label">Company</span>
            </div>
            <div class="legend-row__right">
              <span class="legend-row__val">৳2.10M</span>
              <span class="legend-row__pct">72%</span>
            </div>
          </div>
          <div class="legend-row">
            <div class="legend-row__left">
              <span class="ink-dot" style="background: #0284c7" />
              <span class="legend-row__label">Customer</span>
            </div>
            <div class="legend-row__right">
              <span class="legend-row__val">৳640K</span>
              <span class="legend-row__pct">22%</span>
            </div>
          </div>
          <div class="legend-row">
            <div class="legend-row__left">
              <span class="ink-dot" style="background: #d97706" />
              <span class="legend-row__label">Courier</span>
            </div>
            <div class="legend-row__right">
              <span class="legend-row__val">৳185K</span>
              <span class="legend-row__pct">6%</span>
            </div>
          </div>
        </div>
      </div>
    </section>

    <div class="paper-rule" />

    <section class="paper-section">
      <div class="paper-section__head">
        <span class="paper-section__title">COD to collect</span>
        <span class="paper-section__meta">৳185K</span>
      </div>
      <div class="grade-list">
        <div class="grade-row">
          <div class="grade-row__left">
            <span class="grade-row__desc">Steadfast · 18 parcels</span>
          </div>
          <span class="grade-row__val">৳92,400</span>
        </div>
        <div class="grade-row">
          <div class="grade-row__left">
            <span class="grade-row__desc">Pathao · 10 parcels</span>
          </div>
          <span class="grade-row__val">৳61,200</span>
        </div>
        <div class="grade-row">
          <div class="grade-row__left">
            <span class="grade-row__desc">In-house courier</span>
          </div>
          <span class="grade-row__val">৳31,400</span>
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
const holderChartData = computed<ChartData<'doughnut'>>(() => ({
  labels: ['Company', 'Customer', 'Courier'],
  datasets: [
    {
      data: [2100, 640, 185],
      backgroundColor: ['#059669', '#0284c7', '#d97706'],
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
