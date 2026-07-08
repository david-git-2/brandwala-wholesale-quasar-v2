<template>
  <q-page class="q-pa-md costing-list-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1 q-pa-md">
      <AppPageHeader
        title="Activity Ledger"
        subtitle="Complete chronological log of your capital deposits, withdrawals, and adjustments"
      />
    </q-card>

    <PageInitialLoader v-if="loading" message="Loading ledger..." />

    <q-banner v-else-if="error" class="bg-negative text-white q-mb-md" rounded>
      {{ error }}
    </q-banner>

    <template v-else>
      <q-card flat class="floating-surface shadow-1 q-pa-md">
        <q-markup-table flat bordered wrap-cells>
          <thead>
            <tr>
              <th class="text-left">SL</th>
              <th class="text-left">Date</th>
              <th class="text-left">Transaction type</th>
              <th class="text-left">Payment method</th>
              <th class="text-right">Amount</th>
              <th class="text-left">Note</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="!transactions.length">
              <td colspan="6" class="text-center text-grey-7">No activity records found.</td>
            </tr>
            <tr v-for="(row, index) in transactions" :key="row.id">
              <td>{{ offset + index + 1 }}</td>
              <td class="text-left">{{ formatDate(row.date) }}</td>
              <td class="text-left text-capitalize">{{ formatLabel(row.type) }}</td>
              <td class="text-left text-capitalize">{{ formatLabel(row.method) }}</td>
              <td class="text-right text-weight-bold">{{ formatCurrency(row.amount) }}</td>
              <td class="text-left">{{ row.note ?? '—' }}</td>
            </tr>
          </tbody>
        </q-markup-table>

        <div class="row items-center justify-end q-mt-md q-gutter-sm">
          <q-btn flat round dense icon="chevron_left" :disable="page === 1" @click="prevPage" />
          <span class="text-caption">Page {{ page }} of {{ totalPages }}</span>
          <q-btn
            flat
            round
            dense
            icon="chevron_right"
            :disable="page >= totalPages"
            @click="nextPage"
          />
        </div>
      </q-card>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { storeToRefs } from 'pinia';

import AppPageHeader from 'src/components/ui/AppPageHeader.vue';
import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useInvestorPortalStore } from '../stores/investorPortalStore';

const authStore = useAuthStore();
const investorPortalStore = useInvestorPortalStore();
const { transactions, totalTransactionsCount } = storeToRefs(investorPortalStore);

const loading = ref(true);
const error = ref<string | null>(null);

const page = ref(1);
const limit = 20;
const offset = computed(() => (page.value - 1) * limit);
const totalPages = computed(() => Math.ceil(totalTransactionsCount.value / limit) || 1);

const formatCurrency = (value: number) =>
  new Intl.NumberFormat('en-BD', {
    style: 'currency',
    currency: 'BDT',
    maximumFractionDigits: 0,
  }).format(Number(value ?? 0));

const formatDate = (value: string) => {
  if (!value) return '-';
  return new Date(value).toLocaleDateString();
};

const formatLabel = (value: string) => {
  if (!value) return '-';
  return value
    .split('_')
    .map((item) => item.charAt(0).toUpperCase() + item.slice(1))
    .join(' ');
};

const loadData = async () => {
  loading.value = true;
  const tenantId = authStore.tenantId;
  const investorId = authStore.member?.id;

  if (!tenantId || !investorId) {
    error.value = 'Auth session context invalid.';
    loading.value = false;
    return;
  }

  const result = await investorPortalStore.fetchTransactions(
    tenantId,
    investorId,
    limit,
    offset.value,
  );
  if (!result.success) {
    error.value = result.error ?? 'Failed to load transactions.';
  }
  loading.value = false;
};

const nextPage = () => {
  if (page.value < totalPages.value) {
    page.value++;
    void loadData();
  }
};

const prevPage = () => {
  if (page.value > 1) {
    page.value--;
    void loadData();
  }
};

onMounted(() => {
  void loadData();
});
</script>
