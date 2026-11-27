<template>
  <q-page class="column no-wrap theme-app today-plan-page">
    <TodayPlanHeader
      :loading="isRefreshing || isLoading"
      :last-refreshed-at="lastRefreshedAt"
      :status-label="statusLabel"
      @refresh="onRefresh"
    />

    <div class="col overflow-auto q-pa-sm column q-gutter-sm today-plan-scroll">
      <TodayPlanWorkQueue
        :items="workItems"
        :next-action="nextAction"
        :open-work-count="openWorkCount"
        :loading="isLoading && !hasAnyWork"
      />

      <div v-if="canShowDelivery || canShowShipment" class="column q-gutter-sm">
        <TodayPlanDelivery v-if="canShowDelivery" :steps="deliverySteps" :loading="isLoading" />
        <TodayPlanShipment v-if="canShowShipment" :steps="shipmentSteps" :loading="isLoading" />
      </div>

      <TfEmptyState
        v-if="!canShowDelivery && !canShowShipment && isClear"
        title="No plan sections for this login"
        message="Open a brand desk for delivery work, or the parent company for inbound shipments."
        icon="ph ph-compass"
      />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import TfEmptyState from 'src/components/ui/TfEmptyState.vue';
import TodayPlanHeader from '../components/TodayPlanHeader.vue';
import TodayPlanWorkQueue from '../components/TodayPlanWorkQueue.vue';
import TodayPlanDelivery from '../components/TodayPlanDelivery.vue';
import TodayPlanShipment from '../components/TodayPlanShipment.vue';
import { useTodayPlan } from '../composables/useTodayPlan';

const {
  workItems,
  deliverySteps,
  shipmentSteps,
  canShowDelivery,
  canShowShipment,
  openWorkCount,
  nextAction,
  statusLabel,
  isLoading,
  lastRefreshedAt,
  isClear,
  refetch,
} = useTodayPlan();

const hasAnyWork = computed(() => workItems.value.length > 0);

const isRefreshing = ref(false);

const onRefresh = async () => {
  isRefreshing.value = true;
  try {
    await refetch();
  } finally {
    isRefreshing.value = false;
  }
};
</script>

<style scoped>
.today-plan-page {
  height: calc(100vh - 55px);
  overflow: hidden;
  background: var(--tf-neutral-canvas);
}

.today-plan-scroll {
  max-width: 1200px;
  width: 100%;
  margin: 0 auto;
}
</style>