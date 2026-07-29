<script setup lang="ts">
import type { ShopOrder } from '../types';

const props = defineProps<{
  order: ShopOrder | null;
  updatingStatus: boolean;
  targetUpdatingStatus: string | null;
}>();

const emit = defineEmits<{
  (e: 'update-status', status: string): void;
}>();

const statusOrder = ['submitted', 'processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned'];
const isPassedStatus = (st: string) => {
  if (!props.order?.status) return false;
  const currentIdx = statusOrder.indexOf(props.order.status);
  const targetIdx = statusOrder.indexOf(st);
  return targetIdx !== -1 && targetIdx < currentIdx;
};

const formatStatusLabel = (st: string) => {
  return st.split('_').map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
};

const getStatusColor = (status: string) => {
  switch (status) {
    case 'processing': return 'orange-8';
    case 'ready_for_pickup': return 'blue-7';
    case 'shipped': return 'purple-7';
    case 'delivered': return 'positive';
    case 'returned': return 'negative';
    default: return 'grey';
  }
};
</script>

<template>
  <q-card flat bordered class="q-pa-sm">
    <div class="row items-center justify-between q-col-gutter-sm">
      <div class="col-grow row items-center q-gutter-xs status-workflow-row">
        <!-- Submitted state indicator (Read-Only) -->
        <q-chip
          v-if="order?.status === 'submitted' || isPassedStatus('submitted')"
          dense
          :color="order?.status === 'submitted' ? 'indigo-7' : 'grey-5'"
          :text-color="order?.status === 'submitted' ? 'white' : 'grey-9'"
          :outline="order?.status !== 'submitted'"
          class="q-px-sm text-caption text-weight-bold"
        >
          <q-icon
            v-if="order?.status === 'submitted'"
            name="ph ph-check-circle"
            size="14px"
            class="q-mr-xs"
          />
          Submitted
        </q-chip>
        <q-icon
          v-if="order?.status === 'submitted' || isPassedStatus('submitted')"
          name="ph ph-caret-right"
          color="grey-5"
          size="18px"
          class="status-workflow-chevron"
        />

        <template
          v-for="(st, idx) in ['processing', 'ready_for_pickup', 'shipped', 'delivered']"
          :key="st"
        >
          <q-btn
            :color="order?.status === st ? getStatusColor(st) : isPassedStatus(st) ? 'grey-5' : 'grey-3'"
            :text-color="order?.status === st ? 'white' : isPassedStatus(st) ? 'grey-9' : 'grey-7'"
            :outline="order?.status !== st"
            :unelevated="order?.status === st"
            dense
            no-caps
            class="q-px-md text-caption text-weight-bold"
            :loading="updatingStatus && targetUpdatingStatus === st"
            :disable="updatingStatus && targetUpdatingStatus !== st"
            @click="emit('update-status', st)"
          >
            <q-icon
              v-if="order?.status === st"
              name="ph ph-check-circle"
              size="14px"
              class="q-mr-xs"
            />
            {{ formatStatusLabel(st) }}
          </q-btn>
          <q-icon
            v-if="idx < 3"
            name="ph ph-caret-right"
            color="grey-5"
            size="18px"
            class="status-workflow-chevron"
          />
        </template>
        <q-separator vertical class="q-mx-sm status-workflow-sep" />
        <q-btn
          :color="order?.status === 'returned' ? 'negative' : 'grey-3'"
          :text-color="order?.status === 'returned' ? 'white' : 'grey-7'"
          :outline="order?.status !== 'returned'"
          :unelevated="order?.status === 'returned'"
          dense
          no-caps
          class="q-px-md text-caption text-weight-bold"
          :loading="updatingStatus && targetUpdatingStatus === 'returned'"
          :disable="updatingStatus && targetUpdatingStatus !== 'returned'"
          @click="emit('update-status', 'returned')"
        >
          <q-icon
            v-if="order?.status === 'returned'"
            name="ph ph-x-circle"
            size="14px"
            class="q-mr-xs"
          />
          Returned
        </q-btn>
      </div>
    </div>
  </q-card>
</template>
