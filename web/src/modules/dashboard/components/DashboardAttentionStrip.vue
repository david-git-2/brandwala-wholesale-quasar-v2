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
  padding: 0.6rem 1rem;
  background: var(--bw-neutral-surface, #FFFFFF);
  border: 1px solid var(--bw-neutral-border, #E2E8F0);
  border-radius: 10px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.03);
  flex-wrap: wrap;
}

body.body--dark .attention-banner {
  background: #18181B;
  border-color: #27272A;
}

.attention-banner__label {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-shrink: 0;
}

body.body--dark .attention-banner__label .text-slate-700 {
  color: #F4F4F5 !important;
}

.pulse-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: #F59E0B;
  box-shadow: 0 0 0 3px rgba(245, 158, 11, 0.15);
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
  padding: 4px 10px;
  border-radius: 6px;
  font-size: 11.5px;
  font-weight: 500;
  text-decoration: none;
  border: 1px solid transparent;
  transition: all 0.15s ease;
}

.attention-pill:hover {
  transform: translateY(-1px);
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.04);
}

.attention-pill--warn {
  background: #FFFBEB;
  border-color: #FDE68A;
  color: #B45309;
}

.attention-pill--error {
  background: #FEF2F2;
  border-color: #FECACA;
  color: #DC2626;
}

.attention-pill--info {
  background: #EFF6FF;
  border-color: #BFDBFE;
  color: #2563EB;
}

.attention-pill--success {
  background: #F0FDF4;
  border-color: #BBF7D0;
  color: #16A34A;
}

body.body--dark .attention-pill--warn {
  background: rgba(217, 119, 6, 0.15);
  border-color: rgba(217, 119, 6, 0.3);
  color: #FCD34D;
}

body.body--dark .attention-pill--error {
  background: rgba(220, 38, 38, 0.15);
  border-color: rgba(220, 38, 38, 0.3);
  color: #FCA5A5;
}

body.body--dark .attention-pill--info {
  background: rgba(37, 99, 235, 0.15);
  border-color: rgba(37, 99, 235, 0.3);
  color: #93C5FD;
}

body.body--dark .attention-pill--success {
  background: rgba(22, 163, 74, 0.15);
  border-color: rgba(22, 163, 74, 0.3);
  color: #86EFAC;
}

.attention-pill__text {
  font-weight: 600;
}

.attention-pill__sub {
  font-size: 11px;
}

.attention-pill__icon {
  opacity: 0.7;
}
</style>
