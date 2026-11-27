<template>
  <component :is="bare ? 'div' : 'q-card'" v-bind="shellAttrs">
    <div v-if="title" class="text-subtitle2 text-weight-bold q-mb-sm">{{ title }}</div>
    <slot />
  </component>
</template>

<script setup lang="ts">
import { computed } from 'vue';

const props = withDefaults(
  defineProps<{
    title?: string;
    bare?: boolean;
  }>(),
  { bare: false },
);

const shellAttrs = computed(() =>
  props.bare ? { class: 'report-section-bare' } : { flat: true, bordered: true, class: 'q-pa-md report-section' },
);
</script>

<style scoped>
.report-section {
  background: var(--tf-neutral-surface);
  border-radius: var(--tf-radius-md, 12px);
}
</style>