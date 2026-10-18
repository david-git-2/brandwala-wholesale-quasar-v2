<template>
  <q-btn-toggle
    v-model="model"
    :options="options"
    dense
    unelevated
    no-caps
    :ripple="false"
    toggle-color="primary"
    class="tf-segmented"
  />
</template>

<script setup lang="ts">
export interface TfSegmentedOption {
  label?: string;
  value: string | number;
  icon?: string;
}

defineProps<{ options: TfSegmentedOption[] }>();
const model = defineModel<string | number>({ required: true });
</script>

<style scoped>
.tf-segmented {
  border: 1px solid var(--tf-neutral-border-strong);
  border-radius: var(--tf-radius-sm);
  overflow: hidden;
}
.tf-segmented :deep(.q-btn) {
  border-radius: 0;
  padding: 2px 10px;
  font-size: 12px;
  transition: background-color var(--tf-dur-fast) var(--tf-ease);
}
</style>
