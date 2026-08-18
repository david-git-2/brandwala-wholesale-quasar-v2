<template>
  <q-page class="shipment-settle-page bg-grey-1 column no-wrap" style="height: calc(100vh - 55px); overflow: hidden">
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
            Payee Settlement & Store Credit
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
        <div class="text-grey-6 q-mt-md">Loading settlement details...</div>
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
        <!-- Notice if not received yet -->
        <q-banner
          v-if="shipmentStore.currentShipment?.status !== 'received'"
          dense
          rounded
          class="bg-blue-1 text-blue-10 q-mb-sm"
        >
          <div class="row items-center justify-between q-gutter-sm">
            <span>
              Shipment is currently <strong>{{ shipmentStore.currentShipment?.status || 'in progress' }}</strong>.
              Settlement and credit applications become fully active once the shipment is marked as <strong>Received</strong>.
            </span>
          </div>
        </q-banner>

        <!-- Settlement Panel Component -->
        <ShipmentPayeeSettlePanel
          :shipment-id="shipmentId"
          :status="shipmentStore.currentShipment?.status || 'draft'"
          :vendor-id="shipmentStore.currentShipment?.vendor_id"
          :cargo-company-id="shipmentStore.currentShipment?.cargo_company_id"
          :vendor-name="currentVendorLabel"
          :cargo-company-name="currentCargoLabel"
          :vendor-rate="totals.exchangeRate"
          :cargo-rate="totals.cargoRate"
          :purchase-currency-symbol="currentPurchaseCurrencySymbol"
          :submitting="paySettling"
          :vendor-product-total="totals.goodsPurchase"
          :cargo-cost-total="totals.cargoCost"
          :goods-purchase-total="totals.goodsPurchase"
          @settle="confirmSettlePayee"
        />
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useGlobalShipmentStore } from '../stores/globalShipmentStore';

// Components
import ShipmentPayeeSettlePanel from '../components/ShipmentPayeeSettlePanel.vue';

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
  currentPurchaseCurrencySymbol,
} = calculations;

const {
  currentVendorLabel,
  currentCargoLabel,
  loadShipmentDetails,
  paySettling,
  confirmSettlePayee,
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

onMounted(async () => {
  await refreshData();
});
</script>

<style scoped>
.shipment-settle-page .min-width-0 {
  min-width: 0;
}

.border-bottom {
  border-bottom: 1px solid #e2e8f0;
}
</style>
