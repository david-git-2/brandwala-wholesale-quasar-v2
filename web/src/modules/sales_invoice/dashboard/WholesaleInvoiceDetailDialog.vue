<template>
  <DashboardPaperDrawer v-model="isOpen" @show="isReady = true" @before-hide="isReady = false">
    <section class="paper-section">
      <div class="paper-section__head">
        <span class="paper-section__title">Invoice mix</span>
        <span class="paper-section__meta">Today · stub</span>
      </div>
      <div class="availability-row">
        <div class="donut-wrap">
          <transition name="chart-fade">
            <Doughnut v-if="isReady" :data="mixChartData" :options="donutOptions" />
          </transition>
          <div class="donut-center">
            <span class="donut-center__val">58%</span>
            <span class="donut-center__sub">Paid</span>
          </div>
        </div>
        <div class="legend-list">
          <div class="legend-row">
            <div class="legend-row__left">
              <span class="ink-dot" style="background: #059669" />
              <span class="legend-row__label">Paid</span>
            </div>
            <div class="legend-row__right">
              <span class="legend-row__val">৳740K</span>
              <span class="legend-row__pct">58%</span>
            </div>
          </div>
          <div class="legend-row">
            <div class="legend-row__left">
              <span class="ink-dot" style="background: #d97706" />
              <span class="legend-row__label">Due</span>
            </div>
            <div class="legend-row__right">
              <span class="legend-row__val">৳390K</span>
              <span class="legend-row__pct">30%</span>
            </div>
          </div>
          <div class="legend-row">
            <div class="legend-row__left">
              <span class="ink-dot" style="background: #dc2626" />
              <span class="legend-row__label">Overdue</span>
            </div>
            <div class="legend-row__right">
              <span class="legend-row__val">৳150K</span>
              <span class="legend-row__pct">12%</span>
            </div>
          </div>
        </div>
      </div>
    </section>

    <div class="paper-rule" />

    <section class="paper-section">
      <div class="paper-section__head">
        <span class="paper-section__title">Overdue customers</span>
        <span class="paper-section__meta">11 invoices</span>
      </div>
      <div class="grade-list">
        <div class="grade-row">
          <div class="grade-row__left">
            <span class="grade-row__desc">Riverside Traders</span>
          </div>
          <span class="grade-row__val">৳48,200</span>
        </div>
        <div class="grade-row">
          <div class="grade-row__left">
            <span class="grade-row__desc">North Gate Wholesale</span>
          </div>
          <span class="grade-row__val">৳36,750</span>
        </div>
        <div class="grade-row">
          <div class="grade-row__left">
            <span class="grade-row__desc">Lakeview Mart</span>
          </div>
          <span class="grade-row__val">৳21,400</span>
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
const mixChartData = computed<ChartData<'doughnut'>>(() => ({
  labels: ['Paid', 'Due', 'Overdue'],
  datasets: [
    {
      data: [740, 390, 150],
      backgroundColor: ['#059669', '#d97706', '#dc2626'],
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
