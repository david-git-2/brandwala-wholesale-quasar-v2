<template>
  <q-page class="q-pa-sm page-fixed-layout column no-wrap overflow-hidden">
    <div class="row items-center q-pb-sm shrink-0">
      <q-btn flat dense no-caps icon="ph ph-arrow-left" label="Payments" @click="goBack" />
    </div>
    <div class="col overflow-auto">
      <div class="pay-form-card q-pa-md q-gutter-y-md">
        <div class="text-subtitle1 text-weight-bold">Courier remittance</div>
        <p class="text-caption text-grey-7 q-ma-none">
          Net bank in only — not COD face. Allocates to the merchant bill on the order.
        </p>

        <div v-if="loading" class="text-grey-7">Loading queue…</div>
        <q-list v-else bordered separator class="rounded-borders">
          <q-item
            v-for="order in remitOrders"
            :key="order.id"
            clickable
            :active="selectedOrderId === order.id"
            @click="selectOrder(order)"
          >
            <q-item-section>
              <q-item-label>{{ order.orderNo }}</q-item-label>
              <q-item-label caption>
                {{ order.shopName || order.customerName }} · COD {{ formatAmountBdt(order.codCollectAmount) }}
              </q-item-label>
            </q-item-section>
          </q-item>
        </q-list>

        <template v-if="selectedOrder">
          <q-banner dense rounded class="bg-blue-1 text-blue-9">
            Bill due (read-only): {{ formatAmountBdt(selectedOrder.invoiceOutstanding ?? 0) }}
          </q-banner>
          <q-input v-model.number="netAmount" outlined dense label="Net bank in" type="number" />
          <q-input v-model.number="courierCharge" outlined dense label="Courier charge" type="number" />
          <q-input v-model="remittanceRef" outlined dense label="Remittance ref" />
          <q-input v-model="bankTrxId" outlined dense label="Bank trx ID" />
          <q-input v-model="paymentDate" outlined dense label="Payment date" type="date" />
          <q-btn
            unelevated
            color="primary"
            no-caps
            label="Post remittance"
            :loading="submitting"
            :disable="!(netAmount > 0)"
            @click="submit"
          />
        </template>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { formatAmountBdt } from 'src/utils/currency';
import { dropshipFinanceRepository, type FinanceHubOrderQueueItem } from 'src/modules/shop_order/repositories/dropshipFinanceRepository';
import { isAwaitingCourierRemittance } from 'src/modules/shop_order/utils/isAwaitingCourierRemittance';
import { showErrorNotification, showSuccessNotification } from 'src/utils/appFeedback';

const authStore = useAuthStore();
const route = useRoute();
const router = useRouter();

const tenantId = computed(() => authStore.selectedTenant?.id ?? 0);
const loading = ref(true);
const submitting = ref(false);
const remitOrders = ref<FinanceHubOrderQueueItem[]>([]);
const selectedOrderId = ref<number | null>(null);
const selectedOrder = computed(() => remitOrders.value.find((o) => o.id === selectedOrderId.value) ?? null);

const netAmount = ref<number | null>(null);
const courierCharge = ref(0);
const remittanceRef = ref('');
const bankTrxId = ref('');
const paymentDate = ref(new Date().toISOString().slice(0, 10));

const loadQueue = async () => {
  if (!tenantId.value) return;
  loading.value = true;
  try {
    const hub = await dropshipFinanceRepository.getHubData(tenantId.value);
    remitOrders.value = hub.orders.filter(isAwaitingCourierRemittance);
  } finally {
    loading.value = false;
  }
};

const selectOrder = (order: FinanceHubOrderQueueItem) => {
  selectedOrderId.value = order.id;
  remittanceRef.value = order.courierRemittanceRef || `REMIT-${order.id}`;
  bankTrxId.value = order.courierBankTrxId || '';
};

const goBack = () => {
  const tenantSlug = typeof route.params.tenantSlug === 'string' ? route.params.tenantSlug : undefined;
  router.push({ name: 'app-payments-page', params: tenantSlug ? { tenantSlug } : {} });
};

const submit = async () => {
  if (!selectedOrderId.value || !(netAmount.value && netAmount.value > 0)) return;
  submitting.value = true;
  try {
    await dropshipFinanceRepository.confirmCourierRemittance({
      orderId: selectedOrderId.value,
      netAmount: Number(netAmount.value),
      courierCharge: Number(courierCharge.value) || 0,
      remittanceRef: remittanceRef.value || `REMIT-${selectedOrderId.value}`,
      bankTrxId: bankTrxId.value || undefined,
    });
    showSuccessNotification('Remittance recorded.');
    goBack();
  } catch (e) {
    showErrorNotification(e instanceof Error ? e.message : 'Remittance failed.');
  } finally {
    submitting.value = false;
  }
};

onMounted(() => {
  void loadQueue();
});
</script>

<style scoped>
.page-fixed-layout {
  height: calc(100vh - 55px);
}
.pay-form-card {
  max-width: 720px;
  margin: 0 auto;
  background: var(--bw-neutral-surface, #fff);
  border: 1px solid var(--bw-neutral-border, #e7e1d8);
  border-radius: 8px;
}
</style>
