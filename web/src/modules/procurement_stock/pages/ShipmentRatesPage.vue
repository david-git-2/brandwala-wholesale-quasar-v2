<template>
  <q-page class="shipment-rates-page bg-grey-1 column no-wrap" style="height: calc(100vh - 55px); overflow: hidden">
    <!-- Header Bar -->
    <div class="bg-white border-bottom q-px-md q-py-sm shadow-1">
      <div class="row items-center justify-between no-wrap">
        <div class="row items-center q-gutter-sm">
          <q-btn
            icon="ph ph-arrow-left"
            flat
            round
            dense
            color="grey-8"
            @click="goBackToShipment"
          >
            <q-tooltip>Back to shipment</q-tooltip>
          </q-btn>
          <div class="text-subtitle1 text-weight-bold text-grey-9">
            Rates & Cost Entries
          </div>
        </div>

        <!-- Right Actions -->
        <div class="row items-center q-gutter-xs">
          <q-btn
            flat
            dense
            round
            color="grey-7"
            icon="ph ph-arrow-clockwise"
            :loading="shipmentStore.loading || shipmentStore.costEntriesLoading"
            @click="refreshData"
          >
            <q-tooltip>Refresh</q-tooltip>
          </q-btn>
        </div>
      </div>
    </div>

    <!-- Main Content -->
    <div class="col scroll q-pa-sm">
      <!-- Loading State -->
      <div v-if="shipmentStore.loading && !shipmentStore.currentShipment" class="text-center q-pa-xl">
        <q-spinner color="primary" size="3em" />
        <div class="text-grey-6 q-mt-md">Loading rates configuration...</div>
      </div>

      <!-- Error State -->
      <div v-else-if="shipmentStore.error && !shipmentStore.currentShipment" class="q-pa-md">
        <q-banner class="bg-negative text-white rounded-borders">
          {{ shipmentStore.error }}
          <template #action>
            <q-btn flat color="white" label="Back to Overview" @click="goBackToShipment" />
          </template>
        </q-banner>
      </div>

      <template v-else>
        <!-- Attention Banner if discrepancy exists -->
        <q-banner
          v-if="weightNeedsAttention || purchaseNeedsAttention"
          dense
          rounded
          class="bg-orange-1 text-orange-10 q-mb-sm"
        >
          <div class="row items-center justify-between q-gutter-sm">
            <span>Lines don’t match invoices — balance or adjust to reconcile.</span>
            <q-btn
              flat
              dense
              no-caps
              color="orange-10"
              label="Go to Adjust / Invoices"
              @click="goToAdjustPage"
            />
          </div>
        </q-banner>

        <div class="row q-col-gutter-sm items-start">
          <!-- Cost Entries Configuration Panel -->
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
              @go-match-invoices="goToAdjustPage"
            />
          </div>

          <!-- Landed Cost Summary Sidebar -->
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
              :is-cost-finalized="isCostFinalized"
            />
          </div>
        </div>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';

// Components
import ShipmentCostEntriesPanel from '../components/ShipmentCostEntriesPanel.vue';
import ShipmentLandedCostSummaryCard from '../components/ShipmentLandedCostSummaryCard.vue';

// Composables
import { useInboundShipmentCalculations } from '../composables/useInboundShipmentCalculations';
import { useInboundShipmentActions } from '../composables/useInboundShipmentActions';

const route = useRoute();
const router = useRouter();
const shipmentStore = useGlobalShipmentStore();
const shipmentId = Number(route.params.id);

const activeTab = ref<'lines' | 'balance' | 'cost' | 'receive'>('cost');
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

const {
  totals,
  cargoCostWeightLabel,
  transactionRateWeightLabel,
  currentShipmentBoxesTotal,
  hasCargoInvoiceWeight,
  isCostFinalized,
  canEditCosts,
  weightNeedsAttention,
  purchaseNeedsAttention,
  currentPurchaseCurrencySymbol,
  currentCostCurrencySymbol,
} = calculations;

const {
  loadShipmentDetails,
  onSaveCostEntries,
  paySettling,
  confirmSettlePayee,
} = actions;

const refreshData = async () => {
  if (shipmentId && !isNaN(shipmentId)) {
    await loadShipmentDetails();
    await shipmentStore.fetchCostEntries(shipmentId);
  }
};

const goBackToShipment = () => {
  const tenantSlug = route.params.tenantSlug;
  if (tenantSlug) {
    void router.push({
      name: 'app-procurement-shipment-details',
      params: { tenantSlug, id: shipmentId },
    });
  } else {
    void router.push({
      name: 'app-procurement-shipment-details',
      params: { id: shipmentId },
    });
  }
};

const goToAdjustPage = () => {
  const tenantSlug = route.params.tenantSlug;
  if (tenantSlug) {
    void router.push({
      name: 'app-procurement-shipment-rates-invoices',
      params: { tenantSlug, id: shipmentId },
    });
  } else {
    void router.push({
      name: 'app-procurement-shipment-rates-invoices',
      params: { id: shipmentId },
    });
  }
};

onMounted(async () => {
  await refreshData();
});
</script>

<style scoped>
.shipment-rates-page .min-width-0 {
  min-width: 0;
}

.border-bottom {
  border-bottom: 1px solid #e2e8f0;
}
</style>
