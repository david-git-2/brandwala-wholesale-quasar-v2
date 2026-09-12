<template>
  <DashboardPulseCard title="After sales service" stub>
    <DashboardMetric label="Open cases" value="—" />
    <DashboardMetric label="Pending approval" value="—" unit="Cases" />
    <DashboardMetric label="Awaiting receipt" value="—" />
    <DashboardMetric label="Dropship complaints" value="—" />

    <template #chart>
      <DashboardBarChart :data="sampleStatusChart" />
    </template>

    <template #visuals>
      <DashboardChartLegend :rows="sampleLegend" />
    </template>

    <template #footer>
      <q-btn
        flat
        no-caps
        color="primary"
        label="Open returns hub"
        icon-right="ph ph-arrow-up-right"
        :to="overviewTo"
      />
    </template>
  </DashboardPulseCard>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import type { ChartData } from 'chart.js';
import DashboardPulseCard from 'src/modules/dashboard/components/DashboardPulseCard.vue';
import DashboardMetric from 'src/modules/dashboard/components/DashboardMetric.vue';
import DashboardBarChart from 'src/modules/dashboard/components/DashboardBarChart.vue';
import DashboardChartLegend from 'src/modules/dashboard/components/DashboardChartLegend.vue';
import type { DashboardChartLegendRow } from 'src/modules/dashboard/components/DashboardChartLegend.vue';
import { dashboardChartColors } from 'src/modules/dashboard/utils/dashboardChartColors';

const route = useRoute();
const tenantSlug = computed(() => (route.params.tenantSlug as string) || '');

const overviewTo = computed(() => ({
  name: 'app-after-sales-overview',
  params: tenantSlug.value ? { tenantSlug: tenantSlug.value } : {},
}));

const colors = computed(() => dashboardChartColors());

const sampleStatusChart = computed<ChartData<'bar'>>(() => ({
  labels: ['Pending', 'Receipt', 'Inspecting', 'Closed'],
  datasets: [
    {
      label: 'Sample',
      data: [8, 9, 5, 14],
      backgroundColor: [
        colors.value.warning,
        colors.value.primary,
        colors.value.error,
        colors.value.success,
      ],
      borderRadius: 4,
      borderSkipped: false,
    },
  ],
}));

const sampleLegend = computed<DashboardChartLegendRow[]>(() => [
  { color: colors.value.warning, label: 'Pending approval (sample)', value: '—' },
  { color: colors.value.primary, label: 'Awaiting receipt (sample)', value: '—' },
  { color: colors.value.error, label: 'Inspecting (sample)', value: '—' },
]);
</script>
