<template>
  <div class="fulfillment-card">
    <div class="fulfillment-header">
      <div class="row items-center q-gutter-x-xs">
        <span class="fulfillment-title">Orders & Fulfillment Pipeline</span>
      </div>
      <router-link :to="routes.shopOrders()" class="fulfillment-view-all">
        View all <q-icon name="ph ph-arrow-right" size="11px" />
      </router-link>
    </div>

    <!-- Linear Flow Stepper Track -->
    <div class="stepper-track">
      <!-- Stage 1: Pending Approval -->
      <div
        class="step-item"
        @click="navigateTo(routes.shopOrders({ status: 'pending' }))"
      >
        <div class="step-progress-bar step-progress-bar--pending" />
        <div class="step-meta">
          <span class="step-name">Pending Approval</span>
          <span class="step-count bw-tabular">{{ formatDashboardCount(pendingCount) }}</span>
        </div>
        <div class="step-sub text-slate-400">{{ formatDashboardMoney(pendingAmount) }}</div>
      </div>

      <!-- Stage 2: Warehouse Picking -->
      <div
        class="step-item"
        @click="navigateTo(routes.shopOrders({ status: 'processing' }))"
      >
        <div class="step-progress-bar step-progress-bar--processing" />
        <div class="step-meta">
          <span class="step-name">Warehouse Picking</span>
          <span class="step-count bw-tabular">{{ formatDashboardCount(processingCount) }}</span>
        </div>
        <div class="step-sub text-slate-400">{{ formatDashboardCount(processingUnits) }} pcs queued</div>
      </div>

      <!-- Stage 3: In Courier Transit -->
      <div
        class="step-item"
        @click="navigateTo(routes.shopOrders({ status: 'dispatched' }))"
      >
        <div class="step-progress-bar step-progress-bar--transit" />
        <div class="step-meta">
          <span class="step-name">In Courier Transit</span>
          <span class="step-count bw-tabular">{{ formatDashboardCount(inTransitCount) }}</span>
        </div>
        <div class="step-sub text-slate-400">Pathao / Steadfast</div>
      </div>

      <!-- Stage 4: Delivered & Settled -->
      <div
        class="step-item"
        @click="navigateTo(routes.shopOrders({ status: 'delivered' }))"
      >
        <div class="step-progress-bar step-progress-bar--delivered" />
        <div class="step-meta">
          <span class="step-name">Delivered & Settled</span>
          <span class="step-count bw-tabular text-emerald">{{ formatDashboardCount(deliveredCount) }}</span>
        </div>
        <div class="step-sub text-emerald">Reconciled</div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useRouter, type RouteLocationRaw } from 'vue-router';
import { formatDashboardCount, formatDashboardMoney } from '../utils/formatDashboardMetric';
import { useAppDashboardRoutes } from '../composables/useAppDashboardRoutes';

withDefaults(
  defineProps<{
    pendingCount?: number;
    pendingAmount?: number;
    processingCount?: number;
    processingUnits?: number;
    inTransitCount?: number;
    deliveredCount?: number;
  }>(),
  {
    pendingCount: 18,
    pendingAmount: 245000,
    processingCount: 32,
    processingUnits: 140,
    inTransitCount: 64,
    deliveredCount: 128,
  },
);

const router = useRouter();
const routes = useAppDashboardRoutes();

const navigateTo = (to: RouteLocationRaw) => {
  void router.push(to);
};
</script>

<style scoped>
.fulfillment-card {
  background: var(--bw-neutral-surface, #FFFFFF);
  border: 1px solid var(--bw-neutral-border, #F1F5F9);
  border-radius: var(--bw-radius-md, 12px);
  padding: 0.85rem 1rem;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.03);
}

.fulfillment-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.75rem;
}

.fulfillment-title {
  font-size: 13px;
  font-weight: 600;
  color: #0F172A;
}

.fulfillment-view-all {
  font-size: 11.5px;
  font-weight: 500;
  color: #64748B;
  text-decoration: none;
  display: flex;
  align-items: center;
  gap: 3px;
}

.fulfillment-view-all:hover {
  color: #0F172A;
}

.stepper-track {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 1rem;
}

.step-item {
  display: flex;
  flex-direction: column;
  cursor: pointer;
  padding: 0.25rem 0;
  transition: all 0.15s ease;
}

.step-item:hover .step-name {
  color: #0F172A;
}

.step-progress-bar {
  height: 3px;
  border-radius: 2px;
  margin-bottom: 0.5rem;
  background: #E2E8F0;
}

.step-progress-bar--pending { background: #3B82F6; }
.step-progress-bar--processing { background: #F59E0B; }
.step-progress-bar--transit { background: #6366F1; }
.step-progress-bar--delivered { background: #10B981; }

.step-meta {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.5rem;
}

.step-name {
  font-size: 12px;
  font-weight: 500;
  color: #475569;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.step-count {
  font-size: 15px;
  font-weight: 700;
  color: #0F172A;
}

.step-sub {
  font-size: 11px;
  margin-top: 1px;
}

.text-emerald {
  color: #10B981;
}
.text-slate-400 {
  color: #94A3B8;
}

@media (max-width: 768px) {
  .stepper-track {
    grid-template-columns: repeat(2, 1fr);
  }
}
</style>
