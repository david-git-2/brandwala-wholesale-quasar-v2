<template>
  <ul class="dashboard-share-bars">
    <li v-for="row in rows" :key="row.label" class="dashboard-share-bars__row">
      <div class="dashboard-share-bars__head">
        <span class="dashboard-share-bars__label">{{ row.label }}</span>
        <span class="dashboard-share-bars__sep" aria-hidden="true">·</span>
        <span class="dashboard-share-bars__value bw-tabular">{{ row.displayValue ?? row.value }}</span>
      </div>
      <div class="dashboard-share-bars__track">
        <div
          class="dashboard-share-bars__fill"
          :class="`dashboard-share-bars__fill--${row.tone ?? 'primary'}`"
          :style="{ width: barWidth(row) }"
        />
      </div>
    </li>
    <li v-if="!rows.length" class="dashboard-share-bars__empty">{{ emptyLabel }}</li>
  </ul>
</template>

<script setup lang="ts">
export type DashboardShareBarRow = {
  label: string;
  value: number;
  max?: number;
  displayValue?: string;
  tone?: 'primary' | 'warn' | 'success';
};

const props = withDefaults(
  defineProps<{
    rows: DashboardShareBarRow[];
    emptyLabel?: string;
  }>(),
  {
    emptyLabel: 'Nothing to show',
  },
);

const barWidth = (row: DashboardShareBarRow) => {
  const max = row.max ?? Math.max(1, ...props.rows.map((r) => r.value));
  const pct = Math.round((row.value / max) * 100);
  return `${Math.max(pct, row.value > 0 ? 4 : 0)}%`;
};
</script>

<style scoped>
.dashboard-share-bars {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 0.65rem;
}

.dashboard-share-bars__row {
  display: grid;
  gap: 0.3rem;
}

.dashboard-share-bars__head {
  display: flex;
  align-items: baseline;
  flex-wrap: wrap;
  gap: 0.25rem;
  font-size: 12px;
  line-height: 1.35;
}

.dashboard-share-bars__label {
  color: var(--bw-theme-muted);
  min-width: 0;
}

.dashboard-share-bars__sep {
  color: var(--bw-theme-muted);
}

.dashboard-share-bars__value {
  font-weight: 600;
  color: var(--bw-theme-ink);
}

.dashboard-share-bars__track {
  height: 8px;
  border-radius: 999px;
  background: var(--bw-theme-border);
  overflow: hidden;
}

.dashboard-share-bars__fill {
  height: 100%;
  border-radius: 999px;
  transition: width 0.2s ease;
}

.dashboard-share-bars__fill--primary {
  background: color-mix(in srgb, var(--bw-theme-primary) 70%, transparent);
}

.dashboard-share-bars__fill--warn {
  background: color-mix(in srgb, var(--bw-warning) 70%, transparent);
}

.dashboard-share-bars__fill--success {
  background: color-mix(in srgb, var(--bw-success) 70%, transparent);
}

.dashboard-share-bars__empty {
  font-size: 12px;
  color: var(--bw-theme-muted);
}
</style>
