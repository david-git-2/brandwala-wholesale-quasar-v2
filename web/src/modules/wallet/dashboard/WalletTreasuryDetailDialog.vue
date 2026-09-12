<template>
  <DashboardPaperDrawer v-model="isOpen" @show="isReady = true" @before-hide="isReady = false">
    <section class="paper-section">
      <div class="paper-section__head">
        <span class="paper-section__title">Who holds the money</span>
        <span class="paper-section__meta">Live balances</span>
      </div>
      <div class="availability-row">
        <div class="donut-wrap">
          <transition name="chart-fade">
            <Doughnut v-if="isReady" :data="holderChartData" :options="donutOptions" />
          </transition>
          <div class="donut-center">
            <span class="donut-center__val">{{ companyPct }}%</span>
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
                  <span class="legend-row__val">{{ formatDashboardMoney(summary?.tenant_cash_total ?? 0) }}</span>
                  <span class="legend-row__pct">{{ companyPct }}%</span>
            </div>
          </div>
          <div class="legend-row">
            <div class="legend-row__left">
              <span class="ink-dot" style="background: #0284c7" />
              <span class="legend-row__label">Customer</span>
            </div>
            <div class="legend-row__right">
                  <span class="legend-row__val">{{ formatDashboardMoney(summary?.customer_deposits_total ?? 0) }}</span>
                  <span class="legend-row__pct">{{ customerPct }}%</span>
            </div>
          </div>
          <div class="legend-row">
            <div class="legend-row__left">
              <span class="ink-dot" style="background: #d97706" />
              <span class="legend-row__label">Courier</span>
            </div>
            <div class="legend-row__right">
                  <span class="legend-row__val">{{ formatDashboardMoney(summary?.courier_cod_holding_total ?? 0) }}</span>
                  <span class="legend-row__pct">{{ courierPct }}%</span>
            </div>
          </div>
        </div>
      </div>
    </section>

    <div class="paper-rule" />

    <section class="paper-section">
      <div class="paper-section__head">
        <span class="paper-section__title">Pending vs ready</span>
        <span class="paper-section__meta">{{ formatDashboardMoney(summary?.merchant_pending_total ?? 0) }}</span>
      </div>
      <div class="grade-list">
        <div class="grade-row">
          <div class="grade-row__left">
            <span class="grade-row__desc">Merchant pending payouts</span>
          </div>
          <span class="grade-row__val">{{ formatDashboardMoneyFull(summary?.merchant_pending_total ?? 0) }}</span>
        </div>
        <div class="grade-row">
          <div class="grade-row__left">
            <span class="grade-row__desc">Merchant available</span>
          </div>
          <span class="grade-row__val">{{ formatDashboardMoneyFull(summary?.merchant_available_total ?? 0) }}</span>
        </div>
        <div class="grade-row">
          <div class="grade-row__left">
            <span class="grade-row__desc">Courier COD holding</span>
          </div>
          <span class="grade-row__val">{{ formatDashboardMoneyFull(summary?.courier_cod_holding_total ?? 0) }}</span>
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
  formatDashboardMoney,
  formatDashboardMoneyFull,
} from 'src/modules/dashboard/utils/formatDashboardMetric';
import type { WalletDashboardSummary } from '../types';

ensureDashboardChartsRegistered();

const props = defineProps<{
  modelValue: boolean;
  summary?: WalletDashboardSummary | null;
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
    (props.summary?.tenant_cash_total ?? 0) +
    (props.summary?.customer_deposits_total ?? 0) +
    (props.summary?.courier_cod_holding_total ?? 0),
);
const companyPct = computed(() =>
  dashboardSharePct(props.summary?.tenant_cash_total ?? 0, mixTotal.value),
);
const customerPct = computed(() =>
  dashboardSharePct(props.summary?.customer_deposits_total ?? 0, mixTotal.value),
);
const courierPct = computed(() =>
  dashboardSharePct(props.summary?.courier_cod_holding_total ?? 0, mixTotal.value),
);

const holderChartData = computed<ChartData<'doughnut'>>(() => ({
  labels: ['Company', 'Customer', 'Courier'],
  datasets: [
    {
      data: [
        props.summary?.tenant_cash_total ?? 0,
        props.summary?.customer_deposits_total ?? 0,
        props.summary?.courier_cod_holding_total ?? 0,
      ],
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
