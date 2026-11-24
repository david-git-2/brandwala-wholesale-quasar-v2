<template>
  <div class="glance-block">
    <div v-if="total === 0" class="text-body2 tf-text-muted">
      {{ $t('customer_dashboard.no_recent_orders') }}
    </div>

    <div v-else class="glance-pills">
      <component
        :is="ordersRoute ? 'router-link' : 'div'"
        v-for="seg in segmentRows"
        :key="seg.id"
        :to="segmentRoute(seg.bucket)"
        class="glance-pill"
        :class="{
          'glance-pill--hot': seg.hot && seg.count > 0,
          'glance-pill--muted': seg.count === 0,
          'glance-pill--interactive': Boolean(ordersRoute),
        }"
        :data-test="`glance-${seg.id}`"
      >
        <span class="glance-pill__dot" :style="{ background: seg.color }" />
        <span class="glance-pill__label">{{ $t(seg.labelKey) }}</span>
        <span class="glance-pill__count">{{ seg.count }}</span>
      </component>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useQuasar } from 'quasar';
import type { RouteLocationRaw } from 'vue-router';

import type { OrderGlanceSegments } from '../types/customerDashboard';
import type { OrderGlanceBucket } from '../utils/customerDashboardStatus';

type ChartBucket = OrderGlanceBucket | 'delivered' | 'paid' | 'payment_needed';

const SEGMENT_META: ReadonlyArray<{
  id: ChartBucket;
  bucket?: OrderGlanceBucket;
  token: string;
  fallback: string;
  labelKey: string;
  hot?: boolean;
}> = [
  { id: 'needs_you', bucket: 'needs_you', token: '--tf-warning', fallback: '#b45309', labelKey: 'customer_dashboard.glance_needs_you', hot: true },
  { id: 'in_progress', bucket: 'in_progress', token: '--tf-theme-primary', fallback: '#3368a0', labelKey: 'customer_dashboard.glance_in_progress' },
  { id: 'delivered', bucket: 'done', token: '--tf-shop-sky', fallback: '#66a3bf', labelKey: 'customer_dashboard.glance_delivered' },
  { id: 'paid', bucket: 'done', token: '--tf-success', fallback: '#1a7f4b', labelKey: 'customer_dashboard.glance_paid' },
  { id: 'payment_needed', token: '--tf-error', fallback: '#b83a3a', labelKey: 'customer_dashboard.glance_payment_needed', hot: true },
];

function themeColor(token: string, fallback: string) {
  if (typeof document === 'undefined') return fallback;
  return getComputedStyle(document.body).getPropertyValue(token).trim() || fallback;
}

const props = defineProps<{
  segments: OrderGlanceSegments | null;
  ordersRoute?: {
    name: string;
    params: Record<string, string>;
  } | null;
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

const segmentRoute = (bucket?: OrderGlanceBucket): RouteLocationRaw | undefined => {
  if (!props.ordersRoute) return undefined;
  return bucket
    ? { ...props.ordersRoute, query: { bucket } }
    : props.ordersRoute;
};

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
  text-decoration: none;
}

.glance-pill--interactive {
  cursor: pointer;
  transition:
    transform var(--tf-dur-fast, 120ms) var(--tf-ease, ease),
    filter var(--tf-dur-fast, 120ms) var(--tf-ease, ease);
}

.glance-pill--interactive:hover,
.glance-pill--interactive:focus-visible {
  transform: translateY(-1px);
  filter: brightness(0.96);
}

.glance-pill--hot .glance-pill__count {
  color: var(--q-warning);
}

.glance-pill--muted {
  opacity: 0.55;
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
