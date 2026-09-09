<template>
  <q-card flat bordered class="hub-summary-chart q-pa-md">
    <div class="hub-summary-chart__header">
      <div>
        <h2 class="hub-summary-chart__title">After-sales summary</h2>
        <p class="hub-summary-chart__subtitle">Click a bar to open that queue.</p>
      </div>
      <div class="hub-summary-chart__total">
        <span class="hub-summary-chart__total-value">{{ kpis.open_cases }}</span>
        <span class="hub-summary-chart__total-label">open cases</span>
      </div>
    </div>

    <div class="hub-summary-chart__canvas-wrap">
      <Bar :data="barData" :options="barOptions" />
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { Bar } from 'vue-chartjs';
import type { ChartData, ChartOptions } from 'chart.js';

import {
  ensureDashboardChartsRegistered,
  readThemeRgb,
  rgba,
} from 'src/modules/dashboard/utils/dashboardChartSetup';
import type { AfterSalesHubSummary } from '../types/afterSales.types';

ensureDashboardChartsRegistered();

type MetricKey = keyof AfterSalesHubSummary;

type MetricRow = {
  key: MetricKey;
  label: string;
  color: string;
  path: string;
  value: number;
};

const props = defineProps<{
  kpis: AfterSalesHubSummary;
}>();

const emit = defineEmits<{
  (e: 'navigate', path: string): void;
}>();

const primaryRgb = computed(() => readThemeRgb());

const metricRows = computed<MetricRow[]>(() => [
  {
    key: 'pending_approval',
    label: 'Pending approval',
    color: '#d97706',
    path: 'after-sales/cases?status=pending_approval',
    value: props.kpis.pending_approval,
  },
  {
    key: 'awaiting_receipt',
    label: 'Awaiting receipt',
    color: '#0284c7',
    path: 'after-sales/cases?status=awaiting_receipt',
    value: props.kpis.awaiting_receipt,
  },
  {
    key: 'wholesale_count',
    label: 'Wholesale open',
    color: '#7c3aed',
    path: 'after-sales/cases?channel=wholesale',
    value: props.kpis.wholesale_count,
  },
  {
    key: 'dropship_count',
    label: 'Dropship open',
    color: '#0d9488',
    path: 'after-sales/cases?channel=dropship',
    value: props.kpis.dropship_count,
  },
  {
    key: 'closed_this_month',
    label: 'Closed this month',
    color: '#059669',
    path: 'after-sales/cases?status=closed',
    value: props.kpis.closed_this_month,
  },
  {
    key: 'open_cases',
    label: 'All open',
    color: rgba(primaryRgb.value, 0.85),
    path: 'after-sales/cases',
    value: props.kpis.open_cases,
  },
]);

const barData = computed<ChartData<'bar'>>(() => ({
  labels: metricRows.value.map((row) => row.label),
  datasets: [
    {
      data: metricRows.value.map((row) => row.value),
      backgroundColor: metricRows.value.map((row) => row.color),
      borderRadius: 6,
      borderSkipped: false,
      maxBarThickness: 28,
    },
  ],
}));

const barOptions = computed<ChartOptions<'bar'>>(() => ({
  indexAxis: 'y',
  responsive: true,
  maintainAspectRatio: false,
  onClick: (_event, elements) => {
    const index = elements[0]?.index;
    if (index == null) return;
    const row = metricRows.value[index];
    if (row) emitNavigate(row.path);
  },
  onHover: (event, elements) => {
    const target = event.native?.target as HTMLElement | undefined;
    if (target) target.style.cursor = elements.length ? 'pointer' : 'default';
  },
  plugins: {
    legend: { display: false },
    tooltip: {
      callbacks: {
        label: (ctx) => ` ${ctx.parsed.x ?? 0}`,
      },
    },
  },
  scales: {
    x: {
      beginAtZero: true,
      grid: { color: 'rgba(148, 163, 184, 0.25)' },
      ticks: {
        color: 'var(--bw-theme-muted)',
        font: { size: 11, weight: 600 },
        precision: 0,
      },
      border: { display: false },
    },
    y: {
      grid: { display: false },
      ticks: {
        color: 'var(--bw-theme-ink)',
        font: { size: 11, weight: 600 },
      },
      border: { display: false },
    },
  },
}));

const emitNavigate = (path: string) => {
  emit('navigate', path);
};
</script>

<style scoped>
.hub-summary-chart {
  border-radius: 14px;
  background: var(--bw-theme-surface);
}

.hub-summary-chart__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1rem;
}

.hub-summary-chart__title {
  margin: 0;
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--bw-theme-muted);
}

.hub-summary-chart__subtitle {
  margin: 0.25rem 0 0;
  font-size: 0.78rem;
  color: var(--bw-theme-muted);
}

.hub-summary-chart__total {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 0.1rem;
  flex-shrink: 0;
}

.hub-summary-chart__total-value {
  font-size: 1.75rem;
  font-weight: 800;
  line-height: 1;
  color: var(--bw-theme-primary);
  font-variant-numeric: tabular-nums;
}

.hub-summary-chart__total-label {
  font-size: 0.68rem;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--bw-theme-muted);
}

.hub-summary-chart__canvas-wrap {
  min-height: 240px;
  position: relative;
}
</style>
