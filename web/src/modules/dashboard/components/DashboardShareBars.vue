<template>
  <ul class="dashboard-share-bars">
    <li v-for="row in rows" :key="row.label" class="dashboard-share-bars__row">
      <div class="dashboard-share-bars__head">
        <span class="dashboard-share-bars__label">{{ row.label }}</span>
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
  gap: 0.55rem;
}

.dashboard-share-bars__row {
  display: grid;
  gap: 0.25rem;
}

.dashboard-share-bars__head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.5rem;
}

.dashboard-share-bars__label {
  font-size: 0.78rem;
  color: var(--bw-theme-muted);
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.dashboard-share-bars__value {
  font-size: 0.78rem;
  font-weight: 700;
  color: var(--bw-theme-ink);
  flex-shrink: 0;
}

.dashboard-share-bars__track {
  height: 6px;
  border-radius: 999px;
  background: color-mix(in srgb, var(--bw-theme-border) 60%, transparent);
  overflow: hidden;
}

.dashboard-share-bars__fill {
  height: 100%;
  border-radius: 999px;
  transition: width 0.2s ease;
}

.dashboard-share-bars__fill--primary {
  background: var(--bw-theme-primary);
}

.dashboard-share-bars__fill--warn {
  background: var(--bw-warning);
}

.dashboard-share-bars__fill--success {
  background: var(--bw-success);
}

.dashboard-share-bars__empty {
  font-size: 0.8rem;
  color: var(--bw-theme-muted);
  text-align: center;
  padding: 0.5rem 0;
}
</style>
