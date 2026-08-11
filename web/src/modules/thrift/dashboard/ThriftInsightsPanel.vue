<template>
  <div class="glance">
    <div class="glance__label">Shop glance</div>

    <div v-if="isLoading" class="glance__loading">
      <q-spinner color="primary" size="28px" />
    </div>

    <p v-else-if="isError" class="glance__error">Couldn’t load thrift snapshot</p>

    <div v-else class="glance__layout">
      <div class="glance__metrics">
        <div class="glance__metric">
          <div class="glance__value glance__value--positive">{{ availableItems }}</div>
          <div class="glance__meta">Available</div>
        </div>
        <div class="glance__metric">
          <div class="glance__value">{{ soldItems }}</div>
          <div class="glance__meta">Sold</div>
        </div>
        <router-link class="glance__metric glance__metric--link" :to="codTo">
          <div class="glance__value glance__value--warn">{{ codPendingCount }}</div>
          <div class="glance__meta">COD waiting</div>
          <div class="glance__sub">{{ codExpectedLabel }}</div>
        </router-link>
        <router-link class="glance__metric glance__metric--link" :to="salesTo">
          <div class="glance__value">{{ activeInvoicesToday }}</div>
          <div class="glance__meta">Sales today</div>
        </router-link>
      </div>

      <div class="glance__chart-wrap">
        <div class="glance__chart">
          <Doughnut v-if="hasStockMix" :data="donutData" :options="donutOptions" />
          <p v-else class="glance__empty">No stock yet</p>
          <div v-if="hasStockMix" class="glance__chart-center">
            <span class="glance__chart-pct">{{ availablePct }}%</span>
            <span class="glance__chart-caption">in stock</span>
          </div>
        </div>
        <p class="glance__footnote">Available share of available + sold. Waiting COD is not earned yet.</p>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { RouteLocationRaw } from 'vue-router';
import { storeToRefs } from 'pinia';
import { Doughnut } from 'vue-chartjs';
import type { ChartData, ChartOptions } from 'chart.js';

import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useThriftDashboardMetricsQuery } from 'src/modules/thrift/reports/composables/useThriftReportsQuery';
import { ensureThriftChartsRegistered, rgba, readThemeRgb } from './chartSetup';

ensureThriftChartsRegistered();

const props = defineProps<{
  tenantSlug?: string;
}>();

const authStore = useAuthStore();
const { tenantId } = storeToRefs(authStore);

const { data: metrics, isLoading, isError } = useThriftDashboardMetricsQuery(tenantId);

const availableItems = computed(() => metrics.value?.availableItems ?? 0);
const soldItems = computed(() => metrics.value?.soldItems ?? 0);
const activeInvoicesToday = computed(() => metrics.value?.activeInvoicesToday ?? 0);
const codPendingCount = computed(() => metrics.value?.codPendingCount ?? 0);
const codExpectedLabel = computed(() => {
  const amount = metrics.value?.codExpectedTotal ?? 0;
  return `৳${Number(amount).toFixed(0)} expected`;
});

const tracked = computed(() => availableItems.value + soldItems.value);
const hasStockMix = computed(() => tracked.value > 0);
const availablePct = computed(() =>
  tracked.value > 0 ? Math.round((availableItems.value / tracked.value) * 100) : 0,
);

const primaryRgb = computed(() => readThemeRgb());

const donutData = computed<ChartData<'doughnut'>>(() => ({
  labels: ['Available', 'Sold'],
  datasets: [
    {
      data: [availableItems.value, soldItems.value],
      backgroundColor: [rgba(primaryRgb.value, 0.9), 'rgb(226 232 240)'],
      borderWidth: 0,
      hoverOffset: 2,
    },
  ],
}));

const donutOptions: ChartOptions<'doughnut'> = {
  responsive: true,
  maintainAspectRatio: false,
  cutout: '76%',
  plugins: {
    legend: { display: false },
    tooltip: {
      callbacks: {
        label: (ctx) => ` ${ctx.label}: ${ctx.parsed}`,
      },
    },
  },
};

const withSlug = (name: string): RouteLocationRaw => ({
  name,
  params: props.tenantSlug ? { tenantSlug: props.tenantSlug } : {},
});

const codTo = computed(() => withSlug('thrift-cod-report'));
const salesTo = computed(() => withSlug('thrift-sales-page'));
</script>

<style scoped>
.glance {
  border: 1px solid var(--bw-theme-border);
  border-radius: 14px;
  padding: 1.1rem 1.15rem 1.15rem;
  background: var(--bw-theme-surface);
}

.glance__label {
  font-size: 0.75rem;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--bw-theme-muted);
  margin-bottom: 1rem;
}

.glance__loading {
  display: flex;
  justify-content: center;
  padding: 2rem 0;
}

.glance__error {
  margin: 0;
  color: var(--q-negative);
  font-size: 0.9rem;
}

.glance__layout {
  display: grid;
  gap: 1.5rem;
  grid-template-columns: minmax(0, 1.4fr) minmax(11rem, 0.7fr);
  align-items: center;
}

.glance__metrics {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 1.25rem 1.5rem;
}

.glance__metric {
  min-width: 0;
  color: inherit;
  text-decoration: none;
}

.glance__metric--link:hover .glance__value {
  color: var(--bw-theme-primary);
}

.glance__value {
  font-size: clamp(1.75rem, 3vw, 2.15rem);
  font-weight: 700;
  line-height: 1.05;
  letter-spacing: -0.03em;
  color: var(--bw-theme-ink);
}

.glance__value--positive {
  color: var(--q-positive, #16a34a);
}

.glance__value--warn {
  color: #b45309;
}

.glance__meta {
  margin-top: 0.25rem;
  font-size: 0.875rem;
  color: var(--bw-theme-muted);
}

.glance__sub {
  margin-top: 0.15rem;
  font-size: 0.78rem;
  color: var(--bw-theme-muted);
}

.glance__chart-wrap {
  display: grid;
  gap: 0.65rem;
  justify-items: center;
}

.glance__chart {
  position: relative;
  width: 10.5rem;
  height: 10.5rem;
}

.glance__chart-center {
  position: absolute;
  inset: 0;
  display: grid;
  place-content: center;
  text-align: center;
  pointer-events: none;
}

.glance__chart-pct {
  font-size: 1.45rem;
  font-weight: 700;
  letter-spacing: -0.03em;
  color: var(--bw-theme-ink);
  line-height: 1;
}

.glance__chart-caption {
  margin-top: 0.2rem;
  font-size: 0.72rem;
  color: var(--bw-theme-muted);
  text-transform: uppercase;
  letter-spacing: 0.06em;
}

.glance__empty {
  margin: 0;
  height: 100%;
  display: grid;
  place-items: center;
  color: var(--bw-theme-muted);
  font-size: 0.875rem;
}

.glance__footnote {
  margin: 0;
  max-width: 14rem;
  text-align: center;
  font-size: 0.75rem;
  line-height: 1.4;
  color: var(--bw-theme-muted);
}

@media (max-width: 720px) {
  .glance__layout {
    grid-template-columns: 1fr;
  }

  .glance__chart-wrap {
    order: -1;
  }
}
</style>
