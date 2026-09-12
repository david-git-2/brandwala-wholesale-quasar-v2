<template>
  <DashboardPulseSkeleton v-if="isLoading" />
  <q-banner v-else-if="isError" class="bw-status-banner bg-negative text-white" rounded dense>
    Could not load stock pulse.
  </q-banner>
  <DashboardPulseCard
    v-else
    title="Stock & procurement"
    figure-label="Stock & inbound"
    accent="var(--bw-success)"
    :has-chart="hasFigure"
  >
    <template #featured>
      <DashboardMetric
        label="Sellable stock"
        :value="sellableLabel"
        unit="Pcs"
        :to="stockListTo"
        featured
      />
    </template>
    <DashboardMetric label="Stock valuation" :value="valuationLabel" unit="Landed BDT" />
    <DashboardMetric
      label="In transit"
      :value="inTransitLabel"
      :to="shipmentListTo"
      tone="warn"
    />
    <DashboardMetric
      label="Under processing"
      :value="draftLabel"
      :to="shipmentListTo"
      tone="warn"
    />
    <DashboardMetric
      label="Received"
      :value="receivedLabel"
      :to="shipmentListTo"
    />

    <template v-if="hasFigure" #chart>
      <div class="procurement-stock-card__chart-col">
        <DashboardDonut
          v-if="hasAvailabilityMix"
          :data="availabilityChartData"
          :center-value="sellablePctLabel"
        />
        <DashboardChartLegend v-if="hasAvailabilityMix" :rows="availabilityLegend" />
        <DashboardShareBars v-if="pipelineRows.length" :rows="pipelineRows" />
      </div>
    </template>

    <template v-if="showLocationBars" #visuals>
      <DashboardShareBars :rows="locationRows" />
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
import DashboardShareBars from 'src/modules/dashboard/components/DashboardShareBars.vue';
import type { DashboardShareBarRow } from 'src/modules/dashboard/components/DashboardShareBars.vue';
import DashboardChartLegend from 'src/modules/dashboard/components/DashboardChartLegend.vue';
import type { DashboardChartLegendRow } from 'src/modules/dashboard/components/DashboardChartLegend.vue';
import {
  dashboardSharePct,
  formatDashboardCount,
  formatDashboardMoney,
} from 'src/modules/dashboard/utils/formatDashboardMetric';
import { dashboardChartColors } from 'src/modules/dashboard/utils/dashboardChartColors';
import { useProcurementDashboardQuery } from '../composables/useProcurementDashboardQuery';

const PIPELINE_LABELS: Record<string, string> = {
  draft: 'Under processing',
  in_transit: 'In transit',
  received: 'Received',
};

const authStore = useAuthStore();
const { tenantId } = storeToRefs(authStore);
const routes = useAppDashboardRoutes();

const { data: metrics, isLoading, isError } = useProcurementDashboardQuery(tenantId);

const stockListTo = computed(() => routes.procurementStockList());
const shipmentListTo = computed(() => routes.procurementShipmentList());

const sellableLabel = computed(() => formatDashboardCount(metrics.value?.sellableQty ?? 0));
const valuationLabel = computed(() => formatDashboardMoney(metrics.value?.sellableValueBdt ?? 0));
const inTransitLabel = computed(
  () => `${formatDashboardCount(metrics.value?.inTransitCount ?? 0)} batches`,
);
const draftLabel = computed(
  () => `${formatDashboardCount(metrics.value?.draftCount ?? 0)} batches`,
);
const receivedLabel = computed(
  () => `${formatDashboardCount(metrics.value?.receivedCount ?? 0)} batches`,
);
const sellablePctLabel = computed(() => `${metrics.value?.sellablePct ?? 0}%`);

const totalQty = computed(() => metrics.value?.totalQty ?? 0);
const hasAvailabilityMix = computed(() => totalQty.value > 0);

const colors = computed(() => dashboardChartColors());

const availabilityChartData = computed<ChartData<'doughnut'>>(() => ({
  labels: ['Sellable', 'Held / Reserved', 'Damaged'],
  datasets: [
    {
      data: [
        metrics.value?.sellableQty ?? 0,
        metrics.value?.heldQty ?? 0,
        metrics.value?.unsellableQty ?? 0,
      ],
      backgroundColor: [colors.value.success, colors.value.warning, colors.value.error],
      borderWidth: 0,
      hoverOffset: 2,
    },
  ],
}));

const availabilityLegend = computed<DashboardChartLegendRow[]>(() => [
  {
    color: colors.value.success,
    label: 'Sellable',
    value: formatDashboardCount(metrics.value?.sellableQty ?? 0),
    pct: dashboardSharePct(metrics.value?.sellableQty ?? 0, totalQty.value),
  },
  {
    color: colors.value.warning,
    label: 'Held',
    value: formatDashboardCount(metrics.value?.heldQty ?? 0),
    pct: dashboardSharePct(metrics.value?.heldQty ?? 0, totalQty.value),
  },
  {
    color: colors.value.error,
    label: 'Damaged',
    value: formatDashboardCount(metrics.value?.unsellableQty ?? 0),
    pct: dashboardSharePct(metrics.value?.unsellableQty ?? 0, totalQty.value),
  },
]);

const pipelineRows = computed<DashboardShareBarRow[]>(() => {
  const rows = (metrics.value?.pipeline ?? []).filter((row) => row.count > 0);
  const max = Math.max(1, ...rows.map((r) => r.count));
  return rows.map((row, index) => ({
    label: PIPELINE_LABELS[row.status] ?? row.status,
    value: row.count,
    max,
    displayValue: `${formatDashboardCount(row.count)} batches`,
    tone: index === 0 ? 'primary' : row.status === 'in_transit' ? 'warn' : 'success',
  }));
});

const hasFigure = computed(() => hasAvailabilityMix.value || pipelineRows.value.length > 0);

const locationRows = computed<DashboardShareBarRow[]>(() => {
  const locations = metrics.value?.locations ?? [];
  const max = Math.max(1, ...locations.map((l) => l.qty));
  return locations.map((row, index) => ({
    label: row.name,
    value: row.qty,
    max,
    displayValue: `${formatDashboardCount(row.qty)} pcs`,
    tone: index === 0 ? 'primary' : 'success',
  }));
});

const showLocationBars = computed(() => (metrics.value?.locations?.length ?? 0) >= 2);
</script>

<style scoped>
.procurement-stock-card__chart-col {
  display: grid;
  gap: 0.75rem;
  justify-items: center;
  width: 100%;
}
</style>
