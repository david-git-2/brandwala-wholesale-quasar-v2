<template>
  <q-card flat class="glance-card q-pa-md">
    <div v-if="total === 0" class="text-body2 text-grey-6 text-center">
      {{ $t('customer_dashboard.no_recent_orders') }}
    </div>

    <div v-else class="glance-layout">
      <div class="glance-chart-wrap">
        <div class="glance-chart" role="img" :aria-label="$t('customer_dashboard.glance_title')">
          <Doughnut :data="donutData" :options="donutOptions" />
          <div class="glance-chart__center">
            <span class="glance-chart__total">{{ total }}</span>
            <span class="glance-chart__caption">{{ $t('customer_dashboard.glance_total') }}</span>
          </div>
        </div>
      </div>

      <div class="glance-legend-grid">
        <div
          v-for="seg in segmentRows"
          :key="seg.id"
          class="glance-legend"
          :class="{ 'glance-legend--hot': seg.hot && seg.count > 0 }"
          :data-test="`glance-${seg.id}`"
        >
          <span class="glance-legend__dot" :style="{ background: seg.color }" />
          <span class="glance-legend__meta">
            <span class="glance-legend__label">{{ $t(seg.labelKey) }}</span>
            <span class="glance-legend__track" aria-hidden="true">
              <span
                class="glance-legend__fill"
                :style="{ width: share(seg.count), background: seg.color }"
              />
            </span>
          </span>
          <span class="glance-legend__count">{{ seg.count }}</span>
        </div>
      </div>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { ArcElement, Chart as ChartJS, DoughnutController, Tooltip } from 'chart.js';
import { Doughnut } from 'vue-chartjs';
import type { ChartData, ChartOptions } from 'chart.js';
import { useI18n } from 'vue-i18n';
import { useQuasar } from 'quasar';

import type { OrderGlanceSegments } from '../types/customerDashboard';
import type { OrderGlanceBucket } from '../utils/customerDashboardStatus';

ChartJS.register(ArcElement, DoughnutController, Tooltip);

type ChartBucket = OrderGlanceBucket | 'delivered' | 'paid' | 'payment_needed';

const SEGMENT_META: ReadonlyArray<{
  id: ChartBucket;
  token: string;
  fallback: string;
  labelKey: string;
  hot?: boolean;
}> = [
  { id: 'needs_you', token: '--bw-warning', fallback: '#b45309', labelKey: 'customer_dashboard.glance_needs_you', hot: true },
  { id: 'in_progress', token: '--bw-theme-primary', fallback: '#3368a0', labelKey: 'customer_dashboard.glance_in_progress' },
  { id: 'delivered', token: '--bw-shop-sky', fallback: '#66a3bf', labelKey: 'customer_dashboard.glance_delivered' },
  { id: 'paid', token: '--bw-success', fallback: '#1a7f4b', labelKey: 'customer_dashboard.glance_paid' },
  { id: 'payment_needed', token: '--bw-error', fallback: '#b83a3a', labelKey: 'customer_dashboard.glance_payment_needed', hot: true },
];

function themeColor(token: string, fallback: string) {
  if (typeof document === 'undefined') return fallback;
  return getComputedStyle(document.body).getPropertyValue(token).trim() || fallback;
}

const props = defineProps<{
  segments: OrderGlanceSegments | null;
}>();

const { t } = useI18n();
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

const share = (count: number) => {
  if (total.value <= 0) return '0%';
  return `${Math.max(8, Math.round((count / total.value) * 100))}%`;
};

const donutData = computed<ChartData<'doughnut'>>(() => ({
  labels: segmentRows.value.map((seg) => t(seg.labelKey)),
  datasets: [
    {
      data: segmentRows.value.map((seg) => seg.count),
      backgroundColor: segmentRows.value.map((seg) => seg.color),
      borderWidth: 0,
      spacing: 3,
      borderRadius: 5,
      hoverOffset: 4,
    },
  ],
}));

const donutOptions = computed<ChartOptions<'doughnut'>>(() => ({
  responsive: true,
  maintainAspectRatio: false,
  cutout: '72%',
  plugins: {
    legend: { display: false },
    tooltip: {
      callbacks: {
        label: (ctx) => ` ${ctx.label}: ${ctx.parsed}`,
      },
    },
  },
}));
</script>

<style scoped>
.glance-card {
  border-radius: var(--bw-shop-radius-card, 20px);
  background: var(--bw-theme-surface);
  box-shadow: var(--bw-theme-shadow);
}

.glance-layout {
  display: grid;
  gap: 1.5rem;
}

.glance-chart-wrap {
  display: grid;
  justify-items: center;
}

.glance-chart {
  position: relative;
  width: min(100%, 11.5rem);
  height: 11.5rem;
}

.glance-chart__center {
  position: absolute;
  inset: 0;
  display: grid;
  place-content: center;
  text-align: center;
  pointer-events: none;
}

.glance-chart__total {
  font-size: 1.85rem;
  font-weight: 700;
  letter-spacing: -0.04em;
  line-height: 1;
  color: var(--bw-theme-ink);
}

.glance-chart__caption {
  margin-top: 0.2rem;
  font-size: 0.68rem;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--bw-theme-muted);
}

.glance-legend-grid {
  display: grid;
  gap: 0.5rem;
  grid-template-columns: repeat(auto-fit, minmax(9.5rem, 1fr));
}

.glance-legend {
  display: grid;
  grid-template-columns: 10px minmax(0, 1fr) auto;
  align-items: center;
  gap: 0.65rem;
  padding: 0.5rem 0.6rem;
  border-radius: 10px;
  background: var(--bw-theme-primary-soft, rgb(0 0 0 / 0.03));
}

.glance-legend--hot .glance-legend__count {
  color: var(--q-warning);
}

.glance-legend__dot {
  width: 10px;
  height: 10px;
  border-radius: 999px;
}

.glance-legend__meta {
  min-width: 0;
  display: grid;
  gap: 0.2rem;
}

.glance-legend__label {
  font-size: 0.78rem;
  color: var(--bw-theme-muted);
  line-height: 1.2;
}

.glance-legend__track {
  display: block;
  height: 4px;
  border-radius: 999px;
  overflow: hidden;
  background: var(--bw-theme-border);
}

.glance-legend__fill {
  display: block;
  height: 100%;
  border-radius: 999px;
}

.glance-legend__count {
  font-size: 1rem;
  font-weight: 700;
  letter-spacing: -0.03em;
  line-height: 1;
  color: var(--bw-theme-ink);
}
</style>
