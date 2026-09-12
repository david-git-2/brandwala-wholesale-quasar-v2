<template>
  <component
    :is="to ? 'router-link' : 'div'"
    class="dashboard-metric"
    :class="[`dashboard-metric--${tone}`, { 'dashboard-metric--link': Boolean(to) }]"
    :to="to"
  >
    <span class="dashboard-metric__label">{{ label }}</span>
    <span class="dashboard-metric__value-row">
      <span class="dashboard-metric__value" :class="{ 'bw-tabular': tabular }">{{ value }}</span>
      <span v-if="unit" class="dashboard-metric__unit">{{ unit }}</span>
    </span>
  </component>
</template>

<script setup lang="ts">
import type { RouteLocationRaw } from 'vue-router';

withDefaults(
  defineProps<{
    label: string;
    value: string;
    unit?: string;
    to?: RouteLocationRaw;
    tone?: 'ink' | 'ok' | 'warn' | 'muted';
    tabular?: boolean;
  }>(),
  {
    tone: 'ink',
    tabular: true,
  },
);
</script>

<style scoped>
.dashboard-metric {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  min-width: 0;
  color: inherit;
  text-decoration: none;
}

.dashboard-metric--link:hover .dashboard-metric__value {
  color: var(--bw-theme-primary);
}

.dashboard-metric__label {
  font-size: 0.72rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--bw-theme-muted);
}

.dashboard-metric__value-row {
  display: flex;
  align-items: baseline;
  gap: 0.35rem;
}

.dashboard-metric__value {
  font-size: clamp(1.25rem, 2.5vw, 1.45rem);
  font-weight: 800;
  letter-spacing: -0.02em;
  line-height: 1.15;
  color: var(--bw-theme-ink);
}

.dashboard-metric--ok .dashboard-metric__value {
  color: var(--bw-success);
}

.dashboard-metric--warn .dashboard-metric__value {
  color: var(--bw-warning);
}

.dashboard-metric--muted .dashboard-metric__value {
  color: var(--bw-theme-muted);
}

.dashboard-metric__unit {
  font-size: 0.76rem;
  font-weight: 600;
  color: var(--bw-theme-muted);
}
</style>
