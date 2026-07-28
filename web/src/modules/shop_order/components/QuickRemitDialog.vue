<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import type { ShopOrder } from '../types';
import { useQuickRemitMutation } from '../composables/useQuickRemitMutation';

const props = defineProps<{
  modelValue: boolean;
  order: ShopOrder | null;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'success'): void;
}>();

const isOpen = computed({
  get: () => props.modelValue,
  set: (val: boolean) => emit('update:modelValue', val),
});

const courierCharge = ref<number>(0);

watch(
  () => props.order,
  (newOrder) => {
    if (newOrder) {
      courierCharge.value = newOrder.delivery_charge_amount || 0;
    }
  },
  { immediate: true },
);

const { mutate: remitOrder, isPending } = useQuickRemitMutation();

function handleConfirmRemittance() {
  if (!props.order) return;

  remitOrder(
    {
      orderId: props.order.id,
      courierCharge: Number(courierCharge.value) || 0,
    },
    {
      onSuccess: () => {
        isOpen.value = false;
        emit('success');
      },
    },
  );
}
</script>

<template>
  <q-dialog v-model="isOpen" persistent>
    <q-card style="min-width: 420px; border-radius: 12px">
      <q-card-section class="row items-center justify-between q-pb-none">
        <div class="text-h6 text-weight-bold text-grey-9">Quick Remit Payment</div>
        <q-btn flat round dense icon="ph ph-x" v-close-popup />
      </q-card-section>

      <q-card-section class="q-pt-md q-gutter-y-md">
        <div class="bg-blue-1 text-blue-10 q-pa-md rounded-borders text-body2">
          <div>Order: <strong class="text-weight-bold">{{ order?.order_no }}</strong></div>
          <div>Recipient: <strong>{{ order?.recipient_name || '—' }}</strong></div>
          <div>COD Collect Amount: <strong>{{ order?.cod_collect_amount ?? order?.total_amount ?? 0 }} BDT</strong></div>
        </div>

        <q-input
          v-model.number="courierCharge"
          type="number"
          label="Courier Delivery Charge (BDT)"
          outlined
          dense
          hint="Actual delivery fee deducted by courier service"
          min="0"
        />

        <div class="text-caption text-grey-7">
          <q-icon name="ph ph-info" class="q-mr-xs" />
          Marking as remitted will update order status to <strong>Payment Received</strong> and unlock reseller profit margin into their available wallet.
        </div>
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md bg-grey-1">
        <q-btn flat label="Cancel" color="grey-7" v-close-popup no-caps />
        <q-btn
          color="primary"
          unelevated
          no-caps
          label="Confirm & Mark Remitted"
          icon="ph ph-check-circle"
          :loading="isPending"
          @click="handleConfirmRemittance"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>
