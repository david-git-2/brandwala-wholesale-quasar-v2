<template>
  <q-card flat bordered class="q-pa-md shipment-pay-card">
    <div class="text-subtitle1 text-weight-bold text-primary q-mb-xs">
      Pay
    </div>
    <div class="text-caption text-grey-7 q-mb-md">
      Pay the vendor or cargo company for these costs.
    </div>
    <q-table
      v-if="settleableEntries.length"
      flat
      dense
      :rows="settleableEntries"
      :columns="settleEntryColumns"
      row-key="id"
      hide-pagination
      :rows-per-page-options="[0]"
    >
      <template #body-cell-cost_type="props">
        <q-td :props="props">
          <span class="text-capitalize">{{ props.row.cost_type }}</span>
        </q-td>
      </template>
      <template #body-cell-amount="props">
        <q-td :props="props" class="text-right">
          ৳{{ Number(props.row.amount).toLocaleString(undefined, { minimumFractionDigits: 2 }) }}
        </q-td>
      </template>
    </q-table>
    <div v-else class="text-body2 text-grey-7 q-mb-md">
      Add who to pay on the Landed cost tab first.
    </div>
    <span>
      <q-btn
        color="secondary"
        unelevated
        no-caps
        icon="ph ph-wallet"
        label="Pay all"
        :disable="!settleableEntries.length"
        :loading="paySettling"
        @click="$emit('pay-all')"
      />
      <q-tooltip v-if="!settleableEntries.length">
        Add who to pay on the Landed cost tab first.
      </q-tooltip>
    </span>
  </q-card>
</template>

<script setup lang="ts">
import type { QTableColumn } from 'quasar';
import type { GlobalShipmentCostEntry } from '../types/shipmentCostEntry';

defineProps<{
  settleableEntries: GlobalShipmentCostEntry[];
  settleEntryColumns: QTableColumn<GlobalShipmentCostEntry>[];
  paySettling: boolean;
}>();

defineEmits<{
  'pay-all': [];
}>();
</script>
