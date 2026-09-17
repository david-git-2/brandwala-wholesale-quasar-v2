<template>
  <div class="stock-card">
    <div class="stock-header">
      <div class="row items-center q-gutter-x-xs">
        <span class="stock-title">Warehouse Stock & Inbound Intake</span>
      </div>
      <router-link :to="routes.procurementShipmentList()" class="stock-view-all">
        Inbound Shipments <q-icon name="ph ph-arrow-right" size="11px" />
      </router-link>
    </div>

    <div class="stock-body">
      <!-- Left side: Clean Proportion Breakdown -->
      <div class="stock-allocation-section">
        <div class="allocation-header">
          <div>
            <span class="text-caption text-slate-400">Total Pooled Stock</span>
            <div class="text-h6 text-weight-bold text-slate-900 bw-tabular">
              {{ formatDashboardCount(totalUnits) }} <span class="text-caption text-weight-regular text-slate-400">pcs</span>
            </div>
          </div>
          <span class="sellable-status-pill">
            {{ availablePct }}% sellable
          </span>
        </div>

        <!-- Sleek Multi-segment Horizontal Progress Bar -->
        <div class="segmented-stock-bar">
          <div
            class="bar-seg bar-seg--avail"
            :style="{ width: `${availablePct}%` }"
            :title="`Available: ${availableUnits}`"
          />
          <div
            class="bar-seg bar-seg--alloc"
            :style="{ width: `${allocatedPct}%` }"
            :title="`Allocated: ${allocatedUnits}`"
          />
          <div
            class="bar-seg bar-seg--transit"
            :style="{ width: `${inTransitPct}%` }"
            :title="`In Transit: ${inTransitUnits}`"
          />
        </div>

        <!-- Clean Metric Legend Rows -->
        <div class="legend-list">
          <div class="legend-row">
            <span class="dot dot--avail" />
            <span class="legend-name">Available for sale</span>
            <span class="legend-val bw-tabular">{{ formatDashboardCount(availableUnits) }}</span>
          </div>
          <div class="legend-row">
            <span class="dot dot--alloc" />
            <span class="legend-name">Reserved in orders</span>
            <span class="legend-val bw-tabular">{{ formatDashboardCount(allocatedUnits) }}</span>
          </div>
          <div class="legend-row">
            <span class="dot dot--transit" />
            <span class="legend-name">Inbound in transit</span>
            <span class="legend-val bw-tabular">{{ formatDashboardCount(inTransitUnits) }}</span>
          </div>
        </div>
      </div>

      <!-- Right side: Active Inbound Consignments List -->
      <div class="shipments-section">
        <div class="shipments-title">Active Consignments</div>
        <div v-if="!shipments || !shipments.length" class="text-caption text-slate-400">
          No inbound shipments in transit.
        </div>
        <div v-else class="shipments-list">
          <div
            v-for="shipment in shipments"
            :key="shipment.id"
            class="shipment-item"
            @click="navigateTo(routes.procurementShipmentDetails(shipment.id))"
          >
            <div class="shipment-item__left">
              <q-icon
                :name="shipment.transportType === 'air' ? 'ph ph-airplane-tilt' : 'ph ph-boat'"
                size="15px"
                class="text-slate-400 q-mr-xs"
              />
              <div>
                <div class="shipment-name">{{ shipment.batchNo }}</div>
                <div class="shipment-sub text-slate-400">{{ shipment.origin }} · {{ formatDashboardCount(shipment.totalUnits) }} pcs</div>
              </div>
            </div>
            <span class="status-badge" :class="`status-badge--${shipment.statusKey || 'transit'}`">
              {{ shipment.statusLabel }}
            </span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRouter, type RouteLocationRaw } from 'vue-router';
import { formatDashboardCount } from '../utils/formatDashboardMetric';
import { useAppDashboardRoutes } from '../composables/useAppDashboardRoutes';

export type InboundShipmentItem = {
  id: string | number;
  batchNo: string;
  transportType: 'sea' | 'air';
  origin: string;
  totalUnits: number;
  statusLabel: string;
  statusKey?: string;
};

const props = withDefaults(
  defineProps<{
    availableUnits?: number;
    allocatedUnits?: number;
    inTransitUnits?: number;
    shipments?: InboundShipmentItem[];
  }>(),
  {
    availableUnits: 11400,
    allocatedUnits: 4800,
    inTransitUnits: 2250,
    shipments: () => [
      {
        id: 1,
        batchNo: 'Batch #CN-2026-09',
        transportType: 'sea',
        origin: 'Guangzhou, CN',
        totalUnits: 1800,
        statusLabel: 'Customs Hold',
        statusKey: 'warn',
      },
      {
        id: 2,
        batchNo: 'Batch #UK-2026-03',
        transportType: 'air',
        origin: 'Heathrow, UK',
        totalUnits: 450,
        statusLabel: 'Clearing Dhaka',
        statusKey: 'info',
      },
    ],
  },
);

const router = useRouter();
const routes = useAppDashboardRoutes();

const totalUnits = computed(
  () => props.availableUnits + props.allocatedUnits + props.inTransitUnits,
);

const availablePct = computed(() => {
  if (totalUnits.value <= 0) return 0;
  return Math.round((props.availableUnits / totalUnits.value) * 100);
});

const allocatedPct = computed(() => {
  if (totalUnits.value <= 0) return 0;
  return Math.round((props.allocatedUnits / totalUnits.value) * 100);
});

const inTransitPct = computed(() => {
  if (totalUnits.value <= 0) return 0;
  return Math.max(0, 100 - availablePct.value - allocatedPct.value);
});

const navigateTo = (to: RouteLocationRaw) => {
  void router.push(to);
};
</script>

<style scoped>
.stock-card {
  background: var(--bw-neutral-surface, #FFFFFF);
  border: 1px solid var(--bw-neutral-border, #E2E8F0);
  border-radius: 10px;
  padding: 1rem 1.15rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.04);
}

body.body--dark .stock-card {
  background: #18181B;
  border-color: #27272A;
}

.stock-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.85rem;
}

.stock-title {
  font-size: 13.5px;
  font-weight: 600;
  color: #0F172A;
  letter-spacing: -0.01em;
}

body.body--dark .stock-title {
  color: #F4F4F5;
}

.stock-view-all {
  font-size: 11.5px;
  font-weight: 500;
  color: #64748B;
  text-decoration: none;
  display: flex;
  align-items: center;
  gap: 3px;
  transition: color 0.15s ease;
}

.stock-view-all:hover {
  color: var(--bw-brand-accent, #0d6b5c);
}

body.body--dark .stock-view-all:hover {
  color: var(--bw-brand-accent, #4db8a4);
}

.stock-body {
  display: grid;
  grid-template-columns: 1.1fr 1.2fr;
  gap: 1.5rem;
  align-items: start;
}

.stock-allocation-section {
  display: flex;
  flex-direction: column;
  gap: 0.6rem;
}

.allocation-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.sellable-status-pill {
  font-size: 11px;
  font-weight: 600;
  padding: 2px 8px;
  border-radius: 999px;
  background: #F0FDF4;
  border: 1px solid #BBF7D0;
  color: #16A34A;
}

body.body--dark .sellable-status-pill {
  background: rgba(22, 163, 74, 0.15);
  border-color: rgba(22, 163, 74, 0.3);
  color: #86EFAC;
}

.segmented-stock-bar {
  height: 6px;
  border-radius: 3px;
  background: #F1F5F9;
  overflow: hidden;
  display: flex;
}

.bar-seg {
  height: 100%;
}

.bar-seg--avail { background: #10B981; }
.bar-seg--alloc { background: #F59E0B; }
.bar-seg--transit { background: #3B82F6; }

.legend-list {
  display: flex;
  flex-direction: column;
  gap: 5px;
  margin-top: 0.25rem;
}

.legend-row {
  display: flex;
  align-items: center;
  font-size: 12px;
}

.dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  margin-right: 8px;
  flex-shrink: 0;
}

.dot--avail { background: #10B981; }
.dot--alloc { background: #F59E0B; }
.dot--transit { background: #3B82F6; }

.legend-name {
  color: #64748B;
}

.legend-val {
  margin-left: auto;
  font-weight: 600;
  color: #0F172A;
}

.shipments-section {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}

.shipments-title {
  font-size: 12px;
  font-weight: 600;
  color: #475569;
}

.shipments-list {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}

.shipment-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.4rem 0.5rem;
  border-radius: 6px;
  background: #F8FAFC;
  cursor: pointer;
  transition: all 0.15s ease;
}

.shipment-item:hover {
  background: #F1F5F9;
}

.shipment-item__left {
  display: flex;
  align-items: center;
}

.shipment-name {
  font-size: 12px;
  font-weight: 600;
  color: #0F172A;
}

.shipment-sub {
  font-size: 11px;
}

.status-badge {
  font-size: 10px;
  font-weight: 600;
  padding: 2px 7px;
  border-radius: 4px;
  border: 1px solid transparent;
}

.status-badge--warn {
  background: #FFFBEB;
  border-color: #FDE68A;
  color: #B45309;
}

.status-badge--info {
  background: #EFF6FF;
  border-color: #BFDBFE;
  color: #2563EB;
}

.status-badge--received,
.status-badge--success {
  background: #F0FDF4;
  border-color: #BBF7D0;
  color: #16A34A;
}

body.body--dark .status-badge--warn {
  background: rgba(217, 119, 6, 0.15);
  border-color: rgba(217, 119, 6, 0.3);
  color: #FCD34D;
}

body.body--dark .status-badge--info {
  background: rgba(37, 99, 235, 0.15);
  border-color: rgba(37, 99, 235, 0.3);
  color: #93C5FD;
}

body.body--dark .status-badge--received,
body.body--dark .status-badge--success {
  background: rgba(22, 163, 74, 0.15);
  border-color: rgba(22, 163, 74, 0.3);
  color: #86EFAC;
}

.text-slate-400 { color: #94A3B8; }
.text-slate-900 { color: #0F172A; }

body.body--dark .shipments-title {
  color: #A1A1AA;
}

body.body--dark .shipment-item {
  background: #27272A;
  border: 1px solid #3F3F46;
}

body.body--dark .shipment-item:hover {
  background: #3F3F46;
}

body.body--dark .shipment-name {
  color: #F4F4F5;
}

body.body--dark .legend-name {
  color: #A1A1AA;
}

body.body--dark .legend-val {
  color: #F4F4F5;
}

body.body--dark .text-slate-900 {
  color: #F4F4F5 !important;
}

body.body--dark .segmented-stock-bar {
  background: #27272A;
}

@media (max-width: 800px) {
  .stock-body {
    grid-template-columns: 1fr;
  }
}
</style>
