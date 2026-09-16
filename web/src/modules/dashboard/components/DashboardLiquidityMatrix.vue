<template>
  <div class="liquidity-card">
    <div class="liquidity-header">
      <div class="row items-center q-gutter-x-xs">
        <span class="liquidity-title">Treasury & Liquidity Runway</span>
      </div>
      <router-link :to="routes.walletHome()" class="liquidity-view-all">
        Wallet ledger <q-icon name="ph ph-arrow-right" size="11px" />
      </router-link>
    </div>

    <div class="liquidity-body">
      <!-- 30-Day Liquidity Buffer Bar -->
      <div class="runway-summary">
        <div class="runway-row">
          <span class="text-caption text-slate-500">30-Day Projected Net Buffer</span>
          <span class="text-caption text-weight-bold text-emerald bw-tabular">+{{ formatDashboardMoney(netLiquidity) }}</span>
        </div>
        <div class="runway-progress">
          <div class="runway-progress__fill" :style="{ width: `${coveragePct}%` }" />
        </div>
        <div class="runway-sub-row text-caption-xs text-slate-400">
          <span>Inflows: <strong class="text-slate-700 bw-tabular">{{ formatDashboardMoney(totalInflows) }}</strong></span>
          <span>Outflows: <strong class="text-slate-700 bw-tabular">-{{ formatDashboardMoney(totalOutflows) }}</strong></span>
        </div>
      </div>

      <!-- Financial Metrics Grid -->
      <div class="ledger-metrics-grid">
        <div class="ledger-cell">
          <span class="cell-label text-slate-500">Bank Balance</span>
          <span class="cell-val text-slate-900 bw-tabular">{{ formatDashboardMoney(bankBalance) }}</span>
        </div>
        <div class="ledger-cell">
          <span class="cell-label text-slate-500">Courier COD Holding</span>
          <span class="cell-val text-amber-700 bw-tabular">{{ formatDashboardMoney(courierCodTotal) }}</span>
        </div>
        <div class="ledger-cell">
          <span class="cell-label text-slate-500">Customer Receivables</span>
          <span class="cell-val text-slate-900 bw-tabular">{{ formatDashboardMoney(customerDues) }}</span>
        </div>
        <div class="ledger-cell">
          <span class="cell-label text-slate-500">Vendor Payables</span>
          <span class="cell-val text-rose-700 bw-tabular">-{{ formatDashboardMoney(vendorPayables) }}</span>
        </div>
      </div>

      <!-- Courier COD Snapshot -->
      <div class="cod-strip">
        <div class="cod-header">
          <span class="text-caption text-weight-medium text-slate-500">Courier COD Remittance</span>
          <router-link :to="routes.walletHome()" class="text-caption text-slate-400 hover-dark">Reconcile</router-link>
        </div>
        <div class="cod-partners">
          <div class="cod-partner">
            <span class="partner-dot partner-dot--steadfast" />
            <span class="partner-name text-slate-600">Steadfast</span>
            <span class="partner-val text-slate-900 bw-tabular">{{ formatDashboardMoney(steadfastCod) }}</span>
          </div>
          <div class="cod-partner">
            <span class="partner-dot partner-dot--pathao" />
            <span class="partner-name text-slate-600">Pathao</span>
            <span class="partner-val text-slate-900 bw-tabular">{{ formatDashboardMoney(pathaoCod) }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { formatDashboardMoney } from '../utils/formatDashboardMetric';
import { useAppDashboardRoutes } from '../composables/useAppDashboardRoutes';

const props = withDefaults(
  defineProps<{
    bankBalance?: number;
    courierCodTotal?: number;
    customerDues?: number;
    vendorPayables?: number;
    investorYieldDue?: number;
    steadfastCod?: number;
    pathaoCod?: number;
  }>(),
  {
    bankBalance: 1840000,
    courierCodTotal: 920000,
    customerDues: 1220400,
    vendorPayables: 1120000,
    investorYieldDue: 340000,
    steadfastCod: 540000,
    pathaoCod: 380000,
  },
);

const routes = useAppDashboardRoutes();

const totalInflows = computed(
  () => props.bankBalance + props.courierCodTotal + props.customerDues,
);

const totalOutflows = computed(
  () => props.vendorPayables + props.investorYieldDue,
);

const netLiquidity = computed(() => totalInflows.value - totalOutflows.value);

const coveragePct = computed(() => {
  if (totalInflows.value <= 0) return 0;
  const ratio = (totalInflows.value / (totalInflows.value + totalOutflows.value)) * 100;
  return Math.min(100, Math.max(10, Math.round(ratio)));
});
</script>

<style scoped>
.liquidity-card {
  background: var(--bw-neutral-surface, #FFFFFF);
  border: 1px solid var(--bw-neutral-border, #F1F5F9);
  border-radius: var(--bw-radius-md, 12px);
  padding: 0.85rem 1rem;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.03);
}

.liquidity-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.75rem;
}

.liquidity-title {
  font-size: 13px;
  font-weight: 600;
  color: #0F172A;
}

.liquidity-view-all {
  font-size: 11.5px;
  font-weight: 500;
  color: #64748B;
  text-decoration: none;
  display: flex;
  align-items: center;
  gap: 3px;
}

.liquidity-view-all:hover {
  color: #0F172A;
}

.liquidity-body {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.runway-summary {
  background: #F8FAFC;
  border-radius: 6px;
  padding: 0.6rem 0.75rem;
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
}

.runway-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.runway-progress {
  height: 5px;
  border-radius: 3px;
  background: #E2E8F0;
  overflow: hidden;
}

.runway-progress__fill {
  height: 100%;
  background: #10B981;
  border-radius: 3px;
}

.runway-sub-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.ledger-metrics-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 0.5rem;
}

.ledger-cell {
  padding: 0.5rem 0.65rem;
  background: #F8FAFC;
  border-radius: 6px;
  display: flex;
  flex-direction: column;
}

.cell-label {
  font-size: 11px;
}

.cell-val {
  font-size: 14px;
  font-weight: 700;
  margin-top: 1px;
}

.cod-strip {
  border-top: 1px solid #F1F5F9;
  padding-top: 0.5rem;
}

.cod-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.35rem;
}

.cod-partners {
  display: flex;
  gap: 0.5rem;
}

.cod-partner {
  flex: 1;
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: 11.5px;
  padding: 0.35rem 0.5rem;
  background: #F8FAFC;
  border-radius: 4px;
}

.partner-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  flex-shrink: 0;
}

.partner-dot--steadfast { background: #EF4444; }
.partner-dot--pathao { background: #F97316; }

.partner-name {
  font-size: 11px;
}

.partner-val {
  margin-left: auto;
  font-weight: 600;
}

.text-emerald { color: #10B981; }
.text-amber-700 { color: #B45309; }
.text-rose-700 { color: #BE123C; }
.text-slate-400 { color: #94A3B8; }
.text-slate-500 { color: #64748B; }
.text-slate-600 { color: #475569; }
.text-slate-700 { color: #334155; }
.text-slate-900 { color: #0F172A; }
.text-caption-xs { font-size: 10px; }
.hover-dark:hover { color: #0F172A; }
</style>
