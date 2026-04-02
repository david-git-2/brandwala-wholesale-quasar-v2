<template>
  <div class="bw-empty-state">
    <div class="bw-empty-state__icon">
      <q-icon :name="icon" size="24px" />
    </div>

    <div class="bw-empty-state__title">{{ title }}</div>
    <p class="bw-empty-state__message">{{ message }}</p>

    <div v-if="$slots.actions" class="bw-empty-state__actions">
      <slot name="actions" />
    </div>
  </div>
</template>

<script setup lang="ts">
withDefaults(
  defineProps<{
    icon?: string
    title: string
    message: string
  }>(),
  {
    icon: 'inbox',
  },
)
</script>

<style scoped>
.bw-empty-state {
  display: grid;
  justify-items: start;
  gap: 0.65rem;
  min-height: 220px;
  padding: clamp(1rem, 2vw, 1.75rem);
  border: 1px dashed color-mix(in srgb, var(--bw-theme-border) 78%, transparent);
  border-radius: 18px;
  background:
    linear-gradient(180deg, rgb(var(--bw-theme-primary-rgb) / 0.05), transparent 55%),
    color-mix(in srgb, var(--bw-theme-surface) 90%, white 10%);
  align-content: center;
}

.bw-empty-state__icon {
  display: grid;
  place-items: center;
  width: 2.9rem;
  height: 2.9rem;
  border-radius: 999px;
  color: var(--bw-theme-primary);
  background: rgb(var(--bw-theme-primary-rgb) / 0.12);
}

.bw-empty-state__title {
  font-size: 1rem;
  font-weight: 700;
  color: var(--bw-theme-ink);
}

.bw-empty-state__message {
  margin: 0;
  max-width: 42ch;
  line-height: 1.6;
  color: var(--bw-theme-muted);
}

.bw-empty-state__actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
  margin-top: 0.2rem;
}
</style>
