<template>
  <section class="dashboard-story">
    <header class="dashboard-story__kicker">
      <span v-if="accent" class="dashboard-story__accent" :style="{ background: accent }" />
      <span class="dashboard-story__title">{{ title }}</span>
      <DashboardStubBadge v-if="stub" />
      <slot name="stub" />
    </header>

    <div
      class="dashboard-story__body"
      :class="{ 'dashboard-story__body--no-chart': !hasChart }"
    >
      <div class="dashboard-story__copy">
        <div v-if="$slots.featured" class="dashboard-story__featured">
          <slot name="featured" />
        </div>
        <div v-if="$slots.default" class="dashboard-story__figures">
          <slot />
        </div>
        <div v-if="$slots.visuals" class="dashboard-story__caption">
          <slot name="visuals" />
        </div>
      </div>
      <div v-if="hasChart" class="dashboard-story__figure">
        <div class="dashboard-story__figure-well">
          <p v-if="figureLabel" class="dashboard-story__figure-label">{{ figureLabel }}</p>
          <slot name="chart" />
        </div>
      </div>
    </div>

    <footer v-if="$slots.footer" class="dashboard-story__footer">
      <slot name="footer" />
    </footer>
  </section>
</template>

<script setup lang="ts">
import DashboardStubBadge from './DashboardStubBadge.vue';

withDefaults(
  defineProps<{
    title: string;
    stub?: boolean;
    hasChart?: boolean;
    figureLabel?: string;
    accent?: string;
  }>(),
  {
    hasChart: true,
    accent: 'var(--bw-theme-primary)',
  },
);
</script>

<style scoped>
.dashboard-story {
  min-width: 0;
  padding: 0;
}

.dashboard-story__kicker {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
  margin-bottom: 0.85rem;
}

.dashboard-story__accent {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  flex-shrink: 0;
}

.dashboard-story__title {
  font-size: 12px;
  font-weight: 500;
  color: var(--bw-theme-muted);
}

.dashboard-story__body {
  display: grid;
  grid-template-columns: minmax(0, 1.15fr) minmax(10rem, 0.85fr);
  gap: 1.25rem 1.75rem;
  align-items: start;
}

.dashboard-story__body--no-chart {
  grid-template-columns: 1fr;
}

.dashboard-story__copy {
  display: grid;
  gap: 1.15rem;
  min-width: 0;
}

.dashboard-story__featured {
  min-width: 0;
}

.dashboard-story__figures {
  display: grid;
  gap: 0.65rem;
}

.dashboard-story__caption {
  padding-top: 0.15rem;
}

.dashboard-story__figure {
  min-width: 0;
  max-width: 100%;
  overflow: hidden;
}

.dashboard-story__figure-well {
  display: grid;
  gap: 0.65rem;
  min-width: 0;
  max-width: 100%;
  overflow: hidden;
  padding: 1rem 1rem 0.85rem;
  border-radius: 14px;
  background: color-mix(in srgb, var(--bw-theme-border) 28%, var(--bw-theme-surface));
  border: 1px solid color-mix(in srgb, var(--bw-theme-border) 65%, transparent);
}

.dashboard-story__figure-label {
  margin: 0;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.02em;
  text-transform: uppercase;
  color: var(--bw-theme-muted);
}

.dashboard-story__footer {
  margin-top: 0.75rem;
  display: flex;
  justify-content: flex-start;
  gap: 0.5rem;
}

@media (max-width: 720px) {
  .dashboard-story__body:not(.dashboard-story__body--no-chart) {
    grid-template-columns: 1fr;
  }

  .dashboard-story__figure {
    order: -1;
  }
}
</style>
