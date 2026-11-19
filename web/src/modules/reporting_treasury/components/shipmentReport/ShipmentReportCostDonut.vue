<template>
  <q-card flat bordered class="q-pa-md report-section">
    <div class="text-subtitle2 text-weight-bold q-mb-sm">Cost by type</div>
    <div v-if="!slices.length" class="text-caption" style="color: var(--tf-neutral-muted)">
      No costs recorded.
    </div>
    <div v-else class="row items-center q-col-gutter-md">
      <div class="col-12 col-sm-5">
        <div class="donut-wrap">
          <Doughnut :data="chartData" :options="donutOptions" />
          <div class="donut-center">
            <span class="donut-center__val tf-num">{{ money(totalCostBdt) }}</span>
            <span class="donut-center__sub">Total spent</span>
          </div>
        </div>
      </div>
      <div class="col-12 col-sm-7">
        <div
          v-for="slice in slices"
          :key="slice.key"
          class="legend-row row items-center no-wrap q-mb-xs"
        >
          <span
            class="legend-dot"
            :style="{ background: colorForCostKind(slice.key, 1) }"
          />
          <span class="col text-caption text-weight-medium">{{ slice.label }}</span>
          <span class="tf-num text-caption text-weight-bold">{{ money(slice.amount) }}</span>
          <span class="tf-num text-caption q-ml-sm" style="color: var(--tf-neutral-muted)">
            {{ slice.sharePct }}%
          </span>
        </div>
      </div>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { Doughnut } from 'vue-chartjs';
import type { ChartData, ChartOptions } from 'chart.js';
import { formatSettlementCurrencyAmount } from 'src/utils/currency';
import type { ShipmentReportDonutSlice } from '../../composables/useShipmentReportView';
import {
  colorForCostKind,
  colorFromToken,
  ensureShipmentReportChartsRegistered,
  shipmentReportTooltip,
} from './shipmentReportChartSetup';

ensureShipmentReportChartsRegistered();

const props = withDefaults(
  defineProps<{
    slices: ShipmentReportDonutSlice[];
    totalCostBdt?: number;
  }>(),
  { totalCostBdt: 0 },
);

function money(n: number) {
  return formatSettlementCurrencyAmount(n, 'BDT');
}

const surfaceBorder = computed(() =>
  colorFromToken('--tf-neutral-surface', 1, '#ffffff'),
);

const chartData = computed((): ChartData<'doughnut'> => ({
  labels: props.slices.map((s) => s.label),
  datasets: [
    {
      data: props.slices.map((s) => s.amount),
      backgroundColor: props.slices.map((s) => colorForCostKind(s.key, 0.88)),
      borderColor: surfaceBorder.value,
      borderWidth: 3,
      hoverBorderWidth: 3,
      hoverOffset: 6,
    },
  ],
}));

const donutOptions = computed(
  (): ChartOptions<'doughnut'> => ({
    responsive: true,
    maintainAspectRatio: true,
    cutout: '58%',
    plugins: {
      legend: { display: false },
      tooltip: {
        ...shipmentReportTooltip(),
        callbacks: {
          label(ctx) {
            const slice = props.slices[ctx.dataIndex];
            return `${slice?.label ?? ''}: ${money(Number(ctx.raw))} (${slice?.sharePct ?? 0}%)`;
          },
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

.donut-wrap {
  position: relative;
  max-width: 220px;
  margin: 0 auto;
}

.donut-center {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  pointer-events: none;
  text-align: center;
  padding: 0 12px;
}

.donut-center__val {
  font-size: 15px;
  font-weight: 700;
  color: var(--tf-neutral-ink);
  line-height: 1.2;
}

.donut-center__sub {
  font-size: 11px;
  font-weight: 600;
  color: var(--tf-neutral-muted);
  margin-top: 2px;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

.legend-dot {
  width: 10px;
  height: 10px;
  border-radius: 2px;
  margin-right: 8px;
  flex-shrink: 0;
}

.legend-row {
  border-bottom: 1px solid var(--tf-neutral-border);
  padding-bottom: 4px;
}

.legend-row:last-child {
  border-bottom: none;
}
</style>