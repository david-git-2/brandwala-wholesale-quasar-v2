<template>
  <div v-if="displayItems.length" class="attention-banner">
    <div class="attention-banner__label">
      <span class="pulse-dot" />
      <span class="text-caption text-weight-bold text-slate-700">Needs Attention</span>
    </div>
    <div class="attention-banner__items">
      <router-link
        v-for="item in displayItems"
        :key="item.id"
        :to="item.to"
        class="attention-pill"
        :class="`attention-pill--${item.tone || 'warn'}`"
      >
        <span class="attention-pill__text">{{ item.label }}</span>
        <span v-if="item.sublabel" class="attention-pill__sub text-slate-500">· {{ item.sublabel }}</span>
        <q-icon name="ph ph-arrow-up-right" size="11px" class="attention-pill__icon" />
      </router-link>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { RouteLocationRaw } from 'vue-router';

export type AttentionStripItem = {
  id: string;
  label: string;
  value?: string;
  sublabel?: string;
  to: RouteLocationRaw;
  tone?: 'warn' | 'error' | 'info' | 'success';
  icon?: string;
};

const props = withDefaults(
  defineProps<{
    items?: AttentionStripItem[];
  }>(),
  {
    items: () => [],
  },
);

const displayItems = computed(() => props.items);
</script>

<style scoped>
.attention-banner {
  display: flex;
  align-items: center;
  gap: 0.85rem;
  padding: 0.5rem 0.85rem;
  background: var(--bw-neutral-surface, #FFFFFF);
  border: 1px solid var(--bw-neutral-border, #F1F5F9);
  border-radius: var(--bw-radius-sm, 8px);
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.02);
  flex-wrap: wrap;
}

.attention-banner__label {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-shrink: 0;
}

.pulse-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #F59E0B;
  box-shadow: 0 0 0 2px rgba(245, 158, 11, 0.2);
}

.attention-banner__items {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.attention-pill {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 3px 8px;
  border-radius: 6px;
  font-size: 11.5px;
  font-weight: 500;
  text-decoration: none;
  transition: all 0.15s ease;
}

.attention-pill:hover {
  filter: brightness(0.96);
  transform: translateY(-1px);
}

.attention-pill--warn {
  background: #FEF3C7;
  color: #92400E;
}

.attention-pill--error {
  background: #FEE2E2;
  color: #991B1B;
}

.attention-pill--info {
  background: #E0F2FE;
  color: #075985;
}

.attention-pill--success {
  background: #DCFCE7;
  color: #166534;
}

.attention-pill__text {
  font-weight: 600;
}

.attention-pill__sub {
  font-size: 11px;
}

.attention-pill__icon {
  opacity: 0.6;
}
</style>
