<template>
  <q-card flat bordered class="q-pa-md report-section">
    <div class="text-subtitle2 text-weight-bold q-mb-sm">From sales to profit</div>
    <div v-if="!hasData" class="text-caption" style="color: var(--tf-neutral-muted)">
      No sales or costs yet.
    </div>
    <template v-else>
      <div class="bridge-chart-wrap" :style="{ height: `${chartHeight}px` }">
        <Bar :data="chartData" :options="chartOptions" />
      </div>
      <div class="text-caption q-mt-sm tf-num" style="color: var(--tf-neutral-chrome-text)">
        {{ formulaLine }}
      </div>
    </template>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { Bar } from 'vue-chartjs';
import type { ChartData, ChartOptions } from 'chart.js';
import { formatSettlementCurrencyAmount } from 'src/utils/currency';
import type { ShipmentReportBridgeStep } from '../../composables/useShipmentReportView';
import {
  chartEarnedColor,
  chartProfitColor,
  colorForCostKind,
  colorFromToken,
  ensureShipmentReportChartsRegistered,
  readCssVar,
  shipmentReportTooltip,
} from './shipmentReportChartSetup';

ensureShipmentReportChartsRegistered();

const props = defineProps<{
  steps: ShipmentReportBridgeStep[];
  totalSell: number;
  totalCost: number;
  profit: number;
  hasVendorCredits?: boolean;
  grossCost?: number;
}>();

const hasData = computed(() => props.totalSell > 0.009 || props.totalCost > 0.009);

function money(n: number) {
  return formatSettlementCurrencyAmount(n, 'BDT');
}

const formulaLine = computed(() => {
  const base = `${money(props.totalSell)} earned − ${money(props.totalCost)} spent = ${money(props.profit)} ${props.hasVendorCredits ? 'net profit' : 'profit'}`;
  if (props.hasVendorCredits && props.grossCost != null && props.grossCost > props.totalCost + 0.009) {
    return `${base} (gross cost ${money(props.grossCost)})`;
  }
  return base;
});

const chartHeight = computed(() => {
  const costCount = props.steps.filter((s) => s.kind === 'cost' || s.kind === 'credit').length;
  return Math.min(320, Math.max(200, 44 * (2 + costCount)));
});

const chartData = computed((): ChartData<'bar'> => {
  const sell = props.totalSell;
  const midSteps = props.steps.filter((s) => s.kind === 'cost' || s.kind === 'credit');
  const labels: string[] = [];
  const floating: [number, number][] = [];
  const bg: string[] = [];
  const borders: string[] = [];

  labels.push('Earned');
  floating.push([0, sell]);
  bg.push(chartEarnedColor(0.88));
  borders.push(colorFromToken('--tf-info', 1));

  let cursor = sell;
  for (const c of midSteps) {
    labels.push(c.label);
    if (c.kind === 'credit') {
      floating.push([cursor, cursor + c.amount]);
      cursor += c.amount;
      bg.push(colorFromToken('--tf-positive-soft', 0.95, '#dcfce7'));
      borders.push(colorFromToken('--tf-positive', 1, '#16a34a'));
    } else {
      floating.push([cursor - c.amount, cursor]);
      cursor -= c.amount;
      bg.push(colorForCostKind(c.key, 0.82));
      borders.push(colorForCostKind(c.key, 1));
    }
  }

  const profit = props.profit;
  labels.push('Profit');
  floating.push(profit >= 0 ? [0, profit] : [profit, 0]);
  bg.push(chartProfitColor(profit, 0.9));
  borders.push(chartProfitColor(profit, 1));

  return {
    labels,
    datasets: [
      {
        data: floating,
        backgroundColor: bg,
        borderColor: borders,
        borderWidth: 1,
        borderRadius: 6,
        borderSkipped: false,
        barPercentage: 0.72,
        categoryPercentage: 0.82,
      },
    ],
  };
});

const chartOptions = computed(
  (): ChartOptions<'bar'> => ({
    indexAxis: 'y',
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { display: false },
      tooltip: {
        ...shipmentReportTooltip(),
        callbacks: {
          label(ctx) {
            const raw = ctx.raw as [number, number];
            const diff = Math.abs(raw[1] - raw[0]);
            return money(diff);
          },
        },
      },
    },
    scales: {
      x: {
        beginAtZero: true,
        grid: {
          color: colorFromToken('--tf-neutral-border', 0.6, '#e2e8f0'),
          tickLength: 0,
        },
        border: { display: false },
        ticks: {
          font: { size: 10, family: 'var(--tf-font-ui)' },
          color: readCssVar('--tf-neutral-chrome-text', '#64748b'),
          maxTicksLimit: 6,
          callback: (v) => {
            const n = Number(v);
            if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
            if (n >= 1_000) return `${(n / 1_000).toFixed(0)}k`;
            return String(n);
          },
        },
      },
      y: {
        grid: { display: false },
        border: { display: false },
        ticks: {
          font: { size: 12, weight: 600, family: 'var(--tf-font-ui)' },
          color: readCssVar('--tf-neutral-ink', '#0f172a'),
          padding: 8,
        },
      },
    },
  }),
);
</script>

<style scoped>
.report-section {
  background: var(--tf-neutral-surface);
  border-radius: var(--tf-radius-md, 12px);
}

.bridge-chart-wrap {
  width: 100%;
}
</style>