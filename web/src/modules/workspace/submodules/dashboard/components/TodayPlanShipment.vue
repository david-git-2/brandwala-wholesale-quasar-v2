<template>
  <TodayPlanRunway
    title="Inbound shipment plan"
    caption="Procurement batches"
    :steps="steps"
    :loading="loading"
  />
</template>

<script setup lang="ts">
import TodayPlanRunway from './TodayPlanRunway.vue';
import type { TodayPlanStep } from '../composables/useTodayPlan';

defineProps<{
  steps: TodayPlanStep[];
  loading?: boolean;
}>();
</script>