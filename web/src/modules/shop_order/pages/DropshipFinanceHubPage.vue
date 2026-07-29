<template>
  <q-page class="bw-page">
    <div class="bw-page__stack">
      <!-- Header -->
      <app-page-header
        title="Dropship Finance Hub"
        subtitle="Manage Courier Remittances, Tenant Treasury Cash, and Merchant Profit Payouts"
        eyebrow="DROPSHIP OPERATIONS"
      />

      <!-- Skeleton Loader -->
      <dropship-finance-hub-skeleton v-if="isLoading" />

      <!-- Main Hub View -->
      <template v-else>
        <!-- 1. KPI Cards -->
        <finance-hub-kpi-strip :kpis="kpis" />

        <!-- 2. Order Queue Table -->
        <finance-hub-order-queue
          :orders="orders"
          v-model:active-step="activeQueueStep"
          @select-order="handleSelectOrder"
        />

        <!-- 3. Active Action Step Panel -->
        <div class="row q-col-gutter-md">
          <div class="col-12">
            <q-tabs
              v-model="activeTab"
              dense
              no-caps
              active-color="primary"
              indicator-color="primary"
              class="bg-white rounded-borders q-px-sm border-grey"
            >
              <q-tab name="delivered_costing" label="1. Delivered Costing" />
              <q-tab name="courier_remittance" label="2. Courier Remittance" />
              <q-tab name="middleman_payout" label="3. Merchant Payout" />
            </q-tabs>
          </div>

          <div class="col-12">
            <q-tab-panels v-model="activeTab" animated class="bg-transparent">
              <q-tab-panel name="delivered_costing" class="q-pa-none">
                <finance-hub-step-delivered
                  :selected-order="selectedOrder"
                  :loading="confirmDeliveredCostingMutation.isPending.value"
                  @submit="handleConfirmDelivered"
                />
              </q-tab-panel>

              <q-tab-panel name="courier_remittance" class="q-pa-none">
                <finance-hub-step-remittance
                  :selected-order="selectedOrder"
                  :loading="confirmCourierRemittanceMutation.isPending.value"
                  @submit="handleConfirmRemittance"
                />
              </q-tab-panel>

              <q-tab-panel name="middleman_payout" class="q-pa-none">
                <finance-hub-step-payout
                  :merchants="merchants"
                  :preselected-merchant-id="preselectedMerchantId"
                  :loading="dispenseMiddlemanPayoutMutation.isPending.value"
                  @submit="handleDispensePayout"
                />
              </q-tab-panel>
            </q-tab-panels>
          </div>
        </div>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useTenantStore } from 'src/modules/tenant/stores/tenantStore';
import { useDropshipFinanceHubQuery } from '../composables/useDropshipFinanceHubQuery';
import { useDropshipFinanceHubMutations } from '../composables/useDropshipFinanceHubMutations';
import type { FinanceHubOrderQueueItem } from '../repositories/dropshipFinanceRepository';

import DropshipFinanceHubSkeleton from '../components/finance_hub/DropshipFinanceHubSkeleton.vue';
import FinanceHubKpiStrip from '../components/finance_hub/FinanceHubKpiStrip.vue';
import FinanceHubOrderQueue from '../components/finance_hub/FinanceHubOrderQueue.vue';
import FinanceHubStepDelivered from '../components/finance_hub/FinanceHubStepDelivered.vue';
import FinanceHubStepRemittance from '../components/finance_hub/FinanceHubStepRemittance.vue';
import FinanceHubStepPayout from '../components/finance_hub/FinanceHubStepPayout.vue';

const route = useRoute();
const tenantStore = useTenantStore();
const currentTenantId = computed(() => tenantStore.selectedTenant?.id ?? null);

const { kpis, orders, merchants, isLoading } = useDropshipFinanceHubQuery(currentTenantId);
const {
  confirmDeliveredCostingMutation,
  confirmCourierRemittanceMutation,
  dispenseMiddlemanPayoutMutation,
} = useDropshipFinanceHubMutations(currentTenantId);

const activeQueueStep = ref<string>('delivered_costing');
const activeTab = ref<string>('delivered_costing');
const selectedOrder = ref<FinanceHubOrderQueueItem | null>(null);
const preselectedMerchantId = ref<number | null>(null);

// Route parameters auto-selection support
onMounted(() => {
  const queryOrderId = route.query.orderId ? Number(route.query.orderId) : null;
  const queryMerchantId = route.query.merchantId ? Number(route.query.merchantId) : null;
  const queryStep = route.query.step ? String(route.query.step) : null;

  if (queryStep) {
    activeTab.value = queryStep;
  }

  if (queryMerchantId) {
    preselectedMerchantId.value = queryMerchantId;
    activeTab.value = 'middleman_payout';
  }

  if (queryOrderId && orders.value.length > 0) {
    const match = orders.value.find((o) => o.id === queryOrderId);
    if (match) {
      handleSelectOrder(match);
    }
  }
});

watch(
  () => orders.value,
  (newOrders) => {
    const queryOrderId = route.query.orderId ? Number(route.query.orderId) : null;
    if (queryOrderId && !selectedOrder.value) {
      const match = newOrders.find((o) => o.id === queryOrderId);
      if (match) {
        handleSelectOrder(match);
      }
    }
  }
);

function handleSelectOrder(order: FinanceHubOrderQueueItem) {
  selectedOrder.value = order;
  if (order.nextStep === 'delivered_costing') {
    activeTab.value = 'delivered_costing';
  } else if (order.nextStep === 'courier_remittance') {
    activeTab.value = 'courier_remittance';
  }
}

async function handleConfirmDelivered(payload: { orderId: number; codAmount: number; deliveryCharge: number; courierNotes?: string }) {
  await confirmDeliveredCostingMutation.mutateAsync(payload);
  if (selectedOrder.value && selectedOrder.value.id === payload.orderId) {
    selectedOrder.value.nextStep = 'courier_remittance';
    activeTab.value = 'courier_remittance';
  }
}

async function handleConfirmRemittance(payload: {
  orderId: number;
  netAmount: number;
  courierCharge: number;
  remittanceRef?: string;
  bankTrxId?: string;
}) {
  await confirmCourierRemittanceMutation.mutateAsync(payload);
  if (selectedOrder.value && selectedOrder.value.id === payload.orderId) {
    selectedOrder.value.nextStep = 'completed';
    selectedOrder.value.status = 'payment_received';
  }
}

async function handleDispensePayout(payload: { billingProfileId: number; amount: number; payoutMethod?: string; referenceNotes?: string }) {
  if (!currentTenantId.value) return;
  await dispenseMiddlemanPayoutMutation.mutateAsync({
    tenantId: currentTenantId.value,
    ...payload,
  });
}
</script>

<style scoped>
.border-grey {
  border: 1px solid var(--bw-theme-border);
}
</style>
