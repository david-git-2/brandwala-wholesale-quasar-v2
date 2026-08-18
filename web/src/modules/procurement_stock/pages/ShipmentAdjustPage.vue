<template>
  <q-page class="shipment-adjust-page bg-grey-1 column no-wrap" style="height: calc(100vh - 55px); overflow: hidden">
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
            Adjustments & Invoice Matching
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
            :loading="shipmentStore.loading"
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
        <div class="text-grey-6 q-mt-md">Loading adjustment details...</div>
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
        <!-- Discrepancy Status Badges Bar -->
        <div class="row items-center q-gutter-sm q-mb-sm">
          <q-chip
            dense
            square
            size="sm"
            :color="weightNeedsAttention ? 'orange-1' : hasCargoInvoiceWeight ? 'green-1' : 'grey-2'"
            :text-color="weightNeedsAttention ? 'orange-10' : hasCargoInvoiceWeight ? 'green-9' : 'grey-8'"
            icon="ph ph-scales"
          >
            Weight Match: {{ !hasCargoInvoiceWeight ? 'Not set' : weightNeedsAttention ? 'Needs adjustment' : 'Matched' }}
          </q-chip>
          <q-chip
            dense
            square
            size="sm"
            :color="purchaseNeedsAttention ? 'orange-1' : hasProductInvoiceTotal ? 'green-1' : 'grey-2'"
            :text-color="purchaseNeedsAttention ? 'orange-10' : hasProductInvoiceTotal ? 'green-9' : 'grey-8'"
            icon="ph ph-money"
          >
            Purchase Match: {{ !hasProductInvoiceTotal ? 'Not set' : purchaseNeedsAttention ? 'Needs adjustment' : 'Matched' }}
          </q-chip>
        </div>

        <div class="column q-gutter-y-sm">
          <!-- 1. Match Cargo Invoice Weight Card -->
          <div ref="weightBalanceCardEl">
            <ShipmentWeightBalanceCard
              :shipment-id="shipmentId"
              @applied="refreshData"
            />
          </div>

          <!-- 2. Match Paid Purchase Invoice Card -->
          <div ref="purchaseBalanceCardEl">
            <ShipmentPurchaseBalanceCard
              :shipment-id="shipmentId"
              @applied="refreshData"
              @go-landed-cost="goToRatesPage"
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
import ShipmentWeightBalanceCard from '../components/ShipmentWeightBalanceCard.vue';
import ShipmentPurchaseBalanceCard from '../components/ShipmentPurchaseBalanceCard.vue';

// Composables
import { useInboundShipmentCalculations } from '../composables/useInboundShipmentCalculations';
import { useInboundShipmentActions } from '../composables/useInboundShipmentActions';

const route = useRoute();
const router = useRouter();
const shipmentStore = useGlobalShipmentStore();
const shipmentId = Number(route.params.id);

const activeTab = ref<'lines' | 'balance' | 'cost' | 'receive'>('balance');
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
  hasCargoInvoiceWeight,
  hasProductInvoiceTotal,
  weightNeedsAttention,
  purchaseNeedsAttention,
} = calculations;

const {
  loadShipmentDetails,
} = actions;

const refreshData = async () => {
  if (shipmentId && !isNaN(shipmentId)) {
    await loadShipmentDetails();
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

const goToRatesPage = () => {
  const tenantSlug = route.params.tenantSlug;
  if (tenantSlug) {
    void router.push({
      name: 'app-procurement-shipment-rates',
      params: { tenantSlug, id: shipmentId },
    });
  } else {
    void router.push({
      name: 'app-procurement-shipment-rates',
      params: { id: shipmentId },
    });
  }
};

onMounted(async () => {
  await refreshData();
});
</script>

<style scoped>
.shipment-adjust-page .min-width-0 {
  min-width: 0;
}

.border-bottom {
  border-bottom: 1px solid #e2e8f0;
}
</style>
