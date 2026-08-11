<template>
  <div v-if="item.component" class="dashboard-slot-host">
    <component :is="item.component" :tenant-slug="tenantSlug" />
  </div>
  <router-link
    v-else-if="item.routeName"
    class="dashboard-slot"
    :class="slotClass"
    :to="to"
  >
    <span class="dashboard-slot__icon" aria-hidden="true">
      <i :class="item.icon" />
    </span>
    <span class="dashboard-slot__body">
      <span class="dashboard-slot__title">{{ item.title }}</span>
      <span v-if="item.caption" class="dashboard-slot__caption">{{ item.caption }}</span>
    </span>
    <i class="ph ph-caret-right dashboard-slot__chevron" aria-hidden="true" />
  </router-link>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { RouteLocationRaw } from 'vue-router';

import type { DashboardSlot } from '../types/dashboardSlot';

const props = defineProps<{
  item: DashboardSlot;
  tenantSlug?: string;
  emphasis?: 'primary' | 'default';
}>();

const to = computed((): RouteLocationRaw => {
  const params: Record<string, string | number> = {
    ...(props.item.routeParams ?? {}),
  };
  if (props.tenantSlug) {
    params.tenantSlug = props.tenantSlug;
  }
  return {
    name: props.item.routeName,
    params,
  };
});

const slotClass = computed(() => ({
  'dashboard-slot--primary': props.emphasis === 'primary' || props.item.kind === 'action',
}));
</script>

<style scoped>
.dashboard-slot-host {
  min-width: 0;
}

.dashboard-slot {
  display: flex;
  align-items: center;
  gap: 0.9rem;
  min-height: 72px;
  padding: 0.9rem 1rem;
  border-radius: 14px;
  border: 1px solid var(--bw-theme-border);
  background: var(--bw-theme-surface);
  color: inherit;
  text-decoration: none;
  transition: border-color 0.15s ease;
}

.dashboard-slot:hover {
  border-color: var(--bw-theme-primary);
}

.dashboard-slot__icon {
  flex: 0 0 auto;
  width: 44px;
  height: 44px;
  border-radius: 12px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: var(--bw-theme-primary-soft, rgb(var(--bw-theme-primary-rgb) / 0.15));
  color: var(--bw-theme-primary);
}

.dashboard-slot__icon i {
  font-size: 1.25rem;
}

.dashboard-slot__body {
  flex: 1 1 auto;
  min-width: 0;
  display: grid;
  gap: 0.15rem;
}

.dashboard-slot__title {
  font-size: 1.02rem;
  font-weight: 700;
  line-height: 1.3;
  color: var(--bw-theme-ink);
}

.dashboard-slot__caption {
  font-size: 0.875rem;
  line-height: 1.35;
  color: var(--bw-theme-muted);
}

.dashboard-slot__chevron {
  flex: 0 0 auto;
  color: var(--bw-theme-muted);
  font-size: 1.1rem;
}

.dashboard-slot--primary {
  border-color: rgb(var(--bw-theme-primary-rgb) / 0.28);
}
</style>
