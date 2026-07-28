<script setup lang="ts">
const props = defineProps<{
  order: any;
  workflowStatuses: string[];
  changingStatus: boolean;
  targetUpdatingStatus: string | null;
}>();

const emit = defineEmits<{
  (e: 'change-status', newStatus: string): void;
}>();

const formatStatusLabel = (st: string) => {
  return st.replace(/_/g, ' ').replace(/\b\w/g, (l) => l.toUpperCase());
};

const getStatusColor = (st: string) => {
  switch (st) {
    case 'draft':
      return 'grey-7';
    case 'submitted':
      return 'blue-7';
    case 'negotiating':
      return 'warning';
    case 'priced':
      return 'cyan-8';
    case 'confirmed':
      return 'positive';
    case 'placed':
      return 'indigo-7';
    case 'fulfilled':
      return 'teal-7';
    case 'processing':
      return 'purple-7';
    case 'ready_for_pickup':
      return 'light-blue-8';
    case 'shipped':
      return 'sky-7';
    case 'delivered':
      return 'positive';
    case 'returned':
      return 'orange-9';
    case 'payment_received':
      return 'emerald-7';
    case 'cancelled':
      return 'negative';
    default:
      return 'primary';
  }
};

const isPassedStatus = (st: string) => {
  const current = props.order?.status;
  if (!current) return false;
  const currentIdx = props.workflowStatuses.indexOf(current);
  const targetIdx = props.workflowStatuses.indexOf(st);
  return currentIdx !== -1 && targetIdx !== -1 && targetIdx < currentIdx;
};
</script>

<template>
  <q-card flat bordered class="q-pa-sm">
    <div class="row items-center justify-between q-col-gutter-sm">
      <div class="col-grow row items-center q-gutter-xs status-workflow-row">
        <template v-for="(st, idx) in workflowStatuses" :key="st">
          <q-btn
            :color="order.status === st ? getStatusColor(st) : isPassedStatus(st) ? 'grey-5' : 'grey-3'"
            :text-color="order.status === st ? 'white' : isPassedStatus(st) ? 'grey-9' : 'grey-7'"
            :outline="order.status !== st"
            :unelevated="order.status === st"
            dense
            no-caps
            class="q-px-md text-caption text-weight-bold"
            :loading="changingStatus && targetUpdatingStatus === st"
            :disable="changingStatus && targetUpdatingStatus !== st"
            @click="emit('change-status', st)"
          >
            <q-icon v-if="order.status === st" name="ph ph-check-circle" size="14px" class="q-mr-xs" />
            {{ formatStatusLabel(st) }}
          </q-btn>
          <q-icon
            v-if="idx < workflowStatuses.length - 1"
            name="chevron_right"
            color="grey-5"
            size="18px"
            class="status-workflow-chevron"
          />
        </template>
        <q-separator vertical class="q-mx-sm status-workflow-sep" />
        <q-btn
          :color="order.status === 'cancelled' ? 'negative' : 'grey-3'"
          :text-color="order.status === 'cancelled' ? 'white' : 'grey-7'"
          :outline="order.status !== 'cancelled'"
          :unelevated="order.status === 'cancelled'"
          dense
          no-caps
          class="q-px-md text-caption text-weight-bold"
          :loading="changingStatus && targetUpdatingStatus === 'cancelled'"
          :disable="changingStatus && targetUpdatingStatus !== 'cancelled'"
          @click="emit('change-status', 'cancelled')"
        >
          <q-icon v-if="order.status === 'cancelled'" name="ph ph-check-circle" size="14px" class="q-mr-xs" />
          Cancelled
        </q-btn>
      </div>
    </div>
  </q-card>
</template>
