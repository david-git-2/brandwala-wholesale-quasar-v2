<template>
  <component
    :is="to ? 'router-link' : 'div'"
    class="dashboard-metric"
    :class="[
      `dashboard-metric--${effectiveTone}`,
      { 'dashboard-metric--featured': featured, 'dashboard-metric--link': Boolean(to) },
    ]"
    :to="to"
  >
    <template v-if="featured">
      <span class="dashboard-metric__value dashboard-metric__value--featured bw-tabular">{{ value }}</span>
      <span class="dashboard-metric__label dashboard-metric__label--featured">{{ label }}</span>
      <span v-if="unit" class="dashboard-metric__unit">{{ unit }}</span>
    </template>
    <template v-else>
      <span class="dashboard-metric__label">{{ label }}</span>
      <span class="dashboard-metric__value-row">
        <span class="dashboard-metric__value bw-tabular">{{ value }}</span>
        <span v-if="unit" class="dashboard-metric__unit">{{ unit }}</span>
      </span>
    </template>
  </component>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { RouteLocationRaw } from 'vue-router';
import { isDashboardMetricZero } from '../utils/formatDashboardMetric';

const props = withDefaults(
  defineProps<{
    label: string;
    value: string;
    unit?: string;
    to?: RouteLocationRaw;
    tone?: 'ink' | 'ok' | 'warn' | 'muted';
    featured?: boolean;
  }>(),
  {
    tone: 'ink',
    featured: false,
  },
);

const effectiveTone = computed(() => {
  if (props.tone === 'warn' && isDashboardMetricZero(props.value)) {
    return 'ink';
  }
  return props.tone;
});
</script>

<style scoped>
.dashboard-metric {
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
  min-width: 0;
  color: inherit;
  text-decoration: none;
}

.dashboard-metric--link:hover .dashboard-metric__value {
  text-decoration: underline;
  text-underline-offset: 3px;
}

.dashboard-metric__label {
  font-size: 12px;
  font-weight: 500;
  color: var(--bw-theme-muted);
  line-height: 1.3;
}

.dashboard-metric__label--featured {
  font-size: 13px;
  margin-top: 0.15rem;
}

.dashboard-metric__value-row {
  display: flex;
  align-items: baseline;
  gap: 0.35rem;
}

.dashboard-metric__value {
  font-size: 15px;
  font-weight: 600;
  letter-spacing: -0.02em;
  line-height: 1.2;
  color: var(--bw-theme-ink);
}

.dashboard-metric__value--featured {
  font-size: clamp(2rem, 3.2vw, 2.75rem);
  font-weight: 700;
  letter-spacing: -0.04em;
  line-height: 1.05;
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
  font-size: 12px;
  font-weight: 500;
  color: var(--bw-theme-muted);
}
</style>
