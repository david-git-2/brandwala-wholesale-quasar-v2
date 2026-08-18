<template>
  <q-page class="shipment-rates-invoices-page bg-grey-1 column no-wrap" style="height: calc(100vh - 55px); overflow: hidden">
    <!-- Header Bar: Name, Type, Vendor, Cargo -->
    <div class="bg-white border-bottom q-px-md q-py-sm shadow-1">
      <div class="row items-center justify-between wrap q-gutter-y-xs">
        <!-- Left: Back button, Name, and Type / Vendor / Cargo Chips -->
        <div class="row items-center q-gutter-sm min-width-0 col-12 col-md-auto">
          <q-btn
            icon="ph ph-arrow-left"
            flat
            round
            dense
            color="grey-8"
            @click="goBackToShipmentList"
          >
            <q-tooltip>Back to shipments list</q-tooltip>
          </q-btn>

          <div class="min-width-0">
            <div class="row items-center q-gutter-xs no-wrap">
              <span class="text-caption text-weight-bold text-grey-7">
                #{{ (shipmentStore.currentShipment as any)?.tenant_shipment_id || shipmentStore.currentShipment?.id || shipmentId }}
              </span>
              <span class="text-subtitle1 text-weight-bold text-grey-9 ellipsis">
                {{ shipmentStore.currentShipment?.name || 'Shipment' }}
              </span>
            </div>

            <!-- Chips Row: Type, Vendor, Cargo -->
            <div class="row items-center q-gutter-xs q-mt-xs wrap">
              <!-- Shipment Type Chip -->
              <q-chip
                outline
                dense
                square
                size="sm"
                color="primary"
                class="text-capitalize"
              >
                <q-icon name="ph ph-globe" size="12px" class="q-mr-xs" />
                {{ shipmentStore.currentShipment?.type || 'international' }}
              </q-chip>

              <!-- Vendor Chip -->
              <q-chip
                v-if="currentVendorLabel"
                outline
                dense
                square
                size="sm"
                color="teal-8"
              >
                <q-icon name="ph ph-storefront" size="12px" class="q-mr-xs" />
                {{ currentVendorLabel }}
              </q-chip>

              <!-- Cargo Chip -->
              <q-chip
                v-if="currentCargoLabel && shipmentStore.currentShipment?.type !== 'local'"
                outline
                dense
                square
                size="sm"
                color="indigo-8"
              >
                <q-icon name="ph ph-airplane-tilt" size="12px" class="q-mr-xs" />
                {{ currentCargoLabel }}
              </q-chip>
            </div>
          </div>
        </div>

        <!-- Right: Refresh & Actions -->
        <div class="row items-center q-gutter-xs col-12 col-md-auto justify-end">
          <q-btn
            flat
            dense
            round
            color="grey-7"
            icon="ph ph-arrow-clockwise"
            :loading="shipmentStore.loading"
            @click="refreshData"
          >
            <q-tooltip>Refresh</q-tooltip>
          </q-btn>
        </div>
      </div>
    </div>

    <!-- Main Scrollable Content -->
    <div class="col scroll q-pa-md">
      <!-- Loading State -->
      <div v-if="shipmentStore.loading && !shipmentStore.currentShipment" class="text-center q-pa-xl">
        <q-spinner color="primary" size="3em" />
        <div class="text-grey-6 q-mt-md">Loading shipment details...</div>
      </div>

      <!-- Error State -->
      <div v-else-if="shipmentStore.error && !shipmentStore.currentShipment" class="q-pa-md">
        <q-banner class="bg-negative text-white rounded-borders">
          {{ shipmentStore.error }}
          <template #action>
            <q-btn flat color="white" label="Back to List" @click="goBackToShipmentList" />
          </template>
        </q-banner>
      </div>

      <template v-else-if="shipmentStore.currentShipment">
        <!-- Status Workflow Bar -->
        <ShipmentStatusWorkflowBar
          :status="shipmentStore.currentShipment.status"
          :updating="updatingStatus"
          :target-status="targetUpdatingStatus"
          :flow-options="progressFlowOptions"
          :progress-flow-id="shipmentStore.currentShipment.progress_flow_id ?? null"
          :progress-options="shipmentStore.progressTags"
          :progress-tag-id="shipmentStore.currentShipment.progress_tag_id ?? shipmentStore.currentShipment.progress_tag?.id ?? null"
          :progress-updating="shipmentStore.progressUpdating"
          :progress-target-id="progressTargetId"
          :show-next="!!nextStep"
          class="q-mb-md"
          @update-status="changeStatus"
          @update-flow="changeFlow"
          @update-progress="changeProgress"
        >
          <template #next>
            <div
              v-if="nextStep"
              class="row items-center justify-between q-gutter-xs wrap full-width"
            >
              <div class="col row items-center q-gutter-xs no-wrap min-width-0">
                <q-icon name="ph ph-arrow-right" color="primary" size="16px" />
                <div class="min-width-0">
                  <div class="text-caption text-weight-medium text-grey-9">{{ nextStep.message }}</div>
                  <div
                    v-if="nextStep.disabled && nextStep.reason"
                    class="text-caption text-grey-7"
                  >
                    {{ nextStep.reason }}
                  </div>
                </div>
              </div>
              <div class="col-auto row items-center q-gutter-xs wrap">
                <q-btn
                  v-if="nextStep.label"
                  color="primary"
                  unelevated
                  dense
                  no-caps
                  size="sm"
                  style="border-radius: 8px"
                  class="q-px-sm"
                  :label="nextStep.label"
                  :disable="nextStep.disabled"
                  @click="runPrimaryCta"
                />
              </div>
            </div>
          </template>
        </ShipmentStatusWorkflowBar>

        <!-- Summary Metrics Cards Grid -->
        <div class="row q-col-gutter-sm q-mb-md">
          <!-- Total Goods Purchase -->
          <div class="col-12 col-sm-6 col-md-3">
            <q-card flat bordered class="bg-white q-pa-sm summary-kpi-card">
              <div class="text-caption text-grey-7 row items-center justify-between">
                <span>Goods Purchase Total</span>
                <q-icon name="ph ph-receipt" size="16px" color="primary" />
              </div>
              <div class="text-h6 text-weight-bolder text-grey-9 q-mt-xs">
                {{ currentPurchaseCurrencySymbol }}{{ (totals.goodsPurchase || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}
              </div>
              <div class="text-caption text-grey-6 q-mt-xs">
                {{ totals.quantity || 0 }} units across {{ shipmentStore.currentShipmentItems?.length || 0 }} lines
              </div>
            </q-card>
          </div>

          <!-- Total Landed Cost -->
          <div class="col-12 col-sm-6 col-md-3">
            <q-card flat bordered class="bg-white q-pa-sm summary-kpi-card">
              <div class="text-caption text-grey-7 row items-center justify-between">
                <span>Total Landed Cost</span>
                <q-icon name="ph ph-coins" size="16px" color="positive" />
              </div>
              <div class="text-h6 text-weight-bolder text-positive q-mt-xs">
                {{ currentCostCurrencySymbol }}{{ (totals.totalCost || 0).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}
              </div>
              <div class="text-caption text-grey-6 q-mt-xs">
                Avg: {{ currentCostCurrencySymbol }}{{ totals.quantity ? ((totals.totalCost || 0) / totals.quantity).toFixed(2) : '0.00' }} / unit
              </div>
            </q-card>
          </div>

          <!-- Cargo Weight vs Line Weight -->
          <div class="col-12 col-sm-6 col-md-3">
            <q-card flat bordered class="bg-white q-pa-sm summary-kpi-card">
              <div class="text-caption text-grey-7 row items-center justify-between">
                <span>Cargo Weight</span>
                <q-icon name="ph ph-scales" size="16px" color="indigo-8" />
              </div>
              <div class="text-h6 text-weight-bolder text-grey-9 q-mt-xs">
                {{ (totals.cargoWeightKg || 0).toFixed(2) }} kg
              </div>
              <div class="text-caption text-grey-6 q-mt-xs">
                Pkg: {{ (totals.packagingWeightKg || 0).toFixed(2) }} kg
              </div>
            </q-card>
          </div>

          <!-- Cost Allocation Status -->
          <div class="col-12 col-sm-6 col-md-3">
            <q-card flat bordered class="bg-white q-pa-sm summary-kpi-card">
              <div class="text-caption text-grey-7 row items-center justify-between">
                <span>Cost Status</span>
                <q-icon name="ph ph-check-circle" size="16px" :color="isCostFinalized ? 'positive' : 'orange'" />
              </div>
              <div class="text-h6 text-weight-bolder q-mt-xs" :class="isCostFinalized ? 'text-positive' : 'text-orange-9'">
                {{ isCostFinalized ? 'Finalized' : 'Draft / Live' }}
              </div>
              <div class="text-caption text-grey-6 q-mt-xs">
                {{ shipmentStore.currentCostEntries.length }} cost entries recorded
              </div>
            </q-card>
          </div>
        </div>

        <!-- Section Navigation Shortcuts -->
        <div class="row items-center q-gutter-xs q-mb-md">
          <q-btn
            flat
            dense
            no-caps
            size="sm"
            color="primary"
            icon="ph ph-receipt"
            label="Rates & Cost Entries"
            @click="scrollToSection('rates')"
          />
          <span class="text-grey-5">·</span>
          <q-btn
            flat
            dense
            no-caps
            size="sm"
            color="primary"
            icon="ph ph-scales"
            label="Match Weight"
            @click="scrollToSection('weight')"
          />
          <span class="text-grey-5">·</span>
          <q-btn
            flat
            dense
            no-caps
            size="sm"
            color="primary"
            icon="ph ph-money"
            label="Match Purchase"
            @click="scrollToSection('purchase')"
          />
        </div>

        <!-- Cards List: Rates & Match Invoices -->
        <div class="column q-gutter-y-md">
          <!-- Card Section 1: Rates & Cost Entries Panel + Landed Cost Summary Card -->
          <div ref="ratesSectionEl" class="row q-col-gutter-md items-start">
            <div ref="paySettleCard" class="col-12 col-md-7 col-lg-8">
              <ShipmentCostEntriesPanel
                :entries="shipmentStore.currentCostEntries"
                :loading="shipmentStore.costEntriesLoading"
                :saving="shipmentStore.costEntriesSaving"
                :can-edit="canEditCosts"
                :is-finalized="isCostFinalized"
                :is-local-shipment="shipmentStore.currentShipment?.type === 'local'"
                :cargo-kg="totals.cargoWeightKg"
                :purchase-currency-symbol="currentPurchaseCurrencySymbol"
                :cost-currency-symbol="currentCostCurrencySymbol"
                :goods-purchase-total="totals.goodsPurchase"
                :goods-quantity-total="totals.quantity"
                :pay-settling="paySettling"
                @save="onSaveCostEntries"
                @settle="confirmSettlePayee"
                @go-match-invoices="scrollToSection('weight')"
              />
            </div>
            <div class="col-12 col-md-5 col-lg-4">
              <ShipmentLandedCostSummaryCard
                :totals="totals"
                :has-cargo-invoice-weight="hasCargoInvoiceWeight"
                :current-shipment-boxes-total="currentShipmentBoxesTotal"
                :current-purchase-currency-symbol="currentPurchaseCurrencySymbol"
                :current-cost-currency-symbol="currentCostCurrencySymbol"
                :cargo-cost-weight-label="cargoCostWeightLabel"
                :transaction-rate-weight-label="transactionRateWeightLabel"
                :shipment-type="shipmentStore.currentShipment?.type"
              />
            </div>
          </div>

          <!-- Card Section 2: Match Invoices (Weight & Purchase Balance) -->
          <div class="column q-gutter-y-md">
            <!-- Weight Balance Card -->
            <div ref="weightBalanceCardEl">
              <ShipmentWeightBalanceCard
                :shipment-id="shipmentId"
                @applied="loadShipmentDetails"
              />
            </div>

            <!-- Purchase Balance Card -->
            <div ref="purchaseBalanceCardEl">
              <ShipmentPurchaseBalanceCard
                :shipment-id="shipmentId"
                @applied="loadShipmentDetails"
                @go-landed-cost="scrollToSection('rates')"
              />
            </div>
          </div>
        </div>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';

// Components
import ShipmentStatusWorkflowBar from '../components/ShipmentStatusWorkflowBar.vue';
import ShipmentCostEntriesPanel from '../components/ShipmentCostEntriesPanel.vue';
import ShipmentLandedCostSummaryCard from '../components/ShipmentLandedCostSummaryCard.vue';
import ShipmentWeightBalanceCard from '../components/ShipmentWeightBalanceCard.vue';
import ShipmentPurchaseBalanceCard from '../components/ShipmentPurchaseBalanceCard.vue';

import { useInboundShipmentCalculations } from '../composables/useInboundShipmentCalculations';
import { useInboundShipmentActions } from '../composables/useInboundShipmentActions';
import { usePageBreadcrumbs } from 'src/composables/useBreadcrumbs';
import { showSuccessNotification, showErrorNotification } from 'src/utils/appFeedback';

const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();
const shipmentStore = useGlobalShipmentStore();
const shipmentId = Number(route.params.id);

const tenantSlug = computed(
  () => (route.params.tenantSlug as string) || authStore.selectedTenant?.slug || '',
);

usePageBreadcrumbs(() => [
  {
    label: authStore.selectedTenant?.name || 'Workspace',
    to: tenantSlug.value ? `/${tenantSlug.value}/app/dashboard` : '/app/dashboard',
    icon: 'ph ph-buildings',
  },
  {
    label: 'Inbound Shipments',
    to: tenantSlug.value
      ? `/${tenantSlug.value}/app/procurement/inbound`
      : '/app/procurement/inbound',
    icon: 'ph ph-truck',
  },
  {
    label: `#${(shipmentStore.currentShipment as any)?.tenant_shipment_id || shipmentStore.currentShipment?.id || shipmentId} ${shipmentStore.currentShipment?.name || ''}`.trim(),
    badge: shipmentStore.currentShipment?.status
      ? {
          label: shipmentStore.currentShipment.status.replace(/_/g, ' '),
          color:
            shipmentStore.currentShipment.status === 'received'
              ? 'positive'
              : shipmentStore.currentShipment.status === 'in_transit'
                ? 'orange-8'
                : 'primary',
        }
      : undefined,
  },
]);

const activeTab = ref<'lines' | 'balance' | 'cost' | 'receive'>('cost');
const ratesSectionEl = ref<HTMLElement | null>(null);
const weightBalanceCardEl = ref<HTMLElement | null>(null);
const purchaseBalanceCardEl = ref<HTMLElement | null>(null);
const assignShopCard = ref<HTMLElement | null>(null);
const paySettleCard = ref<HTMLElement | null>(null);

// Initialize Composables
const calculations = useInboundShipmentCalculations();
const actions = useInboundShipmentActions({
  shipmentId,
  activeTab,
  calculations,
  assignShopCard,
  paySettleCard,
});

// Destructure from Calculations
const {
  totals,
  cargoCostWeightLabel,
  transactionRateWeightLabel,
  currentShipmentBoxesTotal,
  hasCargoInvoiceWeight,
  isCostFinalized,
  canEditCosts,
  currentPurchaseCurrencySymbol,
  currentCostCurrencySymbol,
} = calculations;

// Destructure from Actions
const {
  updatingStatus,
  targetUpdatingStatus,
  progressTargetId,
  currentVendorLabel,
  currentCargoLabel,
  loadShipmentDetails,
  ensureVendorsLoaded,
  ensureCargoLoaded,
  changeStatus,
  changeProgress,
  nextStep,
  runPrimaryCta,
  onSaveCostEntries,
  confirmSettlePayee,
  paySettling,
} = actions;

const progressFlowOptions = computed(() =>
  shipmentStore.progressFlows.filter((flow) => flow.is_active !== false),
);

const goBackToShipmentList = () => {
  const tenantSlug = route.params.tenantSlug;
  if (tenantSlug) {
    void router.push({
      name: 'app-procurement-shipment-list',
      params: { tenantSlug },
    });
  } else {
    void router.push({
      name: 'app-procurement-shipment-list',
    });
  }
};

const changeFlow = async (flowId: number) => {
  if (!shipmentStore.currentShipment || shipmentStore.currentShipment.progress_flow_id === flowId) return;
  try {
    await shipmentStore.setShipmentFlow(shipmentStore.currentShipment.id, flowId);
    showSuccessNotification('Shipment flow updated');
  } catch (err) {
    showErrorNotification(err instanceof Error ? err.message : 'Failed to update shipment flow');
  }
};

const refreshData = async () => {
  await shipmentStore.fetchShipmentDetails(shipmentId);
  await shipmentStore.fetchCostEntries(shipmentId);
};

const scrollToSection = (section: 'rates' | 'weight' | 'purchase') => {
  const map = {
    rates: ratesSectionEl.value,
    weight: weightBalanceCardEl.value,
    purchase: purchaseBalanceCardEl.value,
  };
  map[section]?.scrollIntoView({ behavior: 'smooth', block: 'start' });
};

onMounted(async () => {
  await shipmentStore.fetchShipmentDetails(shipmentId);
  await shipmentStore.fetchCostEntries(shipmentId);
  if (!authStore.tenantId) return;
  void ensureVendorsLoaded();
  void ensureCargoLoaded();
  await shipmentStore.loadProgressFlows(authStore.tenantId, true);
  const flowId =
    shipmentStore.currentShipment?.progress_flow_id ??
    shipmentStore.progressFlows.find((flow) => flow.is_default)?.id ??
    null;
  if (flowId) {
    await shipmentStore.loadProgressFlowStages(flowId, false);
    shipmentStore.progressTags = (shipmentStore.progressStagesByFlow[flowId] ?? []).map((stage) => ({
      id: stage.tag_id,
      name: stage.name,
      slug: stage.slug,
      group_name: 'shipment_progress',
      sort_order: stage.sort_order,
      color: stage.color,
      is_active: stage.is_active,
    }));
  }
});
</script>

<style scoped>
.shipment-rates-invoices-page .min-width-0 {
  min-width: 0;
}

.summary-kpi-card {
  border-radius: 8px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
}

.border-orange {
  border: 1px solid #ffb74d;
}
</style>
