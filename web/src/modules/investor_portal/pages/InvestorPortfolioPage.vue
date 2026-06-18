<template>
  <q-page class="q-pa-md costing-list-page">
    <q-card flat class="q-mb-md floating-surface hero-surface shadow-1 q-pa-md">
      <AppPageHeader
        title="Portfolio"
        subtitle="Capital balances and active shipment investments"
      />
    </q-card>

    <PageInitialLoader v-if="loading" message="Loading portfolio..." />

    <q-banner v-else-if="error" class="bg-negative text-white q-mb-md" rounded>
      {{ error }}
    </q-banner>

    <template v-else-if="portfolio">
      <div class="row q-col-gutter-md q-mb-md">
        <div class="col-12 col-sm-6 col-md-3" v-for="card in balanceCards" :key="card.label">
          <q-card flat class="floating-surface shadow-1 q-pa-md">
            <div class="text-caption text-grey-7">{{ card.label }}</div>
            <div class="text-h6 text-weight-bold">{{ formatCurrency(card.value) }}</div>
          </q-card>
        </div>
      </div>

      <q-card flat class="floating-surface shadow-1 q-pa-md">
        <div class="text-subtitle1 text-weight-bold q-mb-md">Active investments</div>
        <q-markup-table v-if="portfolio.active_investments?.length" flat bordered wrap-cells>
          <thead>
            <tr>
              <th>Shipment</th>
              <th>Invested</th>
              <th>Share %</th>
              <th>Allocated cost</th>
              <th>Profit</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="item in portfolio.active_investments" :key="item.id">
              <td>#{{ item.shipment_id }}</td>
              <td>{{ formatCurrency(item.invested_amount) }}</td>
              <td>{{ item.cost_share_pct ?? '—' }}%</td>
              <td>{{ formatCurrency(item.allocated_cost) }}</td>
              <td>{{ formatCurrency(item.computed_profit) }}</td>
            </tr>
          </tbody>
        </q-markup-table>
        <div v-else class="text-grey-7">No active shipment investments.</div>
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
    { label: 'Deposits', value: balances.deposits },
    { label: 'Withdrawals', value: balances.withdrawals },
    { label: 'Deployed', value: balances.deployed },
    { label: 'Available', value: balances.available },
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
