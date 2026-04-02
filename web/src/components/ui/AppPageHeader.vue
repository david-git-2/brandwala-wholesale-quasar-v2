<template>
  <div class="bw-page-header">
    <div class="bw-page-header__copy">
      <div v-if="eyebrow" class="bw-page-header__eyebrow">{{ eyebrow }}</div>
      <div class="bw-page-header__title-row">
        <slot name="leading" />
        <div>
          <h1 class="bw-page-header__title">{{ title }}</h1>
          <p v-if="subtitle" class="bw-page-header__subtitle">{{ subtitle }}</p>
        </div>
      </div>
    </div>

    <div v-if="$slots.actions" class="bw-page-header__actions">
      <slot name="actions" />
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  title: string
  subtitle?: string
  eyebrow?: string
}>()
</script>

<style scoped>
.bw-page-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: clamp(1rem, 2vw, 1.5rem);
  margin-bottom: 1.5rem;
}

.bw-page-header__copy {
  min-width: 0;
}

.bw-page-header__eyebrow {
  margin-bottom: 0.45rem;
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--bw-theme-primary);
}

.bw-page-header__title-row {
  display: flex;
  align-items: flex-start;
  gap: 0.75rem;
}

.bw-page-header__title {
  margin: 0;
  font-size: clamp(1.65rem, 2vw, 2.1rem);
  line-height: 1.05;
  font-weight: 700;
  color: var(--bw-theme-ink);
}

.bw-page-header__subtitle {
  margin: 0.4rem 0 0;
  max-width: 58ch;
  font-size: 0.95rem;
  line-height: 1.6;
  color: var(--bw-theme-muted);
}

.bw-page-header__actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  flex-wrap: wrap;
  gap: 0.75rem;
}

@media (max-width: 720px) {
  .bw-page-header {
    flex-direction: column;
  }

  .bw-page-header__actions {
    width: 100%;
    justify-content: flex-start;
  }
}
</style>
