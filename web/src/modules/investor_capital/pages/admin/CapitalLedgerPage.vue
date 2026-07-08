<template>
  <q-page class="bw-page">
    <section class="bw-page__stack">
      <section class="row items-center justify-between q-col-gutter-md">
        <div class="col">
          <div class="text-overline">Tenant</div>
          <h1 class="text-h5 q-my-none">Capital Ledger</h1>
          <p class="text-body2 text-grey-7 q-mt-xs q-mb-none">
            Manage capital transactions, deposits, withdrawals, and adjustments.
          </p>
        </div>
        <div class="col-auto">
          <q-btn
            color="primary"
            icon="add"
            label="Add Transaction"
            unelevated
            @click="onClickAddTransaction"
          />
        </div>
      </section>

      <q-banner v-if="error" class="bw-status-banner text-white" rounded>
        {{ error }}
      </q-banner>

      <!-- Filter Controls Card -->
      <q-card flat bordered class="q-pa-md bg-white">
        <div class="row q-col-gutter-md items-center">
          <div class="col-12 col-sm-3">
            <q-select
              v-model="investorFilter"
              outlined
              dense
              label="Filter by Investor"
              emit-value
              map-options
              :options="investorFilterOptions"
              @update:model-value="onFilterChange"
            />
          </div>
          <div class="col-12 col-sm-3">
            <q-select
              v-model="typeFilter"
              outlined
              dense
              label="Filter by Type"
              emit-value
              map-options
              :options="typeFilterOptions"
              @update:model-value="onFilterChange"
            />
          </div>
          <div class="col-12 col-sm-2">
            <q-input
              v-model="startDate"
              outlined
              dense
              label="Start Date"
              type="date"
              @update:model-value="onFilterChange"
            />
          </div>
          <div class="col-12 col-sm-2">
            <q-input
              v-model="endDate"
              outlined
              dense
              label="End Date"
              type="date"
              @update:model-value="onFilterChange"
            />
          </div>
          <div class="col-12 col-sm-2">
            <q-btn
              outline
              color="primary"
              label="Reset Filters"
              class="full-width"
              no-caps
              dense
              @click="resetFilters"
            />
          </div>
        </div>
      </q-card>

      <!-- Transactions Card -->
      <q-card flat bordered>
        <q-card-section v-if="loadingTransactions" class="text-grey-7">
          Loading capital ledger...
        </q-card-section>
        <q-card-section v-else-if="transactions.length === 0" class="text-grey-7">
          No transactions found.
        </q-card-section>

        <q-table
          v-else
          flat
          row-key="id"
          :rows="transactions"
          :columns="columns"
          :pagination="{ rowsPerPage: 20 }"
          :dense="$q.screen.lt.md"
        >
          <template #body-cell-id="props">
            <q-td :props="props" class="text-weight-bold text-primary"> #{{ props.row.id }} </q-td>
          </template>

          <template #body-cell-investor_id="props">
            <q-td :props="props">
              {{ investorNameById(props.row.investor_id) }}
            </q-td>
          </template>

          <template #body-cell-amount="props">
            <q-td :props="props" class="text-right text-weight-bold">
              {{ formatAmountBdt(props.row.amount) }}
            </q-td>
          </template>

          <template #body-cell-type="props">
            <q-td :props="props">
              <q-chip
                dense
                square
                :color="getTypeColor(props.row.type).bg"
                :text-color="getTypeColor(props.row.type).text"
                class="text-weight-bold text-uppercase text-xs"
              >
                {{ formatLabel(props.row.type) }}
              </q-chip>
            </q-td>
          </template>

          <template #body-cell-method="props">
            <q-td :props="props">
              <span class="text-capitalize text-grey-8">{{ formatLabel(props.row.method) }}</span>
            </q-td>
          </template>
        </q-table>
      </q-card>
    </section>

    <InvestorTransactionDialog
      v-model="openDialog"
      :tenant-id="resolvedTenantId"
      :investors="legacyInvestors as any"
      @save="handleSaveTransaction"
    />
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { storeToRefs } from 'pinia';
import type { QTableColumn } from 'quasar';

import { useAuthStore } from 'src/modules/auth/stores/authStore';
import InvestorTransactionDialog from '../../components/InvestorTransactionDialog.vue';
import { useInvestorCapitalStore } from 'src/modules/investor_capital/stores/investorCapitalStore';
import type { InvestorTransactionCreateInput } from 'src/modules/investor_capital/types';
import { formatAmountBdt } from 'src/utils/currency';

const authStore = useAuthStore();
const capitalStore = useInvestorCapitalStore();
const { investors, transactions, loadingTransactions, error } = storeToRefs(capitalStore);

const openDialog = ref(false);
const resolvedTenantId = computed(() => authStore.tenantId ?? 0);

// Filters
const investorFilter = ref<number | null>(null);
const typeFilter = ref<string | null>(null);
const startDate = ref<string | null>(null);
const endDate = ref<string | null>(null);

const investorFilterOptions = computed(() => [
  { label: 'All Investors', value: null },
  ...investors.value.map((item) => ({
    label: item.name,
    value: item.investor_id,
  })),
]);

const typeFilterOptions = [
  { label: 'All Types', value: null },
  { label: 'Capital In', value: 'capital_in' },
  { label: 'Withdrawal Paid', value: 'withdrawal_paid' },
  { label: 'Capital Adjustment', value: 'capital_adjustment' },
];

// Dialogue compatibility helper
const legacyInvestors = computed(() =>
  investors.value.map((item) => ({
    id: item.investor_id,
    tenant_id: resolvedTenantId.value,
    name: item.name,
    phone: item.phone,
    email: item.email,
    address: item.address,
    created_at: '',
    updated_at: '',
  })),
);

const columns: QTableColumn[] = [
  { name: 'id', label: 'ID', field: 'id', align: 'left', sortable: true },
  { name: 'date', label: 'Date', field: 'date', align: 'left', sortable: true },
  { name: 'investor_id', label: 'Investor', field: 'investor_id', align: 'left', sortable: true },
  { name: 'type', label: 'Type', field: 'type', align: 'left', sortable: true },
  { name: 'method', label: 'Method', field: 'method', align: 'left', sortable: true },
  { name: 'amount', label: 'Amount', field: 'amount', align: 'right', sortable: true },
  { name: 'note', label: 'Note', field: 'note', align: 'left' },
];

const refresh = async () => {
  if (!resolvedTenantId.value) {
    return;
  }

  await Promise.all([
    capitalStore.fetchInvestorsByTenant(resolvedTenantId.value),
    fetchTransactions(),
  ]);
};

const fetchTransactions = async () => {
  await capitalStore.fetchTransactionsByTenant(
    resolvedTenantId.value,
    200,
    0,
    investorFilter.value,
    typeFilter.value,
    startDate.value,
    endDate.value,
  );
};

const onFilterChange = async () => {
  await fetchTransactions();
};

const resetFilters = async () => {
  investorFilter.value = null;
  typeFilter.value = null;
  startDate.value = null;
  endDate.value = null;
  await fetchTransactions();
};

const investorNameById = (id: number) => {
  return investors.value.find((item) => item.investor_id === id)?.name ?? `#${id}`;
};

const getTypeColor = (type: string) => {
  if (type === 'capital_in') return { bg: 'green-1', text: 'green-9' };
  if (type === 'withdrawal_paid') return { bg: 'red-1', text: 'red-9' };
  return { bg: 'blue-1', text: 'blue-9' };
};

const formatLabel = (value: string) =>
  (value || '')
    .split('_')
    .map((item) => item.charAt(0).toUpperCase() + item.slice(1))
    .join(' ');

const onClickAddTransaction = () => {
  openDialog.value = true;
};

const handleSaveTransaction = async (payload: InvestorTransactionCreateInput) => {
  await capitalStore.createTransaction({
    ...payload,
    tenant_id: resolvedTenantId.value,
  });
};

onMounted(() => {
  void refresh();
});
</script>
