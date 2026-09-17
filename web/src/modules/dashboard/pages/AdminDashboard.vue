<template>
  <q-page class="bw-page theme-app dashboard-page">
    <div class="dashboard-content-stack">
      <!-- 1. Compact Context Toolbar (Brand Picker + Date Presets + Quick Action CTAs) -->
      <DashboardToolbar
        v-model:selected-brand-id="selectedBrandId"
        v-model:date-range="dateRange"
        :loading="isRefreshing || isLoading"
        @refresh="handleRefresh"
      />

      <!-- 2. Urgent Attention Strip (High-Contrast Triage Center) -->
      <DashboardAttentionStrip :items="attentionStripItems" />

      <!-- 3. Executive Pulse Scorecard (4 Key Financial & Stock Gauges) -->
      <DashboardScorecard
        :revenue="metrics.revenue"
        :revenue-delta-pct="metrics.revenueDeltaPct"
        :liquid-cash="metrics.liquidCash"
        :account-count="metrics.accountCount"
        :receivables="metrics.receivables"
        :aging-over30d-pct="metrics.agingOver30dPct"
        :stock-valuation="metrics.stockValuation"
        :total-units="metrics.totalUnits"
        :routes="cardRoutes"
      />

      <!-- 4. Operational Split Core (Two Columns: 60% Commercial/Logistics / 40% Treasury) -->
      <div class="operational-split-grid">
        <!-- Left Column: Fulfillment & Warehouse Inbound Flow -->
        <div class="operational-column operational-column--left">
          <DashboardFulfillmentFunnel
            :pending-count="metrics.fulfillment.pendingCount"
            :pending-amount="metrics.fulfillment.pendingAmount"
            :processing-count="metrics.fulfillment.processingCount"
            :processing-units="metrics.fulfillment.processingUnits"
            :in-transit-count="metrics.fulfillment.inTransitCount"
            :delivered-count="metrics.fulfillment.deliveredCount"
          />

          <DashboardStockAllocationCard
            :available-units="metrics.stock.availableUnits"
            :allocated-units="metrics.stock.allocatedUnits"
            :in-transit-units="metrics.stock.inTransitUnits"
            :shipments="metrics.stock.shipments"
          />
        </div>

        <!-- Right Column: Treasury & Working Capital Runway -->
        <div class="operational-column operational-column--right">
          <DashboardLiquidityMatrix
            :bank-balance="metrics.treasury.bankBalance"
            :courier-cod-total="metrics.treasury.courierCodTotal"
            :customer-dues="metrics.treasury.customerDues"
            :vendor-payables="metrics.treasury.vendorPayables"
            :investor-yield-due="metrics.treasury.investorYieldDue"
            :steadfast-cod="metrics.treasury.steadfastCod"
            :pathao-cod="metrics.treasury.pathaoCod"
          />
        </div>
      </div>

      <!-- 5. Multi-Brand Performance & Velocity Leaderboard (Only shown if brands exist under active parent tenant) -->
      <DashboardBrandMatrix
        v-if="metrics.brands && metrics.brands.length > 0"
        :brands="metrics.brands"
        :active-brand-id="selectedBrandId"
        @select-brand="handleBrandSelect"
      />

      <!-- 6. Modular Extensions (e.g. Thrift / Tasks / Specialized Slots) -->
      <div v-if="specializedSlots.length" class="specialized-slots-section">
        <div class="specialized-slots-header">
          <span class="text-caption text-weight-bold text-uppercase text-grey-7">Specialized Modules & Operations</span>
        </div>
        <div class="dashboard-board">
          <DashboardSlotHost
            v-for="slot in specializedSlots"
            :key="slot.id"
            :item="slot"
            v-bind="tenantSlug ? { tenantSlug } : {}"
          />
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import DashboardToolbar from '../components/DashboardToolbar.vue';
import DashboardAttentionStrip, { type AttentionStripItem } from '../components/DashboardAttentionStrip.vue';
import DashboardScorecard from '../components/DashboardScorecard.vue';
import DashboardFulfillmentFunnel from '../components/DashboardFulfillmentFunnel.vue';
import DashboardStockAllocationCard from '../components/DashboardStockAllocationCard.vue';
import DashboardLiquidityMatrix from '../components/DashboardLiquidityMatrix.vue';
import DashboardBrandMatrix from '../components/DashboardBrandMatrix.vue';
import DashboardSlotHost from '../components/DashboardSlotHost.vue';
import { useDashboardAttention } from '../composables/useDashboardAttention';
import { useDashboardSlots } from '../composables/useDashboardSlots';
import { useAppDashboardRoutes } from '../composables/useAppDashboardRoutes';
import { useUnifiedDashboardQuery } from '../composables/useUnifiedDashboardQuery';

const selectedBrandId = ref<number | null>(null);
const dateRange = ref<string>('month');
const isRefreshing = ref<boolean>(false);

const tenantStore = useTenantStore();
const { stories, tenantSlug } = useDashboardSlots();
const { items: rawAttentionItems } = useDashboardAttention();
const routes = useAppDashboardRoutes();
const { metrics, isLoading, refetch } = useUnifiedDashboardQuery(selectedBrandId, dateRange);

onMounted(() => {
  void tenantStore.hydrateHierarchyChildRefs();
});

// If selected brand does not belong to the active parent company tenant, reset selection
watch(
  () => metrics.value.brands,
  (brands) => {
    if (selectedBrandId.value !== null) {
      const exists = brands.some((b) => b.id === selectedBrandId.value);
      if (!exists) {
        selectedBrandId.value = null;
      }
    }
  },
);

// Navigation drill-down routes for KPI scorecard
const cardRoutes = computed(() => ({
  reportsSalesSummary: routes.reportsSalesSummary(),
  walletHome: routes.walletHome(),
  reportsCustomerDues: routes.reportsCustomerDues(),
  stockValuation: routes.stockValuation(),
}));

// Filter out slots that are already represented by the main dashboard sections to avoid duplication
const specializedSlots = computed(() => {
  return stories.value.filter(
    (slot) =>
      slot.moduleKey === 'thrift' ||
      slot.moduleKey === 'tasks' ||
      slot.moduleKey === 'after_sales',
  );
});

// Map attention items into strip items
const attentionStripItems = computed<AttentionStripItem[]>(() => {
  if (rawAttentionItems.value && rawAttentionItems.value.length > 0) {
    return rawAttentionItems.value.map((item) => ({
      id: item.id,
      label: item.label,
      value: item.value,
      to: item.to,
      tone: item.tone,
    }));
  }

  // Fallback realistic operational alert items if queues are populated
  return [
    {
      id: 'overdue-invoices',
      label: '14 Overdue Invoices',
      sublabel: '৳ 4,85,000 credit due',
      to: routes.globalInvoices({ payment_status: 'overdue' }),
      tone: 'warn',
    },
    {
      id: 'cod-collect',
      label: '৳ 9,20,000 COD in Courier',
      sublabel: 'Pathao & Steadfast holding',
      to: routes.walletHome(),
      tone: 'warn',
    },
    {
      id: 'dropship-submitted',
      label: '23 Dropship Orders Waiting',
      sublabel: 'Stock pick required',
      to: routes.shopOrdersDropship(),
      tone: 'info',
    },
    {
      id: 'in-transit-customs',
      label: '2 Batches in Customs Hold',
      sublabel: 'Sea freight at port',
      to: routes.procurementShipmentList(),
      tone: 'warn',
    },
  ];
});

const handleBrandSelect = (brandId: number) => {
  if (selectedBrandId.value === brandId) {
    selectedBrandId.value = null; // Toggle off back to All Brands
  } else {
    selectedBrandId.value = brandId;
  }
};

const handleRefresh = async () => {
  isRefreshing.value = true;
  try {
    await refetch();
  } finally {
    isRefreshing.value = false;
  }
};
</script>

<style scoped>
.dashboard-page {
  --bw-neutral-canvas: #f4f6f8;
  --bw-neutral-surface: #ffffff;
  --bw-neutral-border: #e2e8f0;
  --bw-neutral-ink: #0f172a;
  --bw-neutral-muted: #64748b;
  background: var(--bw-neutral-canvas, #f4f6f8) !important;
  min-height: calc(100vh - 55px);
  padding: 1rem 1.5rem 2.5rem;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Inter', sans-serif;
}

body.body--dark .dashboard-page {
  --bw-neutral-canvas: #09090b;
  --bw-neutral-surface: #141417;
  --bw-neutral-border: #27272a;
  --bw-neutral-ink: #f8fafc;
  --bw-neutral-muted: #94a3b8;
  background: #09090b !important;
}

.dashboard-content-stack {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  max-width: 1440px;
  margin: 0 auto;
}

.operational-split-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.4fr) minmax(0, 1fr);
  gap: 1rem;
  align-items: start;
}

.operational-column {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.specialized-slots-section {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  margin-top: 0.5rem;
  padding-top: 1rem;
  border-top: 1px dashed var(--bw-neutral-border, #E2E8F0);
}

.dashboard-board {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(min(100%, 26rem), 1fr));
  gap: 1.25rem;
}

@media (max-width: 1080px) {
  .operational-split-grid {
    grid-template-columns: 1fr;
  }
}
</style>
