<template>
  <DashboardPulseSkeleton v-if="isLoading" />
  <q-banner v-else-if="isError" class="bw-status-banner bg-negative text-white" rounded dense>
    Could not load thrift snapshot.
  </q-banner>
  <DashboardPulseCard
    v-else
    title="Shop glance"
    figure-label="Stock mix"
    accent="var(--bw-success)"
    :has-chart="hasStockMix"
  >
    <template #featured>
      <DashboardMetric label="Available" :value="availableLabel" tone="ok" featured />
    </template>
    <DashboardMetric label="Sold" :value="soldLabel" />
    <DashboardMetric
      label="COD waiting"
      :value="codPendingLabel"
      :unit="codExpectedLabel"
      :to="codTo"
      tone="warn"
    />
    <DashboardMetric
      label="Sales today"
      :value="salesTodayLabel"
      :to="salesTo"
    />

    <template v-if="hasStockMix" #chart>
      <DashboardDonut
        :data="donutData"
        :center-value="`${availablePct}%`"
      />
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
import DashboardDonut from 'src/modules/dashboard/components/DashboardDonut.vue';
import { formatDashboardCount } from 'src/modules/dashboard/utils/formatDashboardMetric';
import { readThemeRgb, rgba } from 'src/modules/dashboard/utils/dashboardChartSetup';
import { dashboardChartColors } from 'src/modules/dashboard/utils/dashboardChartColors';
import { useThriftDashboardMetricsQuery } from 'src/modules/thrift/reports/composables/useThriftReportsQuery';

const props = defineProps<{
  tenantSlug?: string;
}>();

const authStore = useAuthStore();
const { tenantId } = storeToRefs(authStore);

const { data: metrics, isLoading, isError } = useThriftDashboardMetricsQuery(tenantId);

const availableItems = computed(() => metrics.value?.availableItems ?? 0);
const soldItems = computed(() => metrics.value?.soldItems ?? 0);

const availableLabel = computed(() => formatDashboardCount(availableItems.value));
const soldLabel = computed(() => formatDashboardCount(soldItems.value));
const codPendingLabel = computed(() => formatDashboardCount(metrics.value?.codPendingCount ?? 0));
const salesTodayLabel = computed(() => formatDashboardCount(metrics.value?.activeInvoicesToday ?? 0));
const codExpectedLabel = computed(() => {
  const amount = metrics.value?.codExpectedTotal ?? 0;
  return `৳${Number(amount).toFixed(0)} expected`;
});

const tracked = computed(() => availableItems.value + soldItems.value);
const hasStockMix = computed(() => tracked.value > 0);
const availablePct = computed(() =>
  tracked.value > 0 ? Math.round((availableItems.value / tracked.value) * 100) : 0,
);

const primaryRgb = readThemeRgb();
const colors = computed(() => dashboardChartColors());

const donutData = computed<ChartData<'doughnut'>>(() => ({
  labels: ['Available', 'Sold'],
  datasets: [
    {
      data: [availableItems.value, soldItems.value],
      backgroundColor: [rgba(primaryRgb, 0.9), colors.value.surface],
      borderWidth: 0,
      hoverOffset: 2,
    },
  ],
}));

const routes = useAppDashboardRoutes(props.tenantSlug);

const codTo = computed(() => routes.thriftCodReport());
const salesTo = computed(() => routes.thriftSales());
</script>
