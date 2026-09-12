<template>
  <DashboardPulseSkeleton v-if="isDashboardLoading" />
  <q-banner v-else-if="dashboardError" class="bw-status-banner bg-negative text-white" rounded dense>
    Could not load treasury pulse.
  </q-banner>
  <DashboardPulseCard
    v-else
    title="Treasury & liquidity"
    figure-label="Cash holders"
    accent="var(--bw-theme-primary)"
    :has-chart="hasMix"
  >
    <template #featured>
      <DashboardMetric
        :label="featuredLabel"
        :value="featuredValue"
        :unit="featuredUnit"
        :to="walletTo"
        :tone="featuredTone"
        featured
      />
    </template>
    <DashboardMetric
      label="Customer prepayments"
      :value="depositsLabel"
      :to="walletTo"
    />
    <DashboardMetric
      v-if="!hasCodFeatured"
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
    <DashboardMetric
      label="Vendor payables"
      :value="payablesLabel"
      :to="walletTo"
      tone="warn"
    />

    <template v-if="hasMix" #chart>
      <div class="wallet-pulse__chart-col">
        <DashboardDonut
          :data="holderChartData"
          :center-value="`${companyPct}%`"
        />
        <DashboardChartLegend :rows="holderLegend" />
      </div>
    </template>
  </DashboardPulseCard>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { ChartData } from 'chart.js';
import { useAppDashboardRoutes } from 'src/modules/dashboard/composables/useAppDashboardRoutes';
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

const routes = useAppDashboardRoutes();
const { dashboardSummary, isDashboardLoading, dashboardError } = useWalletAccounts();

const walletTo = computed(() => routes.walletHome());

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
const payablesLabel = computed(() =>
  formatDashboardMoney(dashboardSummary.value?.vendor_payables_total ?? 0),
);

const codTotal = computed(() => dashboardSummary.value?.courier_cod_holding_total ?? 0);
const hasCodFeatured = computed(() => codTotal.value > 0);
const featuredLabel = computed(() => (hasCodFeatured.value ? 'COD to collect' : 'Company cash'));
const featuredValue = computed(() => (hasCodFeatured.value ? codLabel.value : cashLabel.value));
const featuredUnit = computed(() => (hasCodFeatured.value ? 'Courier' : 'Live'));
const featuredTone = computed(() => (hasCodFeatured.value ? 'warn' : 'ok'));

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
