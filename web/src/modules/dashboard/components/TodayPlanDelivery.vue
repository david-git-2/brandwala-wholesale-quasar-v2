<template>
  <TodayPlanRunway
    title="Delivery plan"
    caption="Shop orders by stage"
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