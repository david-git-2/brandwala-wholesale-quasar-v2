<template>
  <q-tabs
    v-model="model"
    dense
    no-caps
    inline-label
    align="left"
    :breakpoint="0"
    active-color="primary"
    indicator-color="primary"
    class="tf-tabs"
  >
    <q-tab
      v-for="t in tabs"
      :key="t.name"
      :name="t.name"
      :label="t.label"
      :icon="t.icon"
      :ripple="false"
      class="tf-tabs__tab"
    />
  </q-tabs>
</template>

<script setup lang="ts">
export interface TfTabItem {
  name: string;
  label: string;
  icon?: string;
}

defineProps<{ tabs: TfTabItem[] }>();
const model = defineModel<string>({ required: true });
</script>

<style scoped>
.tf-tabs {
  border-bottom: 1px solid var(--tf-neutral-border);
  color: var(--tf-neutral-muted);
}
.tf-tabs__tab {
  min-height: 32px;
  padding: 0 12px;
  font-size: 13px;
  font-weight: 500;
}
</style>
