<template>
  <q-card flat bordered class="glance-card q-pa-md">
    <div class="text-caption text-grey-6 text-weight-bold text-uppercase q-mb-md">
      {{ $t('customer_dashboard.glance_title') }}
    </div>

    <div v-if="loading" class="glance-layout">
      <div class="column q-gutter-sm">
        <q-skeleton v-for="n in 5" :key="n" type="rect" height="36px" class="rounded-borders" />
      </div>
      <div class="row flex-center">
        <q-skeleton type="QAvatar" size="148px" />
      </div>
    </div>

    <div v-else class="glance-layout">
      <div class="column q-gutter-xs">
        <button
          v-for="seg in segments"
          :key="seg.id"
          type="button"
          class="glance-legend"
          :class="{ 'glance-legend--hot': seg.hot && seg.count > 0 }"
          :data-test="`glance-${seg.id}`"
          @click="onSelect(seg.id)"
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
        </button>
      </div>

      <div class="glance-chart-wrap">
        <div class="glance-chart" role="img" :aria-label="$t('customer_dashboard.glance_title')">
          <Doughnut :data="donutData" :options="donutOptions" />
          <div class="glance-chart__center">
            <span class="glance-chart__total">{{ total }}</span>
            <span class="glance-chart__caption">{{ $t('customer_dashboard.glance_total') }}</span>
          </div>
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

import type { OrderGlanceBucket } from '../utils/customerDashboardStatus';

ChartJS.register(ArcElement, DoughnutController, Tooltip);

type ChartBucket = OrderGlanceBucket | 'delivered' | 'paid' | 'payment_needed';

/** Dummy mix until customer-dashboard RPC lands. */
const DUMMY_SEGMENTS: ReadonlyArray<{
  id: ChartBucket;
  count: number;
  color: string;
  labelKey: string;
  hot?: boolean;
}> = [
  { id: 'needs_you', count: 3, color: '#d97706', labelKey: 'customer_dashboard.glance_needs_you', hot: true },
  { id: 'in_progress', count: 8, color: '#1e3a8a', labelKey: 'customer_dashboard.glance_in_progress' },
  { id: 'delivered', count: 11, color: '#0284c7', labelKey: 'customer_dashboard.glance_delivered' },
  { id: 'paid', count: 17, color: '#059669', labelKey: 'customer_dashboard.glance_paid' },
  { id: 'payment_needed', count: 4, color: '#dc2626', labelKey: 'customer_dashboard.glance_payment_needed', hot: true },
];

defineProps<{
  loading: boolean;
}>();

const emit = defineEmits<{
  (e: 'select-bucket', bucket?: OrderGlanceBucket): void;
}>();

const { t } = useI18n();

const segments = DUMMY_SEGMENTS;
const total = DUMMY_SEGMENTS.reduce((sum, seg) => sum + seg.count, 0);

const share = (count: number) => `${Math.max(8, Math.round((count / total) * 100))}%`;

const onSelect = (id: ChartBucket) => {
  if (id === 'needs_you' || id === 'in_progress') {
    emit('select-bucket', id);
    return;
  }
  emit('select-bucket');
};

const donutData = computed<ChartData<'doughnut'>>(() => ({
  labels: DUMMY_SEGMENTS.map((seg) => t(seg.labelKey)),
  datasets: [
    {
      data: DUMMY_SEGMENTS.map((seg) => seg.count),
      backgroundColor: DUMMY_SEGMENTS.map((seg) => seg.color),
      borderWidth: 0,
      spacing: 3,
      borderRadius: 5,
      hoverOffset: 6,
    },
  ],
}));

const donutOptions: ChartOptions<'doughnut'> = {
  responsive: true,
  maintainAspectRatio: false,
  cutout: '74%',
  onClick: (_event, elements) => {
    const index = elements[0]?.index;
    if (index == null) return;
    const seg = DUMMY_SEGMENTS[index];
    if (seg) onSelect(seg.id);
  },
  onHover: (event, elements) => {
    const target = event.native?.target as HTMLElement | undefined;
    if (target) target.style.cursor = elements.length ? 'pointer' : 'default';
  },
  plugins: {
    legend: { display: false },
    tooltip: {
      callbacks: {
        label: (ctx) => ` ${ctx.label}: ${ctx.parsed}`,
      },
    },
  },
};
</script>

<style scoped>
.glance-card {
  border-radius: 14px;
  background: var(--bw-theme-surface);
}

.glance-layout {
  display: grid;
  gap: 1.25rem;
  grid-template-columns: minmax(0, 1.2fr) minmax(9.5rem, 0.8fr);
  align-items: center;
}

.glance-legend {
  display: grid;
  grid-template-columns: 10px minmax(0, 1fr) auto;
  align-items: center;
  gap: 0.65rem;
  width: 100%;
  margin: 0;
  padding: 0.45rem 0.5rem;
  border: 0;
  border-radius: 8px;
  background: transparent;
  color: inherit;
  text-align: left;
  cursor: pointer;
}

.glance-legend:hover,
.glance-legend:focus-visible {
  background: var(--bw-theme-primary-soft);
  outline: none;
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
  font-size: 0.8rem;
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
  font-size: 1.05rem;
  font-weight: 700;
  letter-spacing: -0.03em;
  line-height: 1;
  color: var(--bw-theme-ink);
}

.glance-chart-wrap {
  display: grid;
  justify-items: center;
}

.glance-chart {
  position: relative;
  width: 9.75rem;
  height: 9.75rem;
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
  font-size: 1.55rem;
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

@media (max-width: 720px) {
  .glance-layout {
    grid-template-columns: 1fr;
  }

  .glance-chart-wrap {
    order: -1;
  }
}
</style>
