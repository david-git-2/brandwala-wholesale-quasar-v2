<template>
  <div class="ops-blank-section">
    <div class="ops-blank-section__header">
      <div class="ops-blank-section__title-row">
        <div class="ops-blank-section__icon-wrap">
          <i :class="icon" />
        </div>
        <div>
          <div class="text-subtitle1 text-weight-bold">{{ title }}</div>
          <div class="text-caption text-grey-6">{{ description }}</div>
        </div>
      </div>
      <q-chip
        dense
        size="sm"
        color="grey-3"
        text-color="grey-8"
        class="text-weight-medium"
      >
        Under Construction
      </q-chip>
    </div>

    <div class="ops-blank-section__body">
      <div class="ops-blank-section__placeholder">
        <i class="ph ph-wrench text-grey-5" />
        <span class="text-body2 text-grey-7">{{ placeholderText }}</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
withDefaults(
  defineProps<{
    title: string;
    description: string;
    icon: string;
    placeholderText?: string;
  }>(),
  {
    placeholderText: 'Operational pulse & triage dashboard widgets will be designed here.',
  },
);
</script>

<style scoped>
.ops-blank-section {
  border: 1px dashed var(--bw-theme-border, rgba(0, 0, 0, 0.12));
  border-radius: 14px;
  background: var(--bw-theme-surface, #fff);
  padding: 1.1rem 1.25rem;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.ops-blank-section__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
}

.ops-blank-section__title-row {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.ops-blank-section__icon-wrap {
  width: 36px;
  height: 36px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgb(var(--bw-theme-primary-rgb, 24 119 242) / 0.1);
  color: var(--bw-theme-primary, #1877f2);
  font-size: 1.25rem;
}

.ops-blank-section__body {
  min-height: 80px;
  border-radius: 10px;
  background: rgba(0, 0, 0, 0.02);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1rem;
}

.ops-blank-section__placeholder {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-style: italic;
}
</style>
