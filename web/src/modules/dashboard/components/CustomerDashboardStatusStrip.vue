<template>
  <div class="glance-block">
    <div v-if="total === 0" class="text-body2 tf-text-muted">
      {{ $t('customer_dashboard.no_recent_orders') }}
    </div>

    <div v-else class="glance-pills">
      <div
        v-for="seg in segmentRows"
        :key="seg.id"
        class="glance-pill"
        :class="{ 'glance-pill--hot': seg.hot && seg.count > 0 }"
        :data-test="`glance-${seg.id}`"
      >
        <span class="glance-pill__dot" :style="{ background: seg.color }" />
        <span class="glance-pill__label">{{ $t(seg.labelKey) }}</span>
        <span class="glance-pill__count">{{ seg.count }}</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useQuasar } from 'quasar';

import type { OrderGlanceSegments } from '../types/customerDashboard';
import type { OrderGlanceBucket } from '../utils/customerDashboardStatus';

type ChartBucket = OrderGlanceBucket | 'delivered' | 'paid' | 'payment_needed';

const SEGMENT_META: ReadonlyArray<{
  id: ChartBucket;
  token: string;
  fallback: string;
  labelKey: string;
  hot?: boolean;
}> = [
  { id: 'needs_you', token: '--tf-warning', fallback: '#b45309', labelKey: 'customer_dashboard.glance_needs_you', hot: true },
  { id: 'in_progress', token: '--tf-theme-primary', fallback: '#3368a0', labelKey: 'customer_dashboard.glance_in_progress' },
  { id: 'delivered', token: '--tf-shop-sky', fallback: '#66a3bf', labelKey: 'customer_dashboard.glance_delivered' },
  { id: 'paid', token: '--tf-success', fallback: '#1a7f4b', labelKey: 'customer_dashboard.glance_paid' },
  { id: 'payment_needed', token: '--tf-error', fallback: '#b83a3a', labelKey: 'customer_dashboard.glance_payment_needed', hot: true },
];

function themeColor(token: string, fallback: string) {
  if (typeof document === 'undefined') return fallback;
  return getComputedStyle(document.body).getPropertyValue(token).trim() || fallback;
}

const props = defineProps<{
  segments: OrderGlanceSegments | null;
}>();

const $q = useQuasar();

const segmentRows = computed(() => {
  void $q.dark.isActive;
  return SEGMENT_META.map((meta) => ({
    ...meta,
    color: themeColor(meta.token, meta.fallback),
    count: props.segments?.[meta.id] ?? 0,
  }));
});

const total = computed(() => props.segments?.total ?? 0);
</script>

<style scoped>
.glance-pills {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  align-items: stretch;
  max-width: 100%;
}

.glance-pill {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  width: fit-content;
  max-width: 100%;
  padding: 0.45rem 0.65rem;
  border-radius: 999px;
  background: var(--shop-home-pill-bg, #f0f2f5);
  border: 0;
}

.glance-pill--hot .glance-pill__count {
  color: var(--q-warning);
}

.glance-pill__dot {
  flex-shrink: 0;
  width: 10px;
  height: 10px;
  border-radius: 999px;
}

.glance-pill__label {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--tf-theme-muted);
  line-height: 1.25;
  white-space: nowrap;
}

.glance-pill__count {
  flex-shrink: 0;
  font-size: 0.9375rem;
  font-weight: 700;
  letter-spacing: -0.03em;
  line-height: 1;
  color: var(--tf-theme-ink);
  font-variant-numeric: tabular-nums;
}
</style>
