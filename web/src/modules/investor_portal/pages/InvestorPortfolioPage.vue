<template>
  <q-page class="q-pa-md costing-list-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1 q-pa-md">
      <AppPageHeader
        title="Dashboard"
        subtitle="Read-only view of your wallet totals"
      />
    </q-card>

    <PageInitialLoader v-if="loading" message="Loading dashboard..." />

    <q-banner v-else-if="error" class="bg-negative text-white q-mb-md" rounded>
      {{ error }}
    </q-banner>

    <template v-else-if="portfolio">
      <div class="row q-col-gutter-md q-mb-md">
        <div class="col-12 col-sm-6 col-md-3" v-for="card in balanceCards" :key="card.label">
          <q-card flat class="floating-surface shadow-1 q-pa-md" :class="card.class">
            <div class="text-caption text-grey-7">{{ card.label }}</div>
            <div class="text-h6 text-weight-bold">{{ formatCurrency(card.value) }}</div>
          </q-card>
        </div>
      </div>

      <q-banner dense inline-actions class="bg-indigo-1 text-indigo-9 q-mb-md rounded-borders">
        <template #avatar>
          <q-icon name="ph ph-info" color="indigo" />
        </template>
        Withdrawable balance is calculated from realized profits. Contact your administrator to
        request a payout.
      </q-banner>

      <q-card flat class="floating-surface shadow-1 q-pa-md">
        <div class="row items-center justify-between q-mb-sm">
          <div class="text-subtitle1 text-weight-bold">Shipments</div>
          <q-btn
            v-if="portfolio.active_investments?.length"
            flat
            dense
            no-caps
            color="primary"
            label="View all shipments"
            :to="shipmentsRoute"
          />
        </div>
        <div v-if="portfolio.active_investments?.length" class="text-body2 text-grey-8">
          You have {{ portfolio.active_investments.length }} active shipment
          {{ portfolio.active_investments.length === 1 ? 'allocation' : 'allocations' }}.
          Open Shipments for investment and profit by batch.
        </div>
        <div v-else class="text-grey-7">No active shipment allocations yet.</div>
      </q-card>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';

import AppPageHeader from 'src/components/ui/AppPageHeader.vue';
import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue';
import { useAuthStore } from 'src/modules/auth/stores/authStore';
import { useInvestorPortalStore } from '../stores/investorPortalStore';

const authStore = useAuthStore();
const investorPortalStore = useInvestorPortalStore();

const loading = ref(true);
const error = ref<string | null>(null);

const portfolio = computed(() => investorPortalStore.portfolio);

const shipmentsRoute = computed(() => {
  const slug = authStore.tenantSlug;
  return slug ? `/${slug}/investor/shipments` : '/investor/shipments';
});

const balanceCards = computed(() => {
  const balances = portfolio.value?.balances;
  if (!balances) return [];

  return [
    { label: 'Total Invested', value: balances.deposits },
    { label: 'Deployed in Shipments', value: balances.deployed },
    { label: 'Unallocated Cash', value: balances.available },
    { label: 'Realized Profit', value: balances.realized_profit },
    { label: 'Unrealized Profit', value: balances.unrealized_profit },
    {
      label: 'Withdrawable Balance',
      value: balances.withdrawable_balance,
      class: 'bg-green-1 text-green-9',
    },
    { label: 'Total Withdrawn', value: balances.withdrawals },
  ];
});

const formatCurrency = (value: number) =>
  new Intl.NumberFormat('en-BD', {
    style: 'currency',
    currency: 'BDT',
    maximumFractionDigits: 0,
  }).format(Number(value ?? 0));

onMounted(async () => {
  const investorId = authStore.member?.id;
  if (!investorId) {
    error.value = 'Investor account not linked.';
    loading.value = false;
    return;
  }

  const result = await investorPortalStore.loadPortfolio(investorId);
  if (!result.success) {
    error.value = result.error ?? 'Failed to load portfolio.';
  }
  loading.value = false;
});
</script>
