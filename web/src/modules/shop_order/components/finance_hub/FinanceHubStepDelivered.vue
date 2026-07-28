<template>
  <q-card flat bordered class="q-pa-md">
    <div class="text-subtitle1 text-weight-bold text-primary q-mb-md row items-center gap-xs">
      <q-icon name="ph ph-check-circle" size="20px" />
      <span>Step 1: Confirm Delivered Costing</span>
    </div>

    <div v-if="!selectedOrder" class="text-body2 text-grey-6 q-my-md">
      Please select a delivered order from the queue above to confirm costing.
    </div>

    <q-form v-else @submit.prevent="handleConfirm" class="q-gutter-y-sm">
      <div class="text-subtitle2 text-weight-bold">
        Order #{{ selectedOrder.orderNo }} ({{ selectedOrder.customerName || 'N/A' }})
      </div>

      <div class="row q-col-gutter-sm">
        <div class="col-12 col-md-6">
          <q-input
            v-model.number="form.codAmount"
            type="number"
            label="COD Collected Amount (BDT)"
            outlined
            dense
            step="0.01"
            class="soft-input"
            :rules="[val => val >= 0 || 'Must be >= 0']"
          />
        </div>

        <div class="col-12 col-md-6">
          <q-input
            v-model.number="form.deliveryCharge"
            type="number"
            label="Delivery Charge Amount (BDT)"
            outlined
            dense
            step="0.01"
            class="soft-input"
            :rules="[val => val >= 0 || 'Must be >= 0']"
          />
        </div>
      </div>

      <q-input
        v-model="form.courierNotes"
        label="Courier Notes / Tracking Notes"
        outlined
        dense
        type="textarea"
        rows="2"
        class="soft-input"
      />

      <div class="row justify-end q-mt-md">
        <q-btn
          type="submit"
          color="primary"
          unelevated
          no-caps
          :loading="loading"
          label="Confirm Costing & Credit Courier Wallet"
        />
      </div>
    </q-form>
  </q-card>
</template>

<script setup lang="ts">
import { reactive, watch } from 'vue';
import type { FinanceHubOrderQueueItem } from '../../repositories/dropshipFinanceRepository';

const props = defineProps<{
  selectedOrder: FinanceHubOrderQueueItem | null;
  loading: boolean;
}>();

const emit = defineEmits<{
  (e: 'submit', payload: { orderId: number; codAmount: number; deliveryCharge: number; courierNotes?: string }): void;
}>();

const form = reactive({
  codAmount: 0,
  deliveryCharge: 0,
  courierNotes: '',
});

watch(
  () => props.selectedOrder,
  (order) => {
    if (order) {
      form.codAmount = order.codCollectAmount || order.totalAmount || 0;
      form.deliveryCharge = order.deliveryChargeAmount || 0;
      form.courierNotes = order.courierNotes || '';
    }
  },
  { immediate: true }
);

function handleConfirm() {
  if (!props.selectedOrder) return;
  emit('submit', {
    orderId: props.selectedOrder.id,
    codAmount: form.codAmount,
    deliveryCharge: form.deliveryCharge,
    courierNotes: form.courierNotes,
  });
}
</script>
