<template>
  <q-card flat bordered class="q-pa-md">
    <div class="text-subtitle1 text-weight-bold text-primary q-mb-md row items-center gap-xs">
      <q-icon name="ph ph-bank" size="20px" />
      <span>Step 2: Confirm Courier Remittance</span>
    </div>

    <div v-if="!selectedOrder" class="text-body2 text-grey-6 q-my-md">
      Please select an order from the queue above to record courier remittance.
    </div>

    <q-form v-else @submit.prevent="handleConfirm" class="q-gutter-y-sm">
      <div class="text-subtitle2 text-weight-bold">
        Order #{{ selectedOrder.orderNo }} (COD: {{ selectedOrder.codCollectAmount }} BDT)
      </div>

      <div class="row q-col-gutter-sm">
        <div class="col-12 col-md-4">
          <q-input
            v-model.number="form.courierCharge"
            type="number"
            label="Courier Charge / Fee (BDT)"
            outlined
            dense
            step="0.01"
            class="soft-input"
            :rules="[val => val >= 0 || 'Must be >= 0']"
          />
        </div>

        <div class="col-12 col-md-4">
          <q-input
            v-model="form.remittanceRef"
            label="Remittance Ref / Statement ID"
            outlined
            dense
            class="soft-input"
          />
        </div>

        <div class="col-12 col-md-4">
          <q-input
            v-model="form.bankTrxId"
            label="Bank Transaction ID"
            outlined
            dense
            class="soft-input"
          />
        </div>
      </div>

      <div class="bg-grey-2 q-pa-sm rounded-borders text-caption text-weight-medium row items-center justify-between">
        <span>Calculated Net Remitted to Tenant:</span>
        <span class="text-positive text-subtitle2">{{ netRemitted }} BDT</span>
      </div>

      <div class="row justify-end q-mt-md">
        <q-btn
          type="submit"
          color="primary"
          unelevated
          no-caps
          :loading="loading"
          label="Confirm Remittance & Book Middleman Profit"
        />
      </div>
    </q-form>
  </q-card>
</template>

<script setup lang="ts">
import { reactive, computed, watch } from 'vue';
import type { FinanceHubOrderQueueItem } from '../../repositories/dropshipFinanceRepository';

const props = defineProps<{
  selectedOrder: FinanceHubOrderQueueItem | null;
  loading: boolean;
}>();

const emit = defineEmits<{
  (e: 'submit', payload: { orderId: number; courierCharge: number; remittanceRef?: string; bankTrxId?: string }): void;
}>();

const form = reactive({
  courierCharge: 0,
  remittanceRef: '',
  bankTrxId: '',
});

watch(
  () => props.selectedOrder,
  (order) => {
    if (order) {
      form.courierCharge = order.deliveryChargeAmount || 0;
      form.remittanceRef = order.courierRemittanceRef || '';
      form.bankTrxId = order.courierBankTrxId || '';
    }
  },
  { immediate: true }
);

const netRemitted = computed(() => {
  if (!props.selectedOrder) return 0;
  const cod = props.selectedOrder.codCollectAmount || 0;
  const charge = form.courierCharge || 0;
  return Math.max(0, cod - charge);
});

function handleConfirm() {
  if (!props.selectedOrder) return;
  emit('submit', {
    orderId: props.selectedOrder.id,
    courierCharge: form.courierCharge,
    remittanceRef: form.remittanceRef,
    bankTrxId: form.bankTrxId,
  });
}
</script>
