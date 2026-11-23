<template>
  <div class="column no-wrap full-height overflow-hidden bg-surface">
    <div class="col overflow-auto q-pa-sm">
      <div v-if="loading" class="text-grey-7 q-pa-md">Loading allocated shipments…</div>

      <q-banner v-else-if="loadError" class="bg-negative text-white q-mb-sm" rounded dense>
        {{ loadError }}
      </q-banner>

      <q-markup-table v-else flat class="sticky-header-table full-width">
        <thead>
          <tr>
            <th class="text-left">Shipment</th>
            <th class="text-left">Status</th>
            <th class="text-right">Share %</th>
            <th class="text-right">Allocated cost</th>
            <th class="text-right">Profit</th>
            <th class="text-left">Profit status</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="!rows.length">
            <td colspan="6" class="text-center text-grey-7 q-pa-lg">No shipment allocations yet.</td>
          </tr>
          <tr v-for="row in rows" :key="row.id">
            <td class="text-weight-medium">{{ row.shipment_name || `#${row.global_shipment_id}` }}</td>
            <td class="text-capitalize">{{ formatLabel(row.shipment_status) }}</td>
            <td class="text-right">{{ row.cost_share_pct }}%</td>
            <td class="text-right">{{ formatAmount(row.allocated_cost) }}</td>
            <td class="text-right text-weight-bold">{{ formatAmount(row.computed_profit) }}</td>
            <td class="text-capitalize">{{ formatLabel(row.profit_status) }}</td>
          </tr>
        </tbody>
      </q-markup-table>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref, watch } from 'vue';

import { investorCapitalService } from '../../services/investorCapitalService';
import { useInvestorDetailContext } from '../../composables/useInvestorDetailContext';
import type { InvestorAllocationRow } from '../../types';
import { formatAmountBdt } from 'src/utils/currency';

const { investorId, tenantId } = useInvestorDetailContext();

const rows = ref<InvestorAllocationRow[]>([]);
const loading = ref(false);
const loadError = ref<string | null>(null);

const refresh = async () => {
  if (tenantId.value <= 0 || investorId.value <= 0) {
    return;
  }

  loading.value = true;
  loadError.value = null;

  const result = await investorCapitalService.listInvestorAllocations(
    tenantId.value,
    investorId.value,
  );

  loading.value = false;

  if (!result.success) {
    loadError.value = result.error;
    rows.value = [];
    return;
  }

  rows.value = result.data ?? [];
};

watch([tenantId, investorId], () => {
  void refresh();
});

onMounted(() => {
  void refresh();
});

const formatAmount = (value: number) => formatAmountBdt(value);

const formatLabel = (value: string) =>
  (value || '')
    .split('_')
    .map((item) => item.charAt(0).toUpperCase() + item.slice(1))
    .join(' ');
</script>
