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

    <!-- Status Workflow Strip (Shows Current Active -> Next) -->
    <q-card flat bordered class="q-pa-sm q-mt-md bg-grey-1">
      <div class="row items-center justify-between no-wrap q-gutter-x-xs">
        <!-- 1. Current Active Step (Highlighted with Action Badge) -->
        <div class="col text-center">
          <q-badge
            unelevated
            :color="getStatusColor(normalizedStatus)"
            class="q-pa-xs text-weight-bold text-caption shadow-1 full-width justify-center"
            style="font-size: 12px;"
          >
            <q-icon name="ph ph-clock text-white q-mr-xs" size="14px" />
            {{ formatStatusLabel(normalizedStatus) }}
          </q-badge>
        </div>

        <q-icon v-if="focusedSteps.next" name="ph ph-caret-right" color="grey-5" size="16px" />

        <!-- 2. Next Step (Upcoming) -->
        <div v-if="focusedSteps.next" class="col-auto">
          <q-chip
            dense
            outline
            color="grey-6"
            class="text-caption q-ma-none"
          >
            Next: {{ formatStatusLabel(focusedSteps.next) }}
          </q-chip>
        </div>
      </div>
    </q-card>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
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

const focusedSteps = computed(() => {
  const seq = props.statusSequence || [];
  const idx = seq.indexOf(props.normalizedStatus);
  if (idx === -1) {
    return { prev: null, next: null };
  }
  return {
    prev: idx > 0 ? seq[idx - 1] : null,
    next: idx < seq.length - 1 ? seq[idx + 1] : null,
  };
});



const formatDate = (dateStr?: string) => {
  if (!dateStr) return '';
  return date.formatDate(dateStr, 'D MMM YYYY, HH:mm');
};

const formatStatusLabel = (st: string) => {
  switch (st) {
    case 'submitted':
      return 'Submitted';
    case 'costing_pending':
      return 'Costing Pending';
    case 'priced':
      return 'Priced';
    case 'countered':
      return 'Countered';
    case 'final_offered':
      return 'Final Offered';
    case 'confirmed':
      return 'Confirmed';
    case 'procuring':
      return 'Procuring';
    case 'ordered':
      return 'Ordered';
    case 'negotiating':
      return 'Negotiating';
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
    case 'costing_pending':
      return 'deep-orange-7';
    case 'negotiating':
    case 'countered':
      return 'amber-9';
    case 'priced':
      return 'cyan-8';
    case 'final_offered':
      return 'purple-7';
    case 'confirmed':
      return 'green-7';
    case 'procuring':
      return 'blue-9';
    case 'ordered':
      return 'indigo-7';
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
