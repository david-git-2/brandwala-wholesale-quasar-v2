<template>
  <q-card flat bordered class="dashboard-attention">
    <q-card-section class="dashboard-attention__head">
      <span class="dashboard-attention__title">Needs attention</span>
    </q-card-section>
    <q-list dense separator class="dashboard-attention__list">
      <router-link
        v-for="item in items"
        :key="item.id"
        class="dashboard-attention__row"
        :to="item.to"
      >
        <q-icon name="ph ph-warning-circle" class="dashboard-attention__icon" />
        <span class="dashboard-attention__label">{{ item.label }}</span>
        <span class="dashboard-attention__value bw-tabular">{{ item.value }}</span>
        <q-icon name="ph ph-caret-right" class="dashboard-attention__chevron" />
      </router-link>
    </q-list>
  </q-card>
</template>

<script setup lang="ts">
import type { DashboardAttentionItem } from '../composables/useDashboardAttention';

defineProps<{
  items: DashboardAttentionItem[];
}>();
</script>

<style scoped>
.dashboard-attention {
  border-radius: 14px;
}

.dashboard-attention__head {
  padding-bottom: 0.35rem;
}

.dashboard-attention__title {
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--bw-theme-muted);
}

.dashboard-attention__list {
  padding: 0;
}

.dashboard-attention__row {
  display: flex;
  align-items: center;
  gap: 0.65rem;
  padding: 0.65rem 1rem;
  color: inherit;
  text-decoration: none;
  transition: background-color 0.15s ease;
}

.dashboard-attention__row:hover {
  background: var(--bw-theme-primary-soft, color-mix(in srgb, var(--bw-theme-primary) 12%, transparent));
}

.dashboard-attention__icon {
  color: var(--bw-warning);
  font-size: 1.1rem;
  flex-shrink: 0;
}

.dashboard-attention__label {
  flex: 1 1 auto;
  min-width: 0;
  font-size: 0.9rem;
  font-weight: 600;
  color: var(--bw-theme-ink);
}

.dashboard-attention__value {
  font-size: 0.85rem;
  font-weight: 700;
  color: var(--bw-warning);
  flex-shrink: 0;
}

.dashboard-attention__chevron {
  color: var(--bw-theme-muted);
  font-size: 1rem;
  flex-shrink: 0;
}
</style>
