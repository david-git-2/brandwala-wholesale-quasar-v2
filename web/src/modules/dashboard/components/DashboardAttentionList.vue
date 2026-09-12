<template>
  <p class="dashboard-attention">
    <span class="dashboard-attention__prefix">{{ items.length ? 'Needs work' : 'Nothing waiting' }}</span>
    <template v-for="(item, index) in items" :key="item.id">
      <span v-if="index > 0" class="dashboard-attention__sep" aria-hidden="true">·</span>
      <router-link class="dashboard-attention__link" :to="item.to">{{ item.label }}</router-link>
    </template>
  </p>
</template>

<script setup lang="ts">
import type { DashboardAttentionItem } from '../composables/useDashboardAttention';

defineProps<{
  items: DashboardAttentionItem[];
}>();
</script>

<style scoped>
.dashboard-attention {
  margin: 0;
  font-size: 13px;
  line-height: 1.5;
  color: var(--bw-theme-muted);
}

.dashboard-attention__prefix {
  margin-right: 0.35rem;
}

.dashboard-attention__sep {
  margin: 0 0.35rem;
}

.dashboard-attention__link {
  color: var(--bw-warning);
  font-weight: 500;
  text-decoration: none;
}

.dashboard-attention__link:hover {
  text-decoration: underline;
  text-underline-offset: 3px;
}
</style>
