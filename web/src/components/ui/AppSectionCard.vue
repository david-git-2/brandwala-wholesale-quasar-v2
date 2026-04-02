<template>
  <q-card flat bordered class="bw-section-card">
    <q-card-section v-if="title || caption || $slots.actions" class="bw-section-card__header">
      <div class="bw-section-card__copy">
        <div v-if="title" class="bw-section-card__title">{{ title }}</div>
        <div v-if="caption" class="bw-section-card__caption">{{ caption }}</div>
      </div>

      <div v-if="$slots.actions" class="bw-section-card__actions">
        <slot name="actions" />
      </div>
    </q-card-section>

    <q-separator v-if="title || caption || $slots.actions" />

    <div class="bw-section-card__body">
      <slot />
    </div>
  </q-card>
</template>

<script setup lang="ts">
defineProps<{
  title?: string
  caption?: string
}>()
</script>

<style scoped>
.bw-section-card {
  overflow: hidden;
}

.bw-section-card__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  padding: 1.1rem 1.15rem;
}

.bw-section-card__copy {
  min-width: 0;
}

.bw-section-card__title {
  font-size: 1rem;
  font-weight: 700;
  color: var(--bw-theme-ink);
}

.bw-section-card__caption {
  margin-top: 0.32rem;
  font-size: 0.88rem;
  line-height: 1.5;
  color: var(--bw-theme-muted);
}

.bw-section-card__actions {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  flex-wrap: wrap;
  justify-content: flex-end;
}

.bw-section-card__body {
  padding: 1.15rem;
}

@media (max-width: 720px) {
  .bw-section-card__header {
    flex-direction: column;
  }

  .bw-section-card__actions {
    width: 100%;
    justify-content: flex-start;
  }
}
</style>
