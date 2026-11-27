<template>
  <div class="column no-wrap full-height overflow-hidden bg-surface">
    <div class="row items-center justify-end q-pa-sm flex-shrink-0">
      <q-btn
        unelevated
        color="primary"
        icon="ph ph-plus"
        label="Record entry"
        no-caps
        style="border-radius: 8px"
        :disable="!investorId"
        @click="openDialog = true"
      />
    </div>

    <div class="col overflow-auto q-px-sm q-pb-sm">
      <div v-if="loading" class="text-grey-7 q-pa-md">Loading investment activity…</div>

      <q-markup-table v-else flat class="sticky-header-table full-width">
        <thead>
          <tr>
            <th class="text-left">Date</th>
            <th class="text-left">Type</th>
            <th class="text-left">Method</th>
            <th class="text-right">Amount</th>
            <th class="text-left">Note</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="!transactions.length">
            <td colspan="5" class="text-center text-grey-7 q-pa-lg">No investment activity yet.</td>
          </tr>
          <tr v-for="row in transactions" :key="`${row.date}-${row.type}-${row.amount}`">
            <td>{{ row.date }}</td>
            <td class="text-capitalize">{{ formatLabel(row.type) }}</td>
            <td class="text-capitalize">{{ formatLabel(row.method) }}</td>
            <td class="text-right text-weight-bold">{{ formatAmount(row.amount) }}</td>
            <td>{{ row.note || '—' }}</td>
          </tr>
        </tbody>
      </q-markup-table>
    </div>

    <InvestorTransactionDialog
      v-model="openDialog"
      :tenant-id="tenantId"
      :investors="dialogInvestors"
      :fixed-investor-id="investorId"
      @save="handleSaveTransaction"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { storeToRefs } from 'pinia';

import InvestorTransactionDialog from '../../components/InvestorTransactionDialog.vue';
import { useInvestorDetailContext } from '../../composables/useInvestorDetailContext';
import { useInvestorCapitalStore } from '../../stores/investorCapitalStore';
import type { InvestorTransactionCreateInput } from '../../types';
import { formatAmountBdt } from 'src/utils/currency';

const capitalStore = useInvestorCapitalStore();
const { transactions, loadingTransactions } = storeToRefs(capitalStore);
const { investorId, tenantId, investorAsProfile } = useInvestorDetailContext();

const openDialog = ref(false);
const loading = computed(() => loadingTransactions.value);

const dialogInvestors = computed(() => {
  const profile = investorAsProfile.value;
  return profile ? [profile] : [];
});

const refresh = async () => {
  if (tenantId.value <= 0 || investorId.value <= 0) {
    return;
  }
  await capitalStore.fetchTransactionsByTenant(tenantId.value, 200, 0, investorId.value);
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

const handleSaveTransaction = async (payload: InvestorTransactionCreateInput) => {
  await capitalStore.createTransaction(payload);
  await refresh();
  await capitalStore.fetchInvestorsByTenant(tenantId.value);
};
</script>
