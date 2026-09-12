<template>
  <DashboardPulseSkeleton v-if="isLoading" />
  <q-banner v-else-if="isError" class="bw-status-banner bg-negative text-white" rounded dense>
    Could not load shop order pulse.
  </q-banner>
  <DashboardPulseCard
    v-else
    title="Shop orders"
    figure-label="Fulfillment desk"
    accent="var(--bw-success)"
    :has-chart="hasFigure"
  >
    <template #featured>
      <DashboardMetric
        :label="featuredLabel"
        :value="featuredValue"
        :unit="featuredUnit"
        :to="ordersTo"
        :tone="featuredTone"
        featured
      />
    </template>
    <DashboardMetric
      label="Needs quote"
      :value="needsQuoteLabel"
      :to="ordersTo"
      tone="warn"
    />
    <DashboardMetric
      v-if="awaitingCustomerCount > 0"
      label="Awaiting customer"
      :value="awaitingCustomerLabel"
      :to="ordersTo"
    />
    <DashboardMetric
      label="Processing"
      :value="processingLabel"
      :to="ordersTo"
      tone="warn"
    />
    <DashboardMetric
      label="Out for delivery"
      :value="shippedLabel"
      :to="ordersTo"
      tone="warn"
    />
    <DashboardMetric
      v-if="(metrics?.dropshipSubmitted ?? 0) > 0"
      label="Dropship queue"
      :value="dropshipLabel"
      :to="dropshipTo"
      tone="warn"
    />
    <DashboardMetric
      label="Fulfilled today"
      :value="invoiceCountLabel"
      unit="Invoices"
      :to="ordersTo"
    />

    <template v-if="hasFigure" #chart>
      <div class="shop-order-card__figure-stack">
        <DashboardShareBars v-if="hasPipeline" :rows="pipelineRows" />
        <DashboardLineChart
          v-if="hasHourlySales"
          :data="hourlySalesData"
        />
      </div>
    </template>

    <template v-if="courierRows.length" #visuals>
      <DashboardShareBars :rows="courierRows" />
    </template>
  </DashboardPulseCard>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { storeToRefs } from 'pinia';
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
import { useAppDashboardRoutes } from 'src/modules/dashboard/composables/useAppDashboardRoutes';
import { useShopOrderDashboardQuery } from '../composables/useShopOrderDashboardQuery';

const PIPELINE_LABELS: Record<string, string> = {
  needs_quote: 'Needs quote',
  awaiting_customer: 'Awaiting customer',
  processing: 'Processing',
  ready_for_pickup: 'Ready for pickup',
  shipped: 'Out for delivery',
};

const PIPELINE_ORDER = [
  'needs_quote',
  'awaiting_customer',
  'processing',
  'ready_for_pickup',
  'shipped',
];

const authStore = useAuthStore();
const { tenantId } = storeToRefs(authStore);
const routes = useAppDashboardRoutes();

const { data: metrics, isLoading, isError } = useShopOrderDashboardQuery(tenantId);

const ordersTo = computed(() => routes.shopOrders());
const dropshipTo = computed(() => routes.shopOrdersDropship());

const salesLabel = computed(() => formatDashboardMoney(metrics.value?.todaySalesAmount ?? 0));
const invoiceCountLabel = computed(() => formatDashboardCount(metrics.value?.todayInvoiceCount ?? 0));
const shippedLabel = computed(
  () => `${formatDashboardCount(metrics.value?.shippedCount ?? 0)} parcels`,
);
const pickupLabel = computed(
  () => `${formatDashboardCount(metrics.value?.readyForPickupCount ?? 0)} orders`,
);
const needsQuoteLabel = computed(
  () => `${formatDashboardCount(metrics.value?.needsQuoteCount ?? 0)} orders`,
);
const processingLabel = computed(
  () => `${formatDashboardCount(metrics.value?.processingCount ?? 0)} orders`,
);
const dropshipLabel = computed(
  () => `${formatDashboardCount(metrics.value?.dropshipSubmitted ?? 0)} orders`,
);

const pipeline = computed(() => metrics.value?.pipeline ?? []);
const pipelineCount = (status: string) =>
  pipeline.value.find((row) => row.status === status)?.count ?? 0;
const awaitingCustomerCount = computed(() => pipelineCount('awaiting_customer'));
const awaitingCustomerLabel = computed(
  () => `${formatDashboardCount(awaitingCustomerCount.value)} orders`,
);

const hasPickup = computed(() => (metrics.value?.readyForPickupCount ?? 0) > 0);
const featuredLabel = computed(() => (hasPickup.value ? 'Ready for pickup' : "Today's sales"));
const featuredValue = computed(() => (hasPickup.value ? pickupLabel.value : salesLabel.value));
const featuredUnit = computed(() => (hasPickup.value ? 'Pickup' : 'Storefront'));
const featuredTone = computed(() => (hasPickup.value ? 'warn' : 'ok'));
const hasPipeline = computed(() => pipeline.value.some((row) => row.count > 0));

const hourly = computed(() => metrics.value?.hourly ?? []);
const hasHourlySales = computed(() => hourly.value.some((hour) => hour.amount > 0));
const hasFigure = computed(() => hasPipeline.value || hasHourlySales.value);

const primaryRgb = readThemeRgb();

const hourlySalesData = computed<ChartData<'line'>>(() => ({
  labels: hourly.value.map((hour) => hour.label),
  datasets: [
    {
      label: 'Sales',
      data: hourly.value.map((hour) => hour.amount),
      borderColor: rgba(primaryRgb, 1),
      backgroundColor: rgba(primaryRgb, 0.16),
      borderWidth: 2,
      tension: 0.3,
      fill: true,
      pointRadius: 0,
      pointHoverRadius: 0,
    },
  ],
}));

const pipelineRows = computed<DashboardShareBarRow[]>(() => {
  const rows = PIPELINE_ORDER
    .map((status) => pipeline.value.find((row) => row.status === status))
    .filter((row): row is NonNullable<typeof row> => Boolean(row && row.count > 0));
  const max = Math.max(1, ...rows.map((row) => row.count));

  return rows.map((row, index) => ({
    label: PIPELINE_LABELS[row.status] ?? row.status,
    value: row.count,
    max,
    displayValue: `${formatDashboardCount(row.count)} orders`,
    tone:
      row.status === 'needs_quote'
        ? 'warn'
        : row.status === 'shipped'
          ? 'success'
          : index === 0
            ? 'primary'
            : 'primary',
  }));
});

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

<style scoped>
.shop-order-card__figure-stack {
  display: grid;
  gap: 0.85rem;
  min-width: 0;
  max-width: 100%;
  overflow: hidden;
}
</style>
