<template>
  <div class="dashboard-scorecard">
    <!-- Card 1: Gross Invoiced Sales -->
    <div
      class="scorecard-tile"
      :class="{ 'scorecard-tile--link': !!routes?.reportsSalesSummary }"
      @click="navigateTo(routes?.reportsSalesSummary)"
    >
      <div class="scorecard-tile__header">
        <span class="scorecard-tile__label">Gross Invoiced Sales</span>
        <span
          v-if="revenueDeltaPct !== undefined"
          class="trend-indicator trend-indicator--positive"
        >
          <q-icon :name="revenueDeltaPct >= 0 ? 'ph ph-arrow-up-right' : 'ph ph-arrow-down-right'" size="12px" />
          {{ Math.abs(revenueDeltaPct).toFixed(1) }}%
        </span>
      </div>
      <div class="scorecard-tile__value-row">
        <span class="currency-symbol">৳</span>
        <span class="main-number">{{ formatNumberOnly(revenue) }}</span>
      </div>
      <div class="scorecard-tile__footer">
        <span class="footer-caption">{{ revenueSubtext || 'Total billed turnover' }}</span>
        <span class="trend-sub">vs last 30d</span>
      </div>
    </div>

    <!-- Card 2: Liquid Cash & Bank Position -->
    <div
      class="scorecard-tile"
      :class="{ 'scorecard-tile--link': !!routes?.walletHome }"
      @click="navigateTo(routes?.walletHome)"
    >
      <div class="scorecard-tile__header">
        <span class="scorecard-tile__label">Liquid Cash & Bank</span>
        <span class="stat-pill-neutral">
          {{ accountCount }} accounts
        </span>
      </div>
      <div class="scorecard-tile__value-row">
        <span class="currency-symbol">৳</span>
        <span class="main-number">{{ formatNumberOnly(liquidCash) }}</span>
      </div>
      <div class="scorecard-tile__footer">
        <span class="footer-caption">Double-entry ledger balance</span>
        <span class="status-dot-active">Real-time</span>
      </div>
    </div>

    <!-- Card 3: Customer Receivables (Dues) -->
    <div
      class="scorecard-tile"
      :class="{ 'scorecard-tile--link': !!routes?.reportsCustomerDues }"
      @click="navigateTo(routes?.reportsCustomerDues)"
    >
      <div class="scorecard-tile__header">
        <span class="scorecard-tile__label">Customer Receivables</span>
        <span v-if="agingOver30dPct > 0" class="trend-indicator trend-indicator--warning">
          {{ agingOver30dPct }}% &gt; 30d
        </span>
        <span v-else class="trend-indicator trend-indicator--positive">
          Healthy
        </span>
      </div>
      <div class="scorecard-tile__value-row">
        <span class="currency-symbol">৳</span>
        <span class="main-number">{{ formatNumberOnly(receivables) }}</span>
      </div>
      <div class="scorecard-tile__footer">
        <span class="footer-caption">Unpaid wholesale credit lines</span>
      </div>
    </div>

    <!-- Card 4: Warehouse Stock Valuation -->
    <div
      class="scorecard-tile"
      :class="{ 'scorecard-tile--link': !!routes?.stockValuation }"
      @click="navigateTo(routes?.stockValuation)"
    >
      <div class="scorecard-tile__header">
        <span class="scorecard-tile__label">Warehouse Stock Asset</span>
        <span class="stat-pill-neutral">
          {{ formatDashboardCount(totalUnits) }} units
        </span>
      </div>
      <div class="scorecard-tile__value-row">
        <span class="currency-symbol">৳</span>
        <span class="main-number">{{ formatNumberOnly(stockValuation) }}</span>
      </div>
      <div class="scorecard-tile__footer">
        <span class="footer-caption">Landed cost in physical bins</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useRouter, type RouteLocationRaw } from 'vue-router';
import { formatDashboardCount, asDashboardNumber } from '../utils/formatDashboardMetric';

withDefaults(
  defineProps<{
    revenue?: number;
    revenueDeltaPct?: number;
    revenueSubtext?: string;
    liquidCash?: number;
    accountCount?: number;
    receivables?: number;
    agingOver30dPct?: number;
    stockValuation?: number;
    totalUnits?: number;
    routes?: {
      reportsSalesSummary?: RouteLocationRaw;
      walletHome?: RouteLocationRaw;
      reportsCustomerDues?: RouteLocationRaw;
      stockValuation?: RouteLocationRaw;
    };
  }>(),
  {
    revenue: 0,
    revenueDeltaPct: 0,
    revenueSubtext: '',
    liquidCash: 0,
    accountCount: 4,
    receivables: 0,
    agingOver30dPct: 0,
    stockValuation: 0,
    totalUnits: 0,
    routes: () => ({}),
  },
);

const router = useRouter();

const navigateTo = (to?: RouteLocationRaw) => {
  if (to) {
    void router.push(to);
  }
};

const formatNumberOnly = (value: unknown): string => {
  const amount = asDashboardNumber(value);
  const abs = Math.abs(amount);
  if (abs >= 1_000_000) {
    const m = abs / 1_000_000;
    const digits = m >= 10 ? 1 : 2;
    return `${m.toFixed(digits).replace(/\.0+$/, '')}M`;
  }
  if (abs >= 10_000) {
    const k = abs / 1000;
    const digits = k >= 100 ? 0 : 1;
    return `${k.toFixed(digits).replace(/\.0+$/, '')}K`;
  }
  return Math.round(abs).toLocaleString();
};
</script>

<style scoped>
.dashboard-scorecard {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 0.85rem;
  width: 100%;
}

.scorecard-tile {
  background: var(--bw-neutral-surface, #FFFFFF);
  border: 1px solid var(--bw-neutral-border, #F1F5F9);
  border-radius: var(--bw-radius-md, 12px);
  padding: 0.85rem 1rem;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.03);
  transition: all 0.15s ease;
  min-height: 105px;
}

.scorecard-tile--link {
  cursor: pointer;
}

.scorecard-tile--link:hover {
  border-color: #CBD5E1;
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.04);
}

.scorecard-tile__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
}

.scorecard-tile__label {
  font-size: 12.5px;
  font-weight: 500;
  color: #64748B;
}

.trend-indicator {
  display: inline-flex;
  align-items: center;
  gap: 2px;
  font-size: 11px;
  font-weight: 600;
}

.trend-indicator--positive {
  color: #10B981;
}

.trend-indicator--warning {
  color: #F59E0B;
}

.stat-pill-neutral {
  font-size: 11px;
  color: #64748B;
  background: #F8FAFC;
  padding: 1px 6px;
  border-radius: var(--bw-radius-sm, 8px);
}

.scorecard-tile__value-row {
  display: flex;
  align-items: baseline;
  gap: 3px;
  margin-top: 0.25rem;
}

.currency-symbol {
  font-size: 18px;
  font-weight: 500;
  color: #94A3B8;
}

.main-number {
  font-family: var(--bw-font-mono, 'IBM Plex Mono', monospace);
  font-size: 26px;
  font-weight: 700;
  letter-spacing: -0.03em;
  color: var(--bw-neutral-ink, #0F172A);
  line-height: 1.1;
}

.scorecard-tile__footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 0.35rem;
}

.footer-caption {
  font-size: 11px;
  color: #94A3B8;
}

.trend-sub {
  font-size: 10.5px;
  color: #94A3B8;
}

.status-dot-active {
  font-size: 10.5px;
  color: #10B981;
}

@media (max-width: 1024px) {
  .dashboard-scorecard {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 600px) {
  .dashboard-scorecard {
    grid-template-columns: 1fr;
  }
}
</style>
