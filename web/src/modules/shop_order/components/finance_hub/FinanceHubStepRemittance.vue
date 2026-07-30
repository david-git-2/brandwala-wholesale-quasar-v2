<template>
  <q-card flat bordered class="q-pa-md">
    <div class="text-subtitle1 text-weight-bold text-primary q-mb-md row items-center gap-xs">
      <q-icon name="ph ph-bank" size="20px" />
      <span>Step 2: Confirm Courier Remittance</span>
    </div>

    <div v-if="!selectedOrder" class="text-body2 text-grey-6 q-my-md">
      Please select an order from the queue above to record courier remittance.
    </div>

    <q-banner
      v-else-if="selectedOrder.collectionSource === 'billing_profile'"
      class="bg-amber-1 text-amber-10 rounded-borders q-mb-md"
      dense
    >
      Prepaid / billing-profile collection — recipient courier remittance is not applicable for this order.
    </q-banner>

    <q-form
      v-else
      class="q-gutter-y-sm"
      @submit.prevent="handleConfirm"
    >
      <div class="text-subtitle2 text-weight-bold">
        Order #{{ selectedOrder.orderNo }}
        <span class="text-grey-7 text-body2 text-weight-regular">
          (COD collect: {{ formatAmt(selectedOrder.codCollectAmount) }} BDT)
        </span>
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
            hint="Delivery + COD fee when deducted from margin"
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
            :rules="[val => !!val || 'Required']"
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

      <div class="bg-grey-2 q-pa-sm rounded-borders q-gutter-y-xs">
        <div class="row items-center justify-between text-caption">
          <span>Net remitted to tenant</span>
          <span class="text-positive text-subtitle2 text-weight-bold">{{ formatAmt(netRemitted) }} BDT</span>
        </div>
        <q-separator />
        <div class="row items-center justify-between text-caption text-grey-8">
          <span>→ Clears B2B invoice (up to due)</span>
          <span>{{ formatAmt(invoiceAllocated) }} BDT</span>
        </div>
        <div class="row items-center justify-between text-caption text-grey-8">
          <span>→ Held for merchant profit payout</span>
          <span>{{ formatAmt(merchantHeld) }} BDT</span>
        </div>
        <div class="row items-center justify-between text-caption text-grey-8">
          <span>Courier fee (tenant cost)</span>
          <span>{{ formatAmt(form.courierCharge || 0) }} BDT</span>
        </div>
        <div
          v-if="overCod"
          class="text-negative text-caption q-mt-xs"
        >
          Net + charge exceeds COD collect ({{ formatAmt(selectedOrder.codCollectAmount) }}).
        </div>
      </div>

      <div class="row justify-end q-mt-md">
        <q-btn
          type="submit"
          color="primary"
          unelevated
          no-caps
          :loading="loading"
          :disable="netRemitted <= 0 || overCod || !form.remittanceRef"
          label="Confirm Remittance"
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
  /** Optional B2B invoice outstanding; defaults to order totalAmount when unknown */
  invoiceOutstanding?: number | null;
}>();

const emit = defineEmits<{
  (
    e: 'submit',
    payload: {
      orderId: number;
      netAmount: number;
      courierCharge: number;
      remittanceRef?: string;
      bankTrxId?: string;
    },
  ): void;
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
      const suggested =
        (order.deliveryChargeAmount || 0) + (order.codChargeAmount || 0);
      form.courierCharge = suggested;
      form.remittanceRef = order.courierRemittanceRef || '';
      form.bankTrxId = order.courierBankTrxId || '';
    }
  },
  { immediate: true },
);

const formatAmt = (n: number) =>
  Number(n || 0).toLocaleString('en-BD', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });

const netRemitted = computed(() => {
  if (!props.selectedOrder) return 0;
  const cod = props.selectedOrder.codCollectAmount || 0;
  const charge = form.courierCharge || 0;
  return Math.max(0, cod - charge);
});

const invoiceDue = computed(() => {
  if (props.selectedOrder?.invoiceOutstanding != null) {
    return props.selectedOrder.invoiceOutstanding;
  }
  if (props.invoiceOutstanding != null && props.invoiceOutstanding >= 0) {
    return props.invoiceOutstanding;
  }
  return 0;
});

const invoiceAllocated = computed(() =>
  Math.min(netRemitted.value, Math.max(invoiceDue.value, 0)),
);

const merchantHeld = computed(() =>
  Math.max(0, netRemitted.value - invoiceAllocated.value),
);

const overCod = computed(() => {
  if (!props.selectedOrder) return false;
  const cod = props.selectedOrder.codCollectAmount || 0;
  if (cod <= 0) return false;
  return (netRemitted.value + (form.courierCharge || 0)) > cod + 0.01;
});

function handleConfirm() {
  if (!props.selectedOrder || netRemitted.value <= 0 || overCod.value) return;
  emit('submit', {
    orderId: props.selectedOrder.id,
    netAmount: netRemitted.value,
    courierCharge: form.courierCharge,
    remittanceRef: form.remittanceRef,
    bankTrxId: form.bankTrxId,
  });
}
</script>
