<template>
  <DashboardPulseCard title="After sales service" stub :has-chart="false">
    <template #featured>
      <DashboardMetric label="Open cases" value="—" featured />
    </template>
    <DashboardMetric label="Pending approval" value="—" unit="Cases" />
    <DashboardMetric label="Awaiting receipt" value="—" />
    <DashboardMetric label="Dropship complaints" value="—" />

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
import DashboardPulseCard from 'src/modules/dashboard/components/DashboardPulseCard.vue';
import DashboardMetric from 'src/modules/dashboard/components/DashboardMetric.vue';
import { useAppDashboardRoutes } from 'src/modules/dashboard/composables/useAppDashboardRoutes';

const routes = useAppDashboardRoutes();

const overviewTo = computed(() => routes.afterSalesOverview());
</script>
