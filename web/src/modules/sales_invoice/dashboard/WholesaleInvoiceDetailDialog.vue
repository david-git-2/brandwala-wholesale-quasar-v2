<template>
  <DashboardPaperDrawer v-model="isOpen" @show="isReady = true" @before-hide="isReady = false">
    <section class="paper-section">
      <div class="paper-section__head">
        <span class="paper-section__title">Invoice mix</span>
        <span class="paper-section__meta">Open invoices</span>
      </div>
      <div class="availability-row">
        <div class="donut-wrap">
          <transition name="chart-fade">
            <Doughnut v-if="isReady" :data="mixChartData" :options="donutOptions" />
          </transition>
          <div class="donut-center">
            <span class="donut-center__val">{{ paidPct }}%</span>
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
                  <span class="legend-row__val">{{ formatDashboardMoney(metrics?.paidAmount ?? 0) }}</span>
                  <span class="legend-row__pct">{{ paidPct }}%</span>
            </div>
          </div>
          <div class="legend-row">
            <div class="legend-row__left">
              <span class="ink-dot" style="background: #d97706" />
              <span class="legend-row__label">Due</span>
            </div>
            <div class="legend-row__right">
                  <span class="legend-row__val">{{ formatDashboardMoney(metrics?.dueAmount ?? 0) }}</span>
                  <span class="legend-row__pct">{{ duePct }}%</span>
            </div>
          </div>
          <div class="legend-row">
            <div class="legend-row__left">
              <span class="ink-dot" style="background: #dc2626" />
              <span class="legend-row__label">Overdue</span>
            </div>
            <div class="legend-row__right">
                  <span class="legend-row__val">{{ formatDashboardMoney(metrics?.overdueAmount ?? 0) }}</span>
                  <span class="legend-row__pct">{{ overduePct }}%</span>
            </div>
          </div>
        </div>
      </div>
    </section>

    <div class="paper-rule" />

    <section class="paper-section">
      <div class="paper-section__head">
        <span class="paper-section__title">Overdue customers</span>
        <span class="paper-section__meta">{{ overdueCountLabel }}</span>
      </div>
      <div class="grade-list">
        <div v-for="row in (metrics?.overdueCustomers ?? [])" :key="row.name" class="grade-row">
          <div class="grade-row__left">
            <span class="grade-row__desc">{{ row.name }}</span>
          </div>
          <span class="grade-row__val">{{ formatDashboardMoneyFull(row.dueAmount) }}</span>
        </div>
        <p v-if="!(metrics?.overdueCustomers?.length)" class="grade-row__desc">No overdue customers</p>
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
  formatDashboardMoney,
  formatDashboardMoneyFull,
} from 'src/modules/dashboard/utils/formatDashboardMetric';
import type { SalesInvoiceDashboardMetrics } from '../repositories/salesInvoiceDashboardRepository';

ensureDashboardChartsRegistered();

const props = defineProps<{
  modelValue: boolean;
  metrics?: SalesInvoiceDashboardMetrics | null;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: boolean): void;
}>();

const isOpen = computed({
  get: () => props.modelValue,
  set: (val: boolean) => emit('update:modelValue', val),
});

const isReady = ref(false);

const mixTotal = computed(
  () =>
    (props.metrics?.paidAmount ?? 0) +
    (props.metrics?.dueAmount ?? 0) +
    (props.metrics?.overdueAmount ?? 0),
);
const paidPct = computed(() => dashboardSharePct(props.metrics?.paidAmount ?? 0, mixTotal.value));
const duePct = computed(() => dashboardSharePct(props.metrics?.dueAmount ?? 0, mixTotal.value));
const overduePct = computed(() =>
  dashboardSharePct(props.metrics?.overdueAmount ?? 0, mixTotal.value),
);
const overdueCountLabel = computed(
  () => `${formatDashboardCount(props.metrics?.overdueCount ?? 0)} invoices`,
);

const mixChartData = computed<ChartData<'doughnut'>>(() => ({
  labels: ['Paid', 'Due', 'Overdue'],
  datasets: [
    {
      data: [
        props.metrics?.paidAmount ?? 0,
        props.metrics?.dueAmount ?? 0,
        props.metrics?.overdueAmount ?? 0,
      ],
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
