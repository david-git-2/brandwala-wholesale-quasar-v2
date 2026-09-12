<template>
  <DashboardPulseSkeleton v-if="isLoading" />
  <q-banner v-else-if="isError" class="bw-status-banner bg-negative text-white" rounded dense>
    Could not load capital pulse.
  </q-banner>
  <DashboardPulseCard
    v-else
    title="Capital pool pulse"
    figure-label="Pool movement"
    accent="var(--bw-success)"
    :has-chart="hasPoolMix"
  >
    <template #featured>
      <DashboardMetric label="Active pool" :value="poolLabel" unit="Live" tone="ok" :to="ledgerTo" featured />
    </template>
    <DashboardMetric
      label="Deployed this month"
      :value="deployedMonthLabel"
      :to="ledgerTo"
    />
    <DashboardMetric
      label="Due to investors"
      :value="dueLabel"
      :to="ledgerTo"
      tone="warn"
    />
    <DashboardMetric
      label="Open containers"
      :value="containersLabel"
      :to="shipmentsTo"
    />

    <template v-if="hasPoolMix" #chart>
      <DashboardBarChart :data="poolChartData" />
    </template>

    <template v-if="containerRows.length" #visuals>
      <DashboardShareBars :rows="containerRows" />
    </template>
  </DashboardPulseCard>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { storeToRefs } from 'pinia';
import type { ChartData } from 'chart.js';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useAppDashboardRoutes } from 'src/modules/dashboard/composables/useAppDashboardRoutes';
import DashboardPulseCard from 'src/modules/dashboard/components/DashboardPulseCard.vue';
import DashboardPulseSkeleton from 'src/modules/dashboard/components/DashboardPulseSkeleton.vue';
import DashboardMetric from 'src/modules/dashboard/components/DashboardMetric.vue';
import DashboardBarChart from 'src/modules/dashboard/components/DashboardBarChart.vue';
import DashboardShareBars from 'src/modules/dashboard/components/DashboardShareBars.vue';
import type { DashboardShareBarRow } from 'src/modules/dashboard/components/DashboardShareBars.vue';
import {
  formatDashboardCount,
  formatDashboardMoney,
  formatDashboardMoneyFull,
} from 'src/modules/dashboard/utils/formatDashboardMetric';
import { dashboardChartColors } from 'src/modules/dashboard/utils/dashboardChartColors';
import { useInvestorCapitalDashboardQuery } from '../composables/useInvestorCapitalDashboardQuery';

const authStore = useAuthStore();
const { tenantId } = storeToRefs(authStore);
const routes = useAppDashboardRoutes();
const { data: metrics, isLoading, isError } = useInvestorCapitalDashboardQuery(tenantId);

const ledgerTo = computed(() => routes.capitalLedger());
const shipmentsTo = computed(() => routes.capitalShipments());

const poolLabel = computed(() => formatDashboardMoney(metrics.value?.activePoolAmount ?? 0));
const deployedMonthLabel = computed(() =>
  formatDashboardMoney(metrics.value?.deployedThisMonth ?? 0),
);
const dueLabel = computed(() => formatDashboardMoney(metrics.value?.dueToInvestors ?? 0));
const containersLabel = computed(
  () => `${formatDashboardCount(metrics.value?.openContainerCount ?? 0)} batches`,
);

const hasPoolMix = computed(
  () =>
    (metrics.value?.activePoolAmount ?? 0) +
      (metrics.value?.deployedAmount ?? 0) +
      (metrics.value?.returnedAmount ?? 0) >
    0,
);

const colors = computed(() => dashboardChartColors());

const poolChartData = computed<ChartData<'bar'>>(() => ({
  labels: ['Pool', 'Deployed', 'Returned'],
  datasets: [
    {
      label: 'Amount',
      data: [
        metrics.value?.activePoolAmount ?? 0,
        metrics.value?.deployedAmount ?? 0,
        metrics.value?.returnedAmount ?? 0,
      ],
      backgroundColor: [colors.value.primary, colors.value.warning, colors.value.success],
      borderRadius: 4,
      borderSkipped: false,
    },
  ],
}));

const containerRows = computed<DashboardShareBarRow[]>(() => {
  const containers = (metrics.value?.openContainers ?? []).slice(0, 3);
  const max = Math.max(1, ...containers.map((c) => c.allocatedCost));
  return containers.map((row, index) => ({
    label: row.name,
    value: row.allocatedCost,
    max,
    displayValue: formatDashboardMoneyFull(row.allocatedCost),
    tone: index === 0 ? 'primary' : 'warn',
  }));
});
</script>
