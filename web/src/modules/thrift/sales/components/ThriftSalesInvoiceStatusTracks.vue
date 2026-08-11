<template>
  <div class="q-gutter-y-sm">
    <!-- Delivery (Online only) -->
    <q-card v-if="isOnline" flat bordered class="q-pa-sm">
      <div class="row items-center q-col-gutter-sm">
        <div class="col-12 col-sm-auto">
          <div class="text-caption text-weight-bold text-grey-8 text-uppercase">
            Delivery
          </div>
        </div>
        <div class="col-grow row items-center q-gutter-xs status-workflow-row">
          <template v-for="(st, idx) in deliveryWorkflow" :key="st">
            <q-btn
              :color="
                deliveryCurrent === st
                  ? deliveryColor(st)
                  : isPassed(deliveryCurrent, deliveryWorkflow, st)
                    ? 'grey-5'
                    : 'grey-3'
              "
              :text-color="
                deliveryCurrent === st
                  ? 'white'
                  : isPassed(deliveryCurrent, deliveryWorkflow, st)
                    ? 'grey-9'
                    : 'grey-7'
              "
              :outline="deliveryCurrent !== st"
              :unelevated="deliveryCurrent === st"
              dense
              no-caps
              class="q-px-md text-caption text-weight-bold"
              :loading="updatingDelivery && targetDelivery === st"
              :disable="deliveryBtnDisabled(st)"
              @click="onDeliveryClick(st)"
            >
              <q-icon
                v-if="deliveryCurrent === st"
                name="ph ph-check-circle"
                size="14px"
                class="q-mr-xs"
              />
              {{ formatStatusLabel(st) }}
            </q-btn>
            <q-icon
              v-if="idx < deliveryWorkflow.length - 1"
              name="ph ph-caret-right"
              color="grey-5"
              size="18px"
              class="status-workflow-chevron"
            />
          </template>
          <q-separator vertical class="q-mx-sm status-workflow-sep" />
          <q-btn
            :color="deliveryCurrent === 'RETURNED' ? 'warning' : 'grey-3'"
            :text-color="deliveryCurrent === 'RETURNED' ? 'white' : 'grey-7'"
            :outline="deliveryCurrent !== 'RETURNED'"
            :unelevated="deliveryCurrent === 'RETURNED'"
            dense
            no-caps
            class="q-px-md text-caption text-weight-bold"
            disable
          >
            <q-icon
              v-if="deliveryCurrent === 'RETURNED'"
              name="ph ph-arrow-u-up-left"
              size="14px"
              class="q-mr-xs"
            />
            Returned
          </q-btn>
        </div>
      </div>
    </q-card>

    <!-- Payment -->
    <q-card flat bordered class="q-pa-sm">
      <div class="row items-center q-col-gutter-sm">
        <div class="col-12 col-sm-auto">
          <div class="text-caption text-weight-bold text-grey-8 text-uppercase">
            Payment
          </div>
        </div>
        <div class="col-grow row items-center q-gutter-xs status-workflow-row">
          <template v-for="(st, idx) in paymentWorkflow" :key="st">
            <q-btn
              :color="
                paymentCurrent === st
                  ? paymentColor(st)
                  : isPassed(paymentCurrent, paymentWorkflow, st)
                    ? 'grey-5'
                    : 'grey-3'
              "
              :text-color="
                paymentCurrent === st
                  ? 'white'
                  : isPassed(paymentCurrent, paymentWorkflow, st)
                    ? 'grey-9'
                    : 'grey-7'
              "
              :outline="paymentCurrent !== st"
              :unelevated="paymentCurrent === st"
              dense
              no-caps
              class="q-px-md text-caption text-weight-bold"
              :loading="remitting && targetPayment === st"
              :disable="paymentBtnDisabled(st)"
              @click="onPaymentClick(st)"
            >
              <q-icon
                v-if="paymentCurrent === st"
                name="ph ph-check-circle"
                size="14px"
                class="q-mr-xs"
              />
              {{ formatStatusLabel(st) }}
            </q-btn>
            <q-icon
              v-if="idx < paymentWorkflow.length - 1"
              name="ph ph-caret-right"
              color="grey-5"
              size="18px"
              class="status-workflow-chevron"
            />
          </template>
          <template v-if="isOnline">
            <q-separator vertical class="q-mx-sm status-workflow-sep" />
            <q-btn
              :color="paymentCurrent === 'WRITTEN_OFF' ? 'grey-8' : 'grey-3'"
              :text-color="paymentCurrent === 'WRITTEN_OFF' ? 'white' : 'grey-7'"
              :outline="paymentCurrent !== 'WRITTEN_OFF'"
              :unelevated="paymentCurrent === 'WRITTEN_OFF'"
              dense
              no-caps
              class="q-px-md text-caption text-weight-bold"
              :loading="remitting && targetPayment === 'WRITTEN_OFF'"
              :disable="writtenOffDisabled"
              @click="onPaymentClick('WRITTEN_OFF')"
            >
              <q-icon
                v-if="paymentCurrent === 'WRITTEN_OFF'"
                name="ph ph-x-circle"
                size="14px"
                class="q-mr-xs"
              />
              Written off
            </q-btn>
          </template>
          <template v-if="isRefundPayment">
            <q-separator vertical class="q-mx-sm status-workflow-sep" />
            <q-btn
              :color="paymentColor(paymentCurrent)"
              text-color="white"
              unelevated
              dense
              no-caps
              class="q-px-md text-caption text-weight-bold"
              disable
            >
              <q-icon name="ph ph-check-circle" size="14px" class="q-mr-xs" />
              {{ formatStatusLabel(paymentCurrent) }}
            </q-btn>
          </template>
        </div>
      </div>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { ThriftDeliveryStatus } from '../repositories/thriftSalesRepository';

const props = defineProps<{
  saleChannel: string;
  deliveryStatus: string | null | undefined;
  paymentStatus: string;
  invoiceActive: boolean;
  canUpdateDelivery: boolean;
  canRecordRemittance: boolean;
  updatingDelivery: boolean;
  remitting: boolean;
  targetDelivery: string | null;
  targetPayment: string | null;
  allowedDeliveryNext: Array<Exclude<ThriftDeliveryStatus, 'RETURNED'>>;
}>();

const emit = defineEmits<{
  (
    e: 'select-delivery',
    status: Exclude<ThriftDeliveryStatus, 'RETURNED'>,
  ): void;
  (e: 'select-payment', status: 'PAID' | 'WRITTEN_OFF'): void;
}>();

const deliveryWorkflow = [
  'PENDING',
  'READY',
  'IN_TRANSIT',
  'DELIVERED',
] as const;

const isOnline = computed(() => (props.saleChannel || '').toUpperCase() === 'ONLINE');

const deliveryCurrent = computed(() =>
  (props.deliveryStatus || 'PENDING').toUpperCase(),
);

const paymentCurrent = computed(() =>
  (props.paymentStatus || '').toUpperCase().replace(/-/g, '_'),
);

const paymentWorkflow = computed(() => {
  if (!isOnline.value) return ['PAID'] as const;
  return ['COD_PENDING', 'PAID'] as const;
});

const isRefundPayment = computed(() =>
  ['REFUNDED', 'PARTIALLY_REFUNDED'].includes(paymentCurrent.value),
);

const writtenOffDisabled = computed(() => true);

function formatStatusLabel(value: string): string {
  const labels: Record<string, string> = {
    PENDING: 'Pending',
    READY: 'Ready',
    IN_TRANSIT: 'In transit',
    DELIVERED: 'Delivered',
    RETURNED: 'Came back',
    COD_PENDING: 'Waiting for COD',
    PAID: 'Paid',
    WRITTEN_OFF: 'Written off',
    REFUNDED: 'Refunded',
    PARTIALLY_REFUNDED: 'Partially refunded',
  };
  return labels[value] ?? value.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
}

function isPassed(current: string, workflow: readonly string[], st: string): boolean {
  if (current === 'RETURNED' || current === 'WRITTEN_OFF') return false;
  if (['REFUNDED', 'PARTIALLY_REFUNDED'].includes(current)) return false;
  const currentIdx = workflow.indexOf(current);
  const targetIdx = workflow.indexOf(st);
  return currentIdx > -1 && targetIdx > -1 && targetIdx < currentIdx;
}

function deliveryColor(st: string): string {
  const s = st.toUpperCase();
  if (s === 'PENDING') return 'grey-7';
  if (s === 'READY') return 'primary';
  if (s === 'IN_TRANSIT') return 'blue-8';
  if (s === 'DELIVERED') return 'positive';
  if (s === 'RETURNED') return 'warning';
  return 'primary';
}

function paymentColor(st: string): string {
  const s = st.toUpperCase().replace(/-/g, '_');
  if (s === 'PAID') return 'positive';
  if (s === 'COD_PENDING') return 'orange-8';
  if (s === 'PARTIALLY_REFUNDED') return 'warning';
  if (s === 'REFUNDED') return 'orange-9';
  if (s === 'WRITTEN_OFF') return 'grey-8';
  return 'grey-7';
}

function deliveryBtnDisabled(st: string): boolean {
  if (deliveryCurrent.value === st) return true;
  if (deliveryCurrent.value === 'RETURNED') return true;
  if (!props.invoiceActive || !props.canUpdateDelivery || !isOnline.value) return true;
  if (props.updatingDelivery || props.remitting) return true;
  // allowedDeliveryNext may include a backward correction (DELIVERED → IN_TRANSIT)
  if (
    props.allowedDeliveryNext.includes(
      st as Exclude<ThriftDeliveryStatus, 'RETURNED'>,
    )
  ) {
    return false;
  }
  if (isPassed(deliveryCurrent.value, deliveryWorkflow, st)) return true;
  return true;
}

function paymentBtnDisabled(_st: string): boolean {
  return true;
}

function onDeliveryClick(st: string) {
  if (deliveryBtnDisabled(st)) return;
  emit('select-delivery', st as Exclude<ThriftDeliveryStatus, 'RETURNED'>);
}

function onPaymentClick(_st: 'PAID' | 'WRITTEN_OFF' | string) {
  return;
}
</script>

<style scoped lang="scss">
.status-workflow-row {
  flex-wrap: wrap;
  row-gap: 8px;
}

.status-workflow-sep {
  align-self: stretch;
  min-height: 24px;
}

@media (max-width: 599px) {
  .status-workflow-chevron,
  .status-workflow-sep {
    display: none;
  }
}
</style>
