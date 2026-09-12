<template>
  <DashboardPulseSkeleton v-if="isDashboardLoading" />
  <q-banner v-else-if="dashboardError" class="bw-status-banner bg-negative text-white" rounded dense>
    Could not load treasury pulse.
  </q-banner>
  <DashboardPulseCard v-else title="Treasury & liquidity">
    <DashboardMetric label="Company cash" :value="cashLabel" unit="Live" tone="ok" :to="walletTo" />
    <DashboardMetric
      label="Customer prepayments"
      :value="depositsLabel"
      :to="walletTo"
    />
    <DashboardMetric
      label="COD to collect"
      :value="codLabel"
      :to="walletTo"
      tone="warn"
    />
    <DashboardMetric
      label="Pending payouts"
      :value="payoutLabel"
      :to="walletTo"
      tone="warn"
    />

    <template #chart>
      <div class="wallet-pulse__chart-col">
        <DashboardDonut
          :data="holderChartData"
          :center-value="`${companyPct}%`"
          center-caption="Company"
          :empty="!hasMix"
        />
        <DashboardChartLegend :rows="holderLegend" />
      </div>
    </template>
  </DashboardPulseCard>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import type { ChartData } from 'chart.js';
import DashboardPulseCard from 'src/modules/dashboard/components/DashboardPulseCard.vue';
import DashboardPulseSkeleton from 'src/modules/dashboard/components/DashboardPulseSkeleton.vue';
import DashboardMetric from 'src/modules/dashboard/components/DashboardMetric.vue';
import DashboardDonut from 'src/modules/dashboard/components/DashboardDonut.vue';
import DashboardChartLegend from 'src/modules/dashboard/components/DashboardChartLegend.vue';
import type { DashboardChartLegendRow } from 'src/modules/dashboard/components/DashboardChartLegend.vue';
import {
  dashboardSharePct,
  formatDashboardMoney,
} from 'src/modules/dashboard/utils/formatDashboardMetric';
import { dashboardChartColors } from 'src/modules/dashboard/utils/dashboardChartColors';
import { useWalletAccounts } from '../composables/useWalletAccounts';

const route = useRoute();
const { dashboardSummary, isDashboardLoading, dashboardError } = useWalletAccounts();

const tenantSlug = computed(() => (route.params.tenantSlug as string) || '');
const walletTo = computed(() => ({
  name: 'app-wallet-home-page',
  params: tenantSlug.value ? { tenantSlug: tenantSlug.value } : {},
}));

const cashLabel = computed(() => formatDashboardMoney(dashboardSummary.value?.tenant_cash_total ?? 0));
const depositsLabel = computed(() =>
  formatDashboardMoney(dashboardSummary.value?.customer_deposits_total ?? 0),
);
const codLabel = computed(() =>
  formatDashboardMoney(dashboardSummary.value?.courier_cod_holding_total ?? 0),
);
const payoutLabel = computed(() =>
  formatDashboardMoney(dashboardSummary.value?.merchant_pending_total ?? 0),
);

const mixTotal = computed(
  () =>
    (dashboardSummary.value?.tenant_cash_total ?? 0) +
    (dashboardSummary.value?.customer_deposits_total ?? 0) +
    (dashboardSummary.value?.courier_cod_holding_total ?? 0) +
    (dashboardSummary.value?.merchant_pending_total ?? 0),
);
const hasMix = computed(() => mixTotal.value > 0);
const companyPct = computed(() =>
  dashboardSharePct(dashboardSummary.value?.tenant_cash_total ?? 0, mixTotal.value),
);

const colors = computed(() => dashboardChartColors());

const holderChartData = computed<ChartData<'doughnut'>>(() => ({
  labels: ['Company', 'Customer', 'Courier', 'Payouts'],
  datasets: [
    {
      data: [
        dashboardSummary.value?.tenant_cash_total ?? 0,
        dashboardSummary.value?.customer_deposits_total ?? 0,
        dashboardSummary.value?.courier_cod_holding_total ?? 0,
        dashboardSummary.value?.merchant_pending_total ?? 0,
      ],
      backgroundColor: [
        colors.value.success,
        colors.value.primary,
        colors.value.warning,
        colors.value.error,
      ],
      borderWidth: 0,
      hoverOffset: 2,
    },
  ],
}));

const holderLegend = computed<DashboardChartLegendRow[]>(() => [
  {
    color: colors.value.success,
    label: 'Company',
    value: formatDashboardMoney(dashboardSummary.value?.tenant_cash_total ?? 0),
    pct: dashboardSharePct(dashboardSummary.value?.tenant_cash_total ?? 0, mixTotal.value),
  },
  {
    color: colors.value.primary,
    label: 'Customer',
    value: formatDashboardMoney(dashboardSummary.value?.customer_deposits_total ?? 0),
    pct: dashboardSharePct(dashboardSummary.value?.customer_deposits_total ?? 0, mixTotal.value),
  },
  {
    color: colors.value.warning,
    label: 'Courier',
    value: formatDashboardMoney(dashboardSummary.value?.courier_cod_holding_total ?? 0),
    pct: dashboardSharePct(dashboardSummary.value?.courier_cod_holding_total ?? 0, mixTotal.value),
  },
  {
    color: colors.value.error,
    label: 'Payouts',
    value: formatDashboardMoney(dashboardSummary.value?.merchant_pending_total ?? 0),
    pct: dashboardSharePct(dashboardSummary.value?.merchant_pending_total ?? 0, mixTotal.value),
  },
]);
</script>

<style scoped>
.wallet-pulse__chart-col {
  display: grid;
  gap: 0.75rem;
  justify-items: center;
  width: 100%;
}
</style>
