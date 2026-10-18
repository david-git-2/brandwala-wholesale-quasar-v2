<template>
  <div class="tf-drawer-section-tabs-header border-bottom row items-center no-wrap q-gutter-x-xs q-px-sm q-py-sm">
    <TfDrawerSectionTabs
      v-model="model"
      :tabs="tabs"
      :ariaLabel="ariaLabel"
      :count-visibility="countVisibility"
      class="col min-width-0"
    />
    <slot name="trailing" />
  </div>
</template>

<script setup lang="ts">
import TfDrawerSectionTabs, { type TfDrawerSectionTab } from './TfDrawerSectionTabs.vue';

defineProps<{
  tabs: readonly TfDrawerSectionTab[];
  ariaLabel: string;
  countVisibility?: 'always' | 'positive';
}>();

const model = defineModel<string | number>({ required: true });
</script>

<style scoped>
.tf-drawer-section-tabs-header {
  background: var(--tf-neutral-surface);
}

.border-bottom {
  border-bottom: 1px solid var(--tf-neutral-border);
}
</style>
