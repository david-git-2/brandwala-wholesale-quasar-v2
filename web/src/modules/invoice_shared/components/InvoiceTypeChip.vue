<template>
  <q-chip
    square
    dense
    :color="chipColor"
    :text-color="chipTextColor"
    class="text-weight-bold text-capitalize q-ma-none"
  >
    {{ label }}
  </q-chip>
</template>

<script setup lang="ts">
import { computed } from 'vue';

const props = defineProps<{ type?: string | null }>();

const label = computed(() => props.type || 'retail');

const chipColor = computed(() => {
  if (props.type === 'wholesale') return 'purple-2';
  if (props.type === 'dropship') return 'orange-2';
  return 'blue-2';
});

const chipTextColor = computed(() => {
  if (props.type === 'wholesale') return 'purple-10';
  if (props.type === 'dropship') return 'orange-10';
  return 'blue-10';
});
</script>
