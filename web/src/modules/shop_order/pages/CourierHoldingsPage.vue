<template>
  <q-page class="q-pa-md">
    <div class="max-width-container q-gutter-y-md">
      <!-- Standard Page Header -->
      <div class="row items-center justify-between">
        <div>
          <div class="text-overline text-primary text-weight-bold">DROPSHIP FINANCIAL ESCROW</div>
          <h1 class="text-h5 text-weight-bold q-my-none">Courier Holdings & Remittance Hub</h1>
        </div>
        <div>
          <q-btn
            outline
            color="primary"
            icon="refresh"
            label="Refresh Holdings"
            no-caps
            style="border-radius: 8px"
            :loading="isFetching"
            @click="() => refetch()"
          />
        </div>
      </div>

      <!-- Skeleton Loader during initial fetch -->
      <CourierHoldingsSkeleton v-if="isLoading" />

      <!-- Loaded Content Grid -->
      <template v-else>
        <!-- KPI Summary Cards -->
        <CourierHoldingKpiCards :totals="totals" />

        <!-- Unremitted Breakdown Table -->
        <CourierHoldingTable :summary-list="summaryList" />
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { useCourierHoldingsQuery } from '../composables/useCourierHoldingsQuery';
import CourierHoldingKpiCards from '../components/CourierHoldingKpiCards.vue';
import CourierHoldingTable from '../components/CourierHoldingTable.vue';
import CourierHoldingsSkeleton from '../components/CourierHoldingsSkeleton.vue';

const { summaryList, totals, isLoading, isFetching, refetch } = useCourierHoldingsQuery();
</script>

<style scoped>
.max-width-container {
  max-width: 1200px;
  margin: 0 auto;
}
</style>
