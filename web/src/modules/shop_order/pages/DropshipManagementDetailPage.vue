<template>
  <q-page class="bw-page dropship-order-detail-v2">
    <div class="bw-page__stack">
      <div v-if="!order" class="text-center text-grey-6 q-pa-xl">
        Order not found.
      </div>

      <template v-else>
        <DropshipManagementSettlementPaper :order="order" />

        <div class="dropship-order-detail-v2__footer-actions">
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="ph ph-package"
            label="Mark as delivered"
            class="text-weight-bold dropship-order-detail-v2__action-btn"
            :disable="order.status !== 'shipped'"
          />
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="ph ph-bank"
            label="Bank transfer from courier"
            class="text-weight-bold dropship-order-detail-v2__action-btn"
            :disable="order.status !== 'delivered'"
          />
          <q-btn
            color="primary"
            unelevated
            no-caps
            icon="ph ph-wallet"
            label="Transfer to reseller"
            class="text-weight-bold dropship-order-detail-v2__action-btn"
            :disable="order.status !== 'delivered'"
          />
        </div>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import DropshipManagementSettlementPaper from '../components/DropshipManagementSettlementPaper.vue';
import { findDropshipManagementDummyOrder } from '../data/dropshipManagementDummyOrders';

const route = useRoute();

const orderId = computed(() => String(route.params.id ?? ''));
const order = computed(() => findDropshipManagementDummyOrder(orderId.value));
</script>

<style scoped>
.dropship-order-detail-v2 {
  background: #eef1f4;
}

.dropship-order-detail-v2__footer-actions {
  width: 100%;
  max-width: 800px;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  align-items: stretch;
  gap: 0.5rem;
  padding-top: 0.25rem;
}

.dropship-order-detail-v2__action-btn {
  border-radius: 8px;
  min-height: 44px;
}
</style>

<script lang="ts">
export default {
  name: 'DropshipManagementDetailPage',
};
</script>
