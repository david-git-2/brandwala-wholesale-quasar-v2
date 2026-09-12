<template>
  <DashboardPulseSkeleton v-if="isLoading" />
  <q-banner v-else-if="isError" class="bw-status-banner bg-negative text-white" rounded dense>
    Could not load tasks pulse.
  </q-banner>
  <DashboardPulseCard
    v-else
    title="Operational taskboard"
    figure-label="My board"
    accent="var(--bw-theme-primary)"
    :has-chart="hasBoardMix"
  >
    <template #featured>
      <DashboardMetric
        label="Assigned to me"
        :value="assignedLabel"
        unit="Mine"
        :to="tasksTo"
        featured
      />
    </template>
    <DashboardMetric
      label="Overdue"
      :value="overdueLabel"
      unit="Tasks"
      :to="tasksTo"
      tone="warn"
    />
    <DashboardMetric
      label="Due today"
      :value="dueTodayLabel"
      :to="tasksTo"
      tone="warn"
    />
    <DashboardMetric
      label="Unassigned"
      :value="unassignedLabel"
      :to="tasksTo"
    />

    <template v-if="hasBoardMix" #chart>
      <div class="tasks-pulse__chart-col">
        <DashboardDonut
          :data="statusChartData"
          :center-value="`${donePct}%`"
        />
        <DashboardChartLegend :rows="boardLegend" />
      </div>
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
import DashboardChartLegend from 'src/modules/dashboard/components/DashboardChartLegend.vue';
import type { DashboardChartLegendRow } from 'src/modules/dashboard/components/DashboardChartLegend.vue';
import {
  dashboardSharePct,
  formatDashboardCount,
} from 'src/modules/dashboard/utils/formatDashboardMetric';
import { dashboardChartColors } from 'src/modules/dashboard/utils/dashboardChartColors';
import { useTasksDashboardQuery } from '../composables/useTasksDashboardQuery';

const authStore = useAuthStore();
const { tenantId } = storeToRefs(authStore);
const routes = useAppDashboardRoutes();
const { data: metrics, isLoading, isError } = useTasksDashboardQuery(tenantId);

const tasksTo = computed(() => routes.tasks());

const assignedLabel = computed(() => formatDashboardCount(metrics.value?.assignedToMe ?? 0));
const overdueLabel = computed(() => formatDashboardCount(metrics.value?.overdueCount ?? 0));
const dueTodayLabel = computed(
  () => `${formatDashboardCount(metrics.value?.dueTodayCount ?? 0)} tasks`,
);
const unassignedLabel = computed(
  () => `${formatDashboardCount(metrics.value?.unassignedCount ?? 0)} tasks`,
);

const boardTotal = computed(
  () =>
    (metrics.value?.myTodo ?? 0) +
    (metrics.value?.myDoing ?? 0) +
    (metrics.value?.myStuck ?? 0) +
    (metrics.value?.myDone ?? 0),
);
const hasBoardMix = computed(() => boardTotal.value > 0);
const donePct = computed(() => dashboardSharePct(metrics.value?.myDone ?? 0, boardTotal.value));

const colors = computed(() => dashboardChartColors());

const statusChartData = computed<ChartData<'doughnut'>>(() => ({
  labels: ['Open', 'Doing', 'Stuck', 'Done'],
  datasets: [
    {
      data: [
        metrics.value?.myTodo ?? 0,
        metrics.value?.myDoing ?? 0,
        metrics.value?.myStuck ?? 0,
        metrics.value?.myDone ?? 0,
      ],
      backgroundColor: [
        colors.value.primary,
        colors.value.warning,
        colors.value.error,
        colors.value.success,
      ],
      borderWidth: 0,
      hoverOffset: 2,
    },
  ],
}));

const boardLegend = computed<DashboardChartLegendRow[]>(() => [
  {
    color: colors.value.primary,
    label: 'Open',
    value: formatDashboardCount(metrics.value?.myTodo ?? 0),
    pct: dashboardSharePct(metrics.value?.myTodo ?? 0, boardTotal.value),
  },
  {
    color: colors.value.warning,
    label: 'Doing',
    value: formatDashboardCount(metrics.value?.myDoing ?? 0),
    pct: dashboardSharePct(metrics.value?.myDoing ?? 0, boardTotal.value),
  },
  {
    color: colors.value.error,
    label: 'Stuck',
    value: formatDashboardCount(metrics.value?.myStuck ?? 0),
    pct: dashboardSharePct(metrics.value?.myStuck ?? 0, boardTotal.value),
  },
  {
    color: colors.value.success,
    label: 'Done',
    value: formatDashboardCount(metrics.value?.myDone ?? 0),
    pct: dashboardSharePct(metrics.value?.myDone ?? 0, boardTotal.value),
  },
]);
</script>

<style scoped>
.tasks-pulse__chart-col {
  display: grid;
  gap: 0.75rem;
  justify-items: center;
  width: 100%;
}
</style>
