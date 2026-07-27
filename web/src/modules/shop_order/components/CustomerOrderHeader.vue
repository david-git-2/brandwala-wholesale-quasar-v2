<template>
  <div>
    <!-- Header -->
    <section class="row items-center justify-between q-col-gutter-md">
      <div class="col">
        <div class="row items-center q-gutter-x-sm">
          <q-btn flat dense icon="ph ph-arrow-left" color="grey-7" @click="emit('back')" />
          <div>
            <div class="text-overline text-primary">Customer Order</div>
            <h1 class="text-h5 text-weight-bold q-my-none">Order #{{ order.order_no }}</h1>
            <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
              Placed on {{ formatDate(order.created_at) }} • {{ order.shop_name || 'Wholesale Shop' }}
            </p>
          </div>
        </div>
      </div>
    </section>

    <!-- Status Workflow Strip (read-only for customer; sequence depends on shop type) -->
    <q-card flat bordered class="q-pa-sm q-mt-md">
      <div class="row items-center q-gutter-xs status-workflow-row">
        <template v-for="(st, idx) in statusSequence" :key="st">
          <q-btn
            dense
            no-caps
            :color="normalizedStatus === st ? getStatusColor(st) : isPassedStatus(st) ? 'grey-5' : 'grey-3'"
            :text-color="normalizedStatus === st ? 'white' : isPassedStatus(st) ? 'grey-9' : 'grey-7'"
            :outline="normalizedStatus !== st"
            :unelevated="normalizedStatus === st"
            class="q-px-md text-caption text-weight-bold"
          >
            <q-icon v-if="normalizedStatus === st" name="ph ph-check-circle" size="14px" class="q-mr-xs" />
            {{ formatStatusLabel(st) }}
          </q-btn>
          <q-icon
            v-if="idx < statusSequence.length - 1"
            name="ph ph-caret-right"
            color="grey-5"
            size="18px"
            class="status-workflow-chevron"
          />
        </template>
        <template v-if="terminalStatuses.length">
          <q-separator vertical class="q-mx-sm status-workflow-sep" />
          <q-btn
            v-for="st in terminalStatuses"
            :key="st"
            dense
            no-caps
            :color="normalizedStatus === st ? getStatusColor(st) : 'grey-3'"
            :text-color="normalizedStatus === st ? 'white' : 'grey-7'"
            :outline="normalizedStatus !== st"
            :unelevated="normalizedStatus === st"
            class="q-px-md text-caption text-weight-bold"
          >
            <q-icon v-if="normalizedStatus === st" name="ph ph-check-circle" size="14px" class="q-mr-xs" />
            {{ formatStatusLabel(st) }}
          </q-btn>
        </template>
      </div>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import { date } from 'quasar';

const props = defineProps<{
  order: any;
  statusSequence: string[];
  terminalStatuses: string[];
  normalizedStatus: string;
}>();

const emit = defineEmits<{
  (e: 'back'): void;
}>();

const isPassedStatus = (st: string) => {
  const currentIndex = props.statusSequence.indexOf(props.normalizedStatus);
  const targetIndex = props.statusSequence.indexOf(st);
  if (currentIndex === -1 || targetIndex === -1) return false;
  return targetIndex < currentIndex;
};

const formatDate = (dateStr?: string) => {
  if (!dateStr) return '';
  return date.formatDate(dateStr, 'D MMM YYYY, HH:mm');
};

const formatStatusLabel = (st: string) => {
  switch (st) {
    case 'submitted':
      return 'Submitted';
    case 'negotiating':
      return 'Negotiating';
    case 'priced':
      return 'Priced';
    case 'confirmed':
      return 'Confirmed';
    case 'placed':
      return 'Placed';
    case 'fulfilled':
      return 'Fulfilled';
    case 'processing':
      return 'Processing';
    case 'ready_for_pickup':
      return 'Ready for Pickup';
    case 'shipped':
      return 'Shipped';
    case 'delivered':
      return 'Delivered';
    case 'returned':
      return 'Returned';
    case 'cancelled':
      return 'Cancelled';
    case 'payment_received':
      return 'Payment Received';
    default:
      return st.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
  }
};

const getStatusColor = (status: string) => {
  switch (status) {
    case 'draft':
      return 'grey-7';
    case 'submitted':
      return 'blue-7';
    case 'negotiating':
      return 'amber-9';
    case 'priced':
      return 'cyan-8';
    case 'confirmed':
      return 'green-7';
    case 'placed':
      return 'indigo-7';
    case 'fulfilled':
      return 'teal-7';
    case 'processing':
      return 'purple-7';
    case 'ready_for_pickup':
      return 'indigo-7';
    case 'shipped':
      return 'light-blue-7';
    case 'delivered':
      return 'green-8';
    case 'returned':
      return 'deep-orange-8';
    case 'payment_received':
      return 'emerald-7';
    case 'cancelled':
      return 'red-7';
    default:
      return 'grey-7';
  }
};
</script>

<script lang="ts">
export default {
  name: 'CustomerOrderHeader',
};
</script>
