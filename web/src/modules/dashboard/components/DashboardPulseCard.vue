<template>
  <q-card flat bordered class="dashboard-pulse-card">
    <q-card-section class="dashboard-pulse-card__head">
      <div class="dashboard-pulse-card__title-row">
        <span class="dashboard-pulse-card__title">{{ title }}</span>
        <DashboardStubBadge v-if="stub" />
        <slot name="stub" />
      </div>
    </q-card-section>

    <q-card-section class="dashboard-pulse-card__body">
      <div class="dashboard-pulse-card__metrics">
        <slot />
      </div>
      <div class="dashboard-pulse-card__chart">
        <slot name="chart" />
      </div>
    </q-card-section>

    <q-card-section v-if="$slots.visuals" class="dashboard-pulse-card__visuals">
      <slot name="visuals" />
    </q-card-section>

    <q-card-section v-if="$slots.footer" class="dashboard-pulse-card__footer">
      <slot name="footer" />
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import DashboardStubBadge from './DashboardStubBadge.vue';

defineProps<{
  title: string;
  stub?: boolean;
}>();
</script>

<style scoped>
.dashboard-pulse-card {
  border-radius: 14px;
  min-width: 0;
}

.dashboard-pulse-card__head {
  padding-bottom: 0.35rem;
}

.dashboard-pulse-card__title-row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.dashboard-pulse-card__title {
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--bw-theme-muted);
}

.dashboard-pulse-card__body {
  display: grid;
  grid-template-columns: minmax(0, 1.3fr) minmax(10.5rem, 0.7fr);
  gap: 1rem 1.25rem;
  align-items: center;
  padding-top: 0.25rem;
}

.dashboard-pulse-card__metrics {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 1rem 1.25rem;
}

.dashboard-pulse-card__chart {
  min-width: 0;
  display: flex;
  justify-content: center;
}

.dashboard-pulse-card__visuals {
  padding-top: 0.5rem;
  border-top: 1px solid var(--bw-theme-border);
}

.dashboard-pulse-card__footer {
  padding-top: 0.35rem;
  display: flex;
  justify-content: flex-end;
  gap: 0.5rem;
}

@media (max-width: 720px) {
  .dashboard-pulse-card__body {
    grid-template-columns: 1fr;
  }

  .dashboard-pulse-card__chart {
    order: -1;
  }
}
</style>
