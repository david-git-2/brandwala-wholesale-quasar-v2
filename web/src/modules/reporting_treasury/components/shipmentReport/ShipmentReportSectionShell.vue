<template>
  <q-card flat bordered class="q-pa-md report-section">
    <div v-if="title" class="text-subtitle2 text-weight-bold q-mb-sm">{{ title }}</div>
    <slot />
  </q-card>
</template>

<script setup lang="ts">
defineProps<{
  title?: string;
}>();
</script>

<style scoped>
.report-section {
  background: var(--tf-neutral-surface);
  border-radius: var(--tf-radius-md, 12px);
}
</style>