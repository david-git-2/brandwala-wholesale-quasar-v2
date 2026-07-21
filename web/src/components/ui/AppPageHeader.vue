<template>
  <div class="app-page-header" :class="{ 'app-page-header--dense': dense }">
    <div class="app-page-header__copy">
      <p v-if="eyebrow" class="app-page-header__eyebrow">{{ eyebrow }}</p>
      <h1 class="app-page-header__title">{{ title }}</h1>
      <p v-if="subtitle" class="app-page-header__subtitle">{{ subtitle }}</p>
    </div>
    <div v-if="$slots.action" class="app-page-header__action">
      <slot name="action" />
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  title: string;
  subtitle?: string;
  eyebrow?: string;
  dense?: boolean;
}>();
</script>

<style scoped>
.app-page-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  flex-wrap: wrap;
}

.app-page-header__eyebrow {
  margin: 0 0 0.25rem;
  font-size: 0.75rem;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--bw-theme-muted, #736a61);
}

.app-page-header__title {
  margin: 0;
  font-size: clamp(1.25rem, 2vw, 1.6rem);
  font-weight: 700;
  color: var(--bw-theme-ink, #171412);
}

.app-page-header__subtitle {
  margin: 0.35rem 0 0;
  color: var(--bw-theme-muted, #736a61);
}

.app-page-header__action {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.app-page-header--dense {
  gap: 0.5rem;
  align-items: center;
}

.app-page-header--dense .app-page-header__eyebrow {
  margin: 0;
  font-size: 0.65rem;
  line-height: 1.2;
}

.app-page-header--dense .app-page-header__title {
  margin: 0;
  font-size: clamp(1rem, 1.4vw, 1.2rem);
  line-height: 1.25;
}

.app-page-header--dense .app-page-header__subtitle {
  margin: 0.15rem 0 0;
  font-size: 0.8rem;
}
</style>
