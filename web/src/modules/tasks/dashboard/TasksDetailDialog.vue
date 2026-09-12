<template>
  <DashboardPaperDrawer v-model="isOpen" @show="isReady = true" @before-hide="isReady = false">
    <section class="paper-section">
      <div class="paper-section__head">
        <span class="paper-section__title">My board</span>
        <span class="paper-section__meta">{{ assignedMeta }}</span>
      </div>
      <div class="availability-row">
        <div class="donut-wrap">
          <transition name="chart-fade">
            <Doughnut v-if="isReady" :data="statusChartData" :options="donutOptions" />
          </transition>
          <div class="donut-center">
            <span class="donut-center__val">{{ assignedLabel }}</span>
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
                  <span class="legend-row__val">{{ formatDashboardCount(metrics?.myTodo ?? 0) }}</span>
                  <span class="legend-row__pct">{{ todoPct }}%</span>
            </div>
          </div>
          <div class="legend-row">
            <div class="legend-row__left">
              <span class="ink-dot" style="background: #d97706" />
              <span class="legend-row__label">Doing</span>
            </div>
            <div class="legend-row__right">
                  <span class="legend-row__val">{{ formatDashboardCount(metrics?.myDoing ?? 0) }}</span>
                  <span class="legend-row__pct">{{ doingPct }}%</span>
            </div>
          </div>
          <div class="legend-row">
            <div class="legend-row__left">
              <span class="ink-dot" style="background: #dc2626" />
              <span class="legend-row__label">Stuck</span>
            </div>
            <div class="legend-row__right">
                  <span class="legend-row__val">{{ formatDashboardCount(metrics?.myStuck ?? 0) }}</span>
                  <span class="legend-row__pct">{{ stuckPct }}%</span>
            </div>
          </div>
          <div class="legend-row">
            <div class="legend-row__left">
              <span class="ink-dot" style="background: #059669" />
              <span class="legend-row__label">Done</span>
            </div>
            <div class="legend-row__right">
                  <span class="legend-row__val">{{ formatDashboardCount(metrics?.myDone ?? 0) }}</span>
                  <span class="legend-row__pct">{{ donePct }}%</span>
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
import {
  dashboardSharePct,
  formatDashboardCount,
} from 'src/modules/dashboard/utils/formatDashboardMetric';
import type { TasksDashboardMetrics } from '../repositories/tasksDashboardRepository';

ensureDashboardChartsRegistered();

const props = defineProps<{
  modelValue: boolean;
  metrics?: TasksDashboardMetrics | null;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
}>();

const isOpen = computed({
  get: () => props.modelValue,
  set: (val: boolean) => emit('update:modelValue', val),
});

const isReady = ref(false);

const myTotal = computed(
  () =>
    (props.metrics?.myTodo ?? 0) +
    (props.metrics?.myDoing ?? 0) +
    (props.metrics?.myStuck ?? 0) +
    (props.metrics?.myDone ?? 0),
);
const assignedLabel = computed(() => formatDashboardCount(props.metrics?.assignedToMe ?? 0));
const assignedMeta = computed(() => `${assignedLabel.value} assigned`);
const todoPct = computed(() => dashboardSharePct(props.metrics?.myTodo ?? 0, myTotal.value));
const doingPct = computed(() => dashboardSharePct(props.metrics?.myDoing ?? 0, myTotal.value));
const stuckPct = computed(() => dashboardSharePct(props.metrics?.myStuck ?? 0, myTotal.value));
const donePct = computed(() => dashboardSharePct(props.metrics?.myDone ?? 0, myTotal.value));

const statusChartData = computed<ChartData<'doughnut'>>(() => ({
  labels: ['Open', 'Doing', 'Stuck', 'Done'],
  datasets: [
    {
      data: [
        props.metrics?.myTodo ?? 0,
        props.metrics?.myDoing ?? 0,
        props.metrics?.myStuck ?? 0,
        props.metrics?.myDone ?? 0,
      ],
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
