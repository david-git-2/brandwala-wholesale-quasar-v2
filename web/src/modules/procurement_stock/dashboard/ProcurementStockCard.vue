<template>
  <DashboardPulseSkeleton v-if="isLoading" />
  <q-banner v-else-if="isError" class="bw-status-banner bg-negative text-white" rounded dense>
    Could not load stock pulse.
  </q-banner>
  <DashboardPulseCard v-else title="Stock & procurement">
    <DashboardMetric
      label="Sellable stock"
      :value="sellableLabel"
      unit="Pcs"
      :to="stockListTo"
    />
    <DashboardMetric label="Stock valuation" :value="valuationLabel" unit="Landed BDT" />
    <DashboardMetric
      label="In transit"
      :value="inTransitLabel"
      :to="shipmentListTo"
      tone="warn"
    />
    <DashboardMetric label="Under processing" :value="draftLabel" :to="shipmentListTo" />

    <template #chart>
      <div class="procurement-stock-card__chart-col">
        <DashboardDonut
          :data="availabilityChartData"
          :center-value="sellablePctLabel"
          center-caption="Sellable"
          :empty="!hasAvailabilityMix"
        />
        <DashboardChartLegend :rows="availabilityLegend" />
      </div>
    </template>

    <template #visuals>
      <DashboardBarChart
        :data="gradeChartData"
        index-axis="y"
        :empty="!(metrics?.grades?.length)"
        empty-label="No graded stock yet"
      />
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
import DashboardDonut from 'src/modules/dashboard/components/DashboardDonut.vue';
import DashboardBarChart from 'src/modules/dashboard/components/DashboardBarChart.vue';
import DashboardChartLegend from 'src/modules/dashboard/components/DashboardChartLegend.vue';
import type { DashboardChartLegendRow } from 'src/modules/dashboard/components/DashboardChartLegend.vue';
import {
  dashboardSharePct,
  formatDashboardCount,
  formatDashboardMoney,
} from 'src/modules/dashboard/utils/formatDashboardMetric';
import { dashboardChartColors, dashboardChartPalette } from 'src/modules/dashboard/utils/dashboardChartColors';
import { useProcurementDashboardQuery } from '../composables/useProcurementDashboardQuery';

const route = useRoute();
const authStore = useAuthStore();
const { tenantId } = storeToRefs(authStore);

const { data: metrics, isLoading, isError } = useProcurementDashboardQuery(tenantId);

const tenantSlug = computed(() => (route.params.tenantSlug as string) || '');

const stockListTo = computed(() => ({
  name: 'app-procurement-stock-list',
  params: tenantSlug.value ? { tenantSlug: tenantSlug.value } : {},
}));

const shipmentListTo = computed(() => ({
  name: 'app-procurement-shipment-list',
  params: tenantSlug.value ? { tenantSlug: tenantSlug.value } : {},
}));

const sellableLabel = computed(() => formatDashboardCount(metrics.value?.sellableQty ?? 0));
const valuationLabel = computed(() => formatDashboardMoney(metrics.value?.sellableValueBdt ?? 0));
const inTransitLabel = computed(
  () => `${formatDashboardCount(metrics.value?.inTransitCount ?? 0)} batches`,
);
const draftLabel = computed(
  () => `${formatDashboardCount(metrics.value?.draftCount ?? 0)} batches`,
);
const sellablePctLabel = computed(() => `${metrics.value?.sellablePct ?? 0}%`);

const totalQty = computed(() => metrics.value?.totalQty ?? 0);
const hasAvailabilityMix = computed(() => totalQty.value > 0);

const colors = computed(() => dashboardChartColors());
const palette = computed(() => dashboardChartPalette());

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

const gradeChartData = computed<ChartData<'bar'>>(() => {
  const grades = metrics.value?.grades ?? [];
  return {
    labels: grades.map((grade) => grade.name),
    datasets: [
      {
        label: 'Quantity',
        data: grades.map((grade) => grade.qty),
        backgroundColor: palette.value,
        borderRadius: 4,
        borderSkipped: false,
      },
    ],
  };
});
</script>

<style scoped>
.procurement-stock-card__chart-col {
  display: grid;
  gap: 0.75rem;
  justify-items: center;
  width: 100%;
}
</style>
