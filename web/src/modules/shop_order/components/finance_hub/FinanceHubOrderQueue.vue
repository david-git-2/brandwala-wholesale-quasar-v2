<template>
  <q-card flat bordered class="q-pa-none">
    <q-card-section class="q-pb-sm row items-center justify-between">
      <div class="text-subtitle1 text-weight-bold row items-center gap-xs">
        <q-icon name="ph ph-list-numbers" size="20px" class="text-primary" />
        <span>Dropship Orders Finance Queue</span>
      </div>
      <q-tabs
        :model-value="activeStep"
        @update:model-value="emit('update:activeStep', $event)"
        dense
        no-caps
        active-color="primary"
        indicator-color="primary"
        class="text-grey-7"
      >
        <q-tab name="delivered_costing" label="1. Delivered Costing" />
        <q-tab name="courier_remittance" label="2. Courier Remittance" />
        <q-tab name="all" label="All Delivered Orders" />
      </q-tabs>
    </q-card-section>

    <q-separator />

    <div class="treasury-table-wrap">
      <q-table
        flat
        dense
        :rows="filteredOrders"
        :columns="columns"
        row-key="id"
        :pagination="{ rowsPerPage: 10 }"
      >
        <template #body-cell-orderNo="props">
          <q-td :props="props">
            <span class="text-weight-bold text-primary cursor-pointer" @click="emit('selectOrder', props.row)">
              #{{ props.row.orderNo }}
            </span>
          </q-td>
        </template>

        <template #body-cell-status="props">
          <q-td :props="props">
            <q-chip
              dense
              size="12px"
              :color="props.row.status === 'payment_received' ? 'positive' : 'info'"
              text-color="white"
            >
              {{ props.row.status }}
            </q-chip>
          </q-td>
        </template>

        <template #body-cell-nextStep="props">
          <q-td :props="props">
            <q-chip
              dense
              size="11px"
              outline
              :color="getStepColor(props.row.nextStep)"
            >
              {{ getStepLabel(props.row.nextStep) }}
            </q-chip>
          </q-td>
        </template>

        <template #body-cell-actions="props">
          <q-td :props="props" align="right">
            <q-btn
              unelevated
              no-caps
              dense
              size="sm"
              color="primary"
              label="Select Action"
              @click="emit('selectOrder', props.row)"
            />
          </q-td>
        </template>
      </q-table>
    </div>
  </q-card>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { FinanceHubOrderQueueItem } from '../../repositories/dropshipFinanceRepository';

const props = defineProps<{
  orders: FinanceHubOrderQueueItem[];
  activeStep: string;
}>();

const emit = defineEmits<{
  (e: 'update:activeStep', val: string): void;
  (e: 'selectOrder', order: FinanceHubOrderQueueItem): void;
}>();

const filteredOrders = computed(() => {
  if (props.activeStep === 'all') return props.orders;
  return props.orders.filter((o) => o.nextStep === props.activeStep);
});

const columns = [
  { name: 'orderNo', label: 'Order #', field: 'orderNo', align: 'left' as const, sortable: true },
  { name: 'customerName', label: 'Customer', field: (row: FinanceHubOrderQueueItem) => row.customerName || 'N/A', align: 'left' as const },
  { name: 'merchant', label: 'Merchant', field: (row: FinanceHubOrderQueueItem) => row.billingProfileName || 'N/A', align: 'left' as const },
  { name: 'totalAmount', label: 'Total', field: (row: FinanceHubOrderQueueItem) => `${row.totalAmount} BDT`, align: 'right' as const, sortable: true },
  { name: 'cod', label: 'COD Collect', field: (row: FinanceHubOrderQueueItem) => `${row.codCollectAmount} BDT`, align: 'right' as const },
  { name: 'status', label: 'Status', field: 'status', align: 'center' as const },
  { name: 'nextStep', label: 'Next Finance Action', field: 'nextStep', align: 'center' as const },
  { name: 'actions', label: '', field: 'actions', align: 'right' as const },
];

function getStepColor(step: string) {
  if (step === 'delivered_costing') return 'orange';
  if (step === 'courier_remittance') return 'primary';
  return 'positive';
}

function getStepLabel(step: string) {
  if (step === 'delivered_costing') return '1. Costing Needed';
  if (step === 'courier_remittance') return '2. Remittance Needed';
  return 'Completed';
}
</script>

<style scoped>
.treasury-table-wrap {
  overflow-x: auto;
}
</style>
