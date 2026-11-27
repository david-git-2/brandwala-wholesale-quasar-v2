<template>
  <q-btn
    v-for="item in items"
    :key="item.value"
    dense
    size="sm"
    no-caps
    class="rounded-sq-btn text-weight-medium q-px-sm"
    :unelevated="preset === item.value"
    :outline="preset !== item.value"
    :color="preset === item.value ? 'primary' : 'grey-7'"
    :label="item.label"
    @click="$emit('set', item.value)"
  />
</template>

<script setup lang="ts">
import type { DatePreset } from '../utils/datePresets';

defineProps<{ preset: DatePreset }>();
defineEmits<{ set: [DatePreset] }>();

const items: { label: string; value: DatePreset }[] = [
  { label: 'This Month', value: 'month' },
  { label: 'Last 7 Days', value: 'week' },
  { label: 'This Year', value: 'year' },
  { label: 'All Time', value: 'all' },
  { label: 'Custom', value: 'custom' },
];
</script>

<style scoped>
.rounded-sq-btn { border-radius: 8px !important; }
</style>
