<template>
  <DashboardPulseSkeleton v-if="isLoading" />
  <q-banner v-else-if="isError" class="bw-status-banner bg-negative text-white" rounded dense>
    Could not load shop order pulse.
  </q-banner>
  <DashboardPulseCard v-else title="Shop orders">
    <DashboardMetric label="Today's sales" :value="salesLabel" unit="Storefront" tone="ok" />
    <DashboardMetric
      label="Fulfilled orders"
      :value="invoiceCountLabel"
      unit="Invoices"
      :to="ordersTo"
    />
    <DashboardMetric
      label="Out for delivery"
      :value="shippedLabel"
      :to="ordersTo"
      tone="warn"
    />
    <DashboardMetric
      label="Ready for pickup"
      :value="pickupLabel"
      :to="ordersTo"
      tone="warn"
    />

    <template #chart>
      <DashboardLineChart :data="hourlySalesData" :empty="!hasHourlySales" />
    </template>

    <template #visuals>
      <DashboardShareBars :rows="courierRows" empty-label="No parcels in queue" />
    </template>
  </DashboardPulseCard>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { storeToRefs } from 'pinia';
import { useRoute } from 'vue-router';
import type { ChartData } from 'chart.js';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import DashboardPulseCard from 'src/modules/dashboard/components/DashboardPulseCard.vue';
import DashboardPulseSkeleton from 'src/modules/dashboard/components/DashboardPulseSkeleton.vue';
import DashboardMetric from 'src/modules/dashboard/components/DashboardMetric.vue';
import DashboardLineChart from 'src/modules/dashboard/components/DashboardLineChart.vue';
import DashboardShareBars from 'src/modules/dashboard/components/DashboardShareBars.vue';
import type { DashboardShareBarRow } from 'src/modules/dashboard/components/DashboardShareBars.vue';
import {
  formatDashboardCount,
  formatDashboardMoney,
} from 'src/modules/dashboard/utils/formatDashboardMetric';
import { readThemeRgb, rgba } from 'src/modules/dashboard/utils/dashboardChartSetup';
import { useShopOrderDashboardQuery } from '../composables/useShopOrderDashboardQuery';

const route = useRoute();
const authStore = useAuthStore();
const { tenantId } = storeToRefs(authStore);

const { data: metrics, isLoading, isError } = useShopOrderDashboardQuery(tenantId);

const tenantSlug = computed(() => (route.params.tenantSlug as string) || '');

const ordersTo = computed(() => ({
  name: 'shop-orders-page',
  params: tenantSlug.value ? { tenantSlug: tenantSlug.value } : {},
}));

const salesLabel = computed(() => formatDashboardMoney(metrics.value?.todaySalesAmount ?? 0));
const invoiceCountLabel = computed(() => formatDashboardCount(metrics.value?.todayInvoiceCount ?? 0));
const shippedLabel = computed(
  () => `${formatDashboardCount(metrics.value?.shippedCount ?? 0)} parcels`,
);
const pickupLabel = computed(
  () => `${formatDashboardCount(metrics.value?.readyForPickupCount ?? 0)} orders`,
);

const hourly = computed(() => metrics.value?.hourly ?? []);
const hasHourlySales = computed(() => hourly.value.some((hour) => hour.amount > 0));

const primaryRgb = readThemeRgb();

const hourlySalesData = computed<ChartData<'line'>>(() => ({
  labels: hourly.value.map((hour) => hour.label),
  datasets: [
    {
      label: 'Sales',
      data: hourly.value.map((hour) => hour.amount),
      borderColor: rgba(primaryRgb, 1),
      backgroundColor: rgba(primaryRgb, 0.12),
      borderWidth: 2,
      tension: 0.3,
      fill: true,
      pointBackgroundColor: rgba(primaryRgb, 1),
      pointBorderColor: 'var(--bw-theme-surface)',
      pointBorderWidth: 2,
      pointRadius: 3,
      pointHoverRadius: 5,
    },
  ],
}));

const courierRows = computed<DashboardShareBarRow[]>(() => {
  const couriers = (metrics.value?.couriers ?? []).slice(0, 3);
  const max = Math.max(1, ...couriers.map((c) => c.count));
  return couriers.map((courier, index) => ({
    label: courier.name,
    value: courier.count,
    max,
    displayValue: `${formatDashboardCount(courier.count)} parcels`,
    tone: index === 0 ? 'primary' : index === 1 ? 'warn' : 'success',
  }));
});
</script>
