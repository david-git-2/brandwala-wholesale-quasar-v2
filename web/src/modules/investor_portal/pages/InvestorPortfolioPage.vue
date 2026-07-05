<template>
  <q-page class="q-pa-md costing-list-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1 q-pa-md">
      <AppPageHeader
        title="Portfolio Dashboard"
        subtitle="Manage your capital balances and track shipment earnings"
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
          <q-icon name="info" color="indigo" />
        </template>
        Withdrawable balance is calculated from realized profits. Contact your administrator to request a payout.
      </q-banner>

      <q-card flat class="floating-surface shadow-1 q-pa-md">
        <div class="text-subtitle1 text-weight-bold q-mb-md">Active shipment allocations</div>
        <q-markup-table v-if="portfolio.active_investments?.length" flat bordered wrap-cells>
          <thead>
            <tr>
              <th class="text-left">Shipment</th>
              <th class="text-right">Invested amount</th>
              <th class="text-right">Cost share %</th>
              <th class="text-right">Allocated cost</th>
              <th class="text-right">Computed profit</th>
              <th class="text-left">Status</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="item in portfolio.active_investments" :key="item.id">
              <td class="text-left">#{{ item.shipment_id }}</td>
              <td class="text-right">{{ formatCurrency(item.invested_amount) }}</td>
              <td class="text-right">{{ item.cost_share_pct ?? '0.00' }}%</td>
              <td class="text-right">{{ formatCurrency(item.allocated_cost) }}</td>
              <td class="text-right">{{ formatCurrency(item.computed_profit) }}</td>
              <td class="text-left text-capitalize">{{ item.profit_status || 'open' }}</td>
            </tr>
          </tbody>
        </q-markup-table>
        <div v-else class="text-grey-7">No active shipment allocations found.</div>
      </q-card>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'

import AppPageHeader from 'src/components/ui/AppPageHeader.vue'
import PageInitialLoader from 'src/components/ui/PageInitialLoader.vue'
import { useAuthStore } from 'src/modules/auth/stores/authStore'
import { useInvestorPortalStore } from '../stores/investorPortalStore'

const authStore = useAuthStore()
const investorPortalStore = useInvestorPortalStore()

const loading = ref(true)
const error = ref<string | null>(null)

const portfolio = computed(() => investorPortalStore.portfolio)

const balanceCards = computed(() => {
  const balances = portfolio.value?.balances
  if (!balances) return []

  return [
    { label: 'Total Invested', value: balances.deposits },
    { label: 'Deployed in Shipments', value: balances.deployed },
    { label: 'Unallocated Cash', value: balances.available },
    { label: 'Realized Profit', value: balances.realized_profit },
    { label: 'Unrealized Profit', value: balances.unrealized_profit },
    { label: 'Withdrawable Balance', value: balances.withdrawable_balance, class: 'bg-green-1 text-green-9' },
    { label: 'Total Withdrawn', value: balances.withdrawals },
  ]
})

const formatCurrency = (value: number) =>
  new Intl.NumberFormat('en-BD', { style: 'currency', currency: 'BDT', maximumFractionDigits: 0 }).format(
    Number(value ?? 0),
  )

onMounted(async () => {
  const investorId = authStore.member?.id
  if (!investorId) {
    error.value = 'Investor account not linked.'
    loading.value = false
    return
  }

  const result = await investorPortalStore.loadPortfolio(investorId)
  if (!result.success) {
    error.value = result.error ?? 'Failed to load portfolio.'
  }
  loading.value = false
})
</script>
